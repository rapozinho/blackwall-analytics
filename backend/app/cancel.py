# -*- coding: utf-8 -*-
"""Cancelamento de consulta em andamento.

Sem isto, "encerrar" seria so parar de olhar: a query continuaria ocupando um
worker e queimando I/O do SQL Server ate terminar sozinha.

Como funciona: `run_query` registra o cursor ativo no job corrente (ContextVar);
cancelar chama `cursor.cancel()`, que dispara SQLCancel no driver ODBC e faz o
`execute()` levantar erro na thread que estava esperando.

Modulo proposital sem dependencia de `db` nem de `jobs` — os dois importam este,
e um importar o outro faria ciclo.
"""
import logging
import threading
from contextvars import ContextVar

logger = logging.getLogger(__name__)

# Id do job que a thread atual esta executando. As threads filhas (o Overview
# roda 2 queries em paralelo) so herdam isto se o contexto for copiado — ver
# `contextvars.copy_context()` em charts/overview.py.
current_job: ContextVar[str | None] = ContextVar("current_job", default=None)

_LOCK = threading.Lock()
_CURSORS: dict[str, set] = {}          # job_id -> cursores abertos
_CANCELLED: set[str] = set()


class Cancelled(Exception):
    """Consulta abortada pelo usuário — não é falha, não vira erro na tela."""


def is_cancelled(job_id: str | None) -> bool:
    if job_id is None:
        return False
    with _LOCK:
        return job_id in _CANCELLED


def register(cursor) -> str | None:
    """Vincula o cursor ao job da thread. Devolve o job_id (ou None fora de job)."""
    job_id = current_job.get()
    if job_id is None:
        return None
    with _LOCK:
        _CURSORS.setdefault(job_id, set()).add(cursor)
    return job_id


def unregister(job_id: str | None, cursor) -> None:
    if job_id is None:
        return
    with _LOCK:
        cursores = _CURSORS.get(job_id)
        if cursores:
            cursores.discard(cursor)
            if not cursores:
                _CURSORS.pop(job_id, None)


def cancel(job_id: str) -> None:
    """Marca o job e aborta o que já estiver rodando no banco.

    A marca vem antes do cancelamento dos cursores: uma consulta que comece entre
    as duas coisas encontra o job já cancelado e nem chega a executar.
    """
    with _LOCK:
        _CANCELLED.add(job_id)
        cursores = list(_CURSORS.get(job_id, ()))

    for cursor in cursores:
        try:
            cursor.cancel()
        except Exception:                       # noqa: BLE001 - cursor pode ter fechado
            logger.debug("Cursor do job %s já estava encerrado", job_id, exc_info=True)


def cleanup(job_id: str) -> None:
    """Solta o estado do job. Chamado quando ele sai do dicionário de jobs."""
    with _LOCK:
        _CURSORS.pop(job_id, None)
        _CANCELLED.discard(job_id)
