# -*- coding: utf-8 -*-
"""Execucao em background para consultas longas.

Monitoring e Big Picture rodam varios SQL em sequencia e passam de 1 minuto por
arquivo — um GET sincrono estouraria no proxy/browser. O cliente inicia o job,
recebe um id e faz polling.

Estado em memoria do processo: e cache de resultado, nao dado de negocio. Com
mais de um worker uvicorn cada um teria seu proprio dicionario — antes de
escalar horizontalmente, trocar por Redis (ver README).
"""
import logging
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from contextvars import copy_context
from dataclasses import dataclass, field
from typing import Any, Callable

from . import cancel

logger = logging.getLogger(__name__)

# 2 workers: as queries sao pesadas e o SQL Server e compartilhado com os bots.
_POOL = ThreadPoolExecutor(max_workers=2, thread_name_prefix="job")

# Resultado expira: evita segurar dezenas de MB de tabela por tempo indefinido.
TTL_SECONDS = 30 * 60


@dataclass
class Job:
    id: str
    label: str
    status: str = "queued"          # queued | running | done | error | cancelled
    progress: int = 0               # 0-100
    step: str = ""                  # o que esta rodando agora
    # Contexto para a tela inicial remontar o link e o resumo sem consultar nada.
    chart_id: str = ""
    base: str = ""
    params: dict = field(default_factory=dict)
    result: Any = None
    error: str | None = None
    created: float = field(default_factory=time.monotonic)
    started: float | None = None     # entrou no worker (fila nao conta)
    finished: float | None = None

    def elapsed(self) -> float | None:
        """Tempo de execucao. Enquanto roda, devolve o parcial."""
        if self.started is None:
            return None
        return (self.finished or time.monotonic()) - self.started

    def public(self, with_result: bool = True) -> dict:
        elapsed = self.elapsed()
        out = {
            "job_id": self.id,
            "label": self.label,
            "status": self.status,
            "progress": self.progress,
            "step": self.step,
            "chart_id": self.chart_id,
            "base": self.base,
            "params": self.params,
            "elapsed_seconds": None if elapsed is None else round(elapsed, 2),
        }
        if self.status == "done" and with_result:
            out["result"] = self.result
        if self.status == "error":
            out["error"] = self.error
        return out


_JOBS: dict[str, Job] = {}
_LOCK = threading.Lock()


def _evict_expired() -> None:
    now = time.monotonic()
    with _LOCK:
        expirados = [j.id for j in _JOBS.values() if now - j.created > TTL_SECONDS]
        for jid in expirados:
            _JOBS.pop(jid, None)
    for jid in expirados:
        cancel.cleanup(jid)


def start(
    label: str,
    work: Callable[[Callable[[int, str], None]], Any],
    *,
    chart_id: str = "",
    base: str = "",
    params: dict | None = None,
) -> str:
    """Enfileira `work`. Recebe um callback `progress(pct, step)` para reportar.

    `chart_id`/`base`/`params` nao afetam a execucao: sao o que a tela inicial
    usa para montar o resumo e o link de volta de uma consulta em andamento.
    """
    _evict_expired()
    job = Job(id=uuid.uuid4().hex, label=label, chart_id=chart_id, base=base,
              params=dict(params or {}))
    with _LOCK:
        _JOBS[job.id] = job

    def progress(pct: int, step: str) -> None:
        with _LOCK:
            job.progress = max(0, min(100, int(pct)))
            job.step = step

    def run() -> None:
        # A thread se identifica: `db.run_query` usa isto para saber qual job
        # cancelar quando o usuário aborta.
        cancel.current_job.set(job.id)

        if cancel.is_cancelled(job.id):           # abortado ainda na fila
            with _LOCK:
                job.status = "cancelled"
                job.finished = time.monotonic()
            return

        with _LOCK:
            job.status = "running"
            job.started = time.monotonic()
        try:
            result = work(progress)
            with _LOCK:
                job.finished = time.monotonic()
                if cancel.is_cancelled(job.id):
                    # Terminou junto com o pedido de cancelamento: o usuário
                    # mandou parar, então o resultado não volta.
                    job.status = "cancelled"
                else:
                    job.result = result
                    job.progress = 100
                    job.step = ""
                    job.status = "done"
        except cancel.Cancelled:
            with _LOCK:
                job.finished = time.monotonic()
                job.status = "cancelled"
                job.step = ""
        except Exception as e:                       # noqa: BLE001 - vai pro cliente
            from .db import scrub                    # import tardio: evita ciclo
            logger.exception("Job %s (%s) falhou", job.id, label)
            with _LOCK:
                job.finished = time.monotonic()
                job.error = scrub(e)
                job.status = "error"

    # O contexto da requisicao vai junto: o idioma escolhido vive num ContextVar
    # (ver i18n.py) e sem esta copia o job responderia sempre em portugues.
    _POOL.submit(copy_context().run, run)
    return job.id


def get(job_id: str) -> Job | None:
    _evict_expired()
    with _LOCK:
        return _JOBS.get(job_id)


def stop(job_id: str) -> Job | None:
    """Aborta o job: marca, derruba a query no banco e descarta o resultado.

    Idempotente — cancelar algo já concluído não desfaz nada, só devolve o
    estado atual.
    """
    job = get(job_id)
    if job is None:
        return None
    if job.status in ("done", "error", "cancelled"):
        return job

    cancel.cancel(job_id)
    with _LOCK:
        # A thread ainda vai reagir ao SQLCancel, mas a tela não precisa esperar
        # por isso para parar de mostrar "consultando".
        job.status = "cancelled"
        job.step = ""
        if job.finished is None:
            job.finished = time.monotonic()
    return job


def listar() -> list[Job]:
    """Jobs vivos, do mais novo para o mais antigo."""
    _evict_expired()
    with _LOCK:
        return sorted(_JOBS.values(), key=lambda j: j.created, reverse=True)
