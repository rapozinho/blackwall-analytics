# -*- coding: utf-8 -*-
"""Endpoints read-only. Toda leitura passa por whitelist (base/chart)."""
import pyodbc
from fastapi import APIRouter, Depends, HTTPException, Query, Request

from .. import i18n, jobs, vertical
from ..auth import current_user
from ..config import BASES, BASE_KEYS, settings
from ..db import run_query, scrub
from ..i18n import msg
from ..registry import (CHARTS, charts_for_base, label as chart_label,
                        required_tables_for_base)

async def _idioma(lang: str = Query(i18n.PADRAO, description="pt | es | en")) -> str:
    """Fixa o idioma desta requisicao para todo o caminho da consulta.

    Dependencia do router e nao parametro de cada rota: quem consome o idioma e
    a saida (rotulo, aba, insight, erro), em codigo que nao ve a requisicao.
    Valor invalido cai no padrao — ver `i18n.normaliza`.

    `async` de proposito: dependencia sincrona roda num worker de threadpool com
    contexto proprio, e o `ContextVar` morreria ali sem chegar ao endpoint. Assim
    ela roda na task da requisicao, e quem for para thread depois (endpoint sync,
    job, pool de queries) leva o contexto por copia.
    """
    return i18n.set_lang(lang)


router = APIRouter(prefix="/api",
                   dependencies=[Depends(current_user), Depends(_idioma)])

# Login timeout curto: o health check testa 4 bases em sequencia e nao pode
# ficar pendurado nos 120s do run_query normal.
_HEALTH_TIMEOUT = 5

# SQLSTATE -> o que olhar primeiro. Erro de ODBC sozinho nao diz onde mexer.
# (4060 tambem chega como 28000, mas a causa e outra — ver _hint_for.)
_SQLSTATE_HINTS = ("08001", "08S01", "28000", "4060", "42000", "IM002")


@router.get("/bases")
def list_bases():
    return BASES


@router.get("/meta")
def app_meta():
    """Vertical de negocio ativa e o vocabulario dela.

    O frontend usa para rotular o que nao vem do backend por metrica (rotulo da
    quebra casino/sports na linha do tempo, unidade de cliente) e para mostrar em
    qual modo o portal esta rodando.
    """
    return vertical.meta()


def _hint_for(sqlstate: str | None, message: str) -> str | None:
    """SQLSTATE nao basta: 'senha errada' e 'sem acesso ao database' sao os dois
    28000. Desempata pelo erro nativo do SQL Server (4060 = database negado)."""
    if "Cannot open database" in message or "(4060)" in message:
        return msg("hint_4060")
    if sqlstate in _SQLSTATE_HINTS:
        return msg(f"hint_{sqlstate}")
    return None


def _check_base(base: dict) -> dict:
    """Testa 1 base: config -> conexao -> tabelas exigidas pelos graficos."""
    key = base["key"]
    database = settings.database_for(key)
    out = {
        "key": key,
        "label": base["label"],
        "database": database or None,
        "status": "unknown",
        "detail": None,
        "missing_tables": [],
    }

    missing_cfg = [n for n, v in (("SERVER", settings.SERVER),
                                  (f"DATABASE_{key.upper()}", database),
                                  ("DB_USER", settings.DB_USER)) if not v]
    if missing_cfg:
        out["status"] = "not_configured"
        out["detail"] = msg("saude_falta_env", vars=", ".join(missing_cfg))
        return out

    required = required_tables_for_base(key)
    try:
        if not required:
            run_query(key, "SELECT 1", timeout=_HEALTH_TIMEOUT)
        else:
            # Nomes vem do registry (codigo), mas ainda vao parametrizados.
            placeholders = ", ".join("?" for _ in required)
            rows = run_query(
                key,
                f"SELECT name FROM sys.tables WHERE name IN ({placeholders})",
                tuple(required),
                timeout=_HEALTH_TIMEOUT,
            )
            found = {r["name"].lower() for r in rows}
            out["missing_tables"] = [t for t in required if t.lower() not in found]
    except pyodbc.Error as e:
        sqlstate = e.args[0] if e.args else None
        detail = scrub(e)
        out["status"] = "error"
        out["detail"] = detail
        out["sqlstate"] = sqlstate
        out["hint"] = _hint_for(sqlstate, detail)
        return out
    except Exception as e:
        out["status"] = "error"
        out["detail"] = scrub(e)
        return out

    if out["missing_tables"]:
        out["status"] = "missing_tables"
        out["detail"] = msg("saude_tabelas")
    else:
        out["status"] = "ok"
    return out


@router.get("/health/db")
def health_db():
    """Diagnostico de conexao por base. Read-only; nao devolve senha."""
    installed = list(pyodbc.drivers())
    bases = [_check_base(b) for b in BASES]
    return {
        "driver": {
            "configured": settings.ODBC_DRIVER,
            "installed": settings.ODBC_DRIVER in installed,
            "available": installed,
        },
        "server": settings.SERVER or None,
        "ok": all(b["status"] == "ok" for b in bases),
        "bases": bases,
    }


@router.get("/charts")
def list_charts(base: str = Query(...)):
    if base not in BASE_KEYS:
        raise HTTPException(400, msg("erro_base"))
    return charts_for_base(base)


def _resolve(chart_id: str, base: str) -> dict:
    """Whitelist de base + chart. Nada aqui aceita SQL ou nome de tabela do cliente."""
    if base not in BASE_KEYS:
        raise HTTPException(400, msg("erro_base"))
    chart = CHARTS.get(chart_id)
    if chart is None:
        raise HTTPException(404, msg("erro_grafico_404"))
    if base not in chart["bases"]:
        raise HTTPException(400, msg("erro_grafico_base"))
    return chart


def _params_from(request: Request) -> dict:
    """Query string exceto 'base'; 'metrics' aceita CSV."""
    return {k: v for k, v in request.query_params.items() if k != "base"}


@router.get("/charts/{chart_id}/data")
def chart_data(chart_id: str, request: Request, base: str = Query(...)):
    """Execução síncrona. Serve para query rápida; Monitoring e Big Picture
    passam de 1 min por arquivo — use o fluxo de job."""
    chart = _resolve(chart_id, base)
    try:
        return chart["load"](base, _params_from(request))
    except ValueError as e:  # validação de params
        raise HTTPException(400, str(e))
    except Exception as e:  # falha de DB/execução
        # scrub: o erro do driver pode carregar a string de conexao inteira, e
        # ela vai direto para o navegador. O fluxo de job ja fazia isso.
        raise HTTPException(500, msg("erro_consulta", e=scrub(e)))


@router.get("/charts/{chart_id}/start")
def chart_start(chart_id: str, request: Request, base: str = Query(...)):
    """Enfileira a consulta e devolve `job_id`. GET de proposito: o desenho do
    projeto e read-only/GET-only e job aqui e cache de resultado, nao recurso
    de negocio."""
    chart = _resolve(chart_id, base)
    params = _params_from(request)
    job_id = jobs.start(
        f"{chart_label(chart)} ({base})",
        lambda progress: chart["load"](base, params, progress),
        chart_id=chart_id, base=base, params=params,
    )
    return {"job_id": job_id}


@router.get("/jobs")
def job_list():
    """Consultas vivas neste processo — alimenta o painel da tela inicial.

    Sem `result`: a lista e' polling frequente e o resultado de um report grande
    passa de 1 MB. Quem quer o dado busca /jobs/{id}.
    """
    return [j.public(with_result=False) for j in jobs.listar()]


@router.get("/jobs/{job_id}")
def job_status(job_id: str):
    job = jobs.get(job_id)
    if job is None:
        raise HTTPException(404, msg("erro_job_404"))
    return job.public()


@router.post("/jobs/{job_id}/cancel")
def job_cancel(job_id: str):
    """Aborta a consulta: derruba a query no banco e descarta o resultado.

    POST porque muda estado no servidor — o resto da API e' GET-only por ser
    leitura pura, o que nao e' o caso aqui.
    """
    job = jobs.stop(job_id)
    if job is None:
        raise HTTPException(404, msg("erro_job_404"))
    return job.public(with_result=False)
