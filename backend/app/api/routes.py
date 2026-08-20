# -*- coding: utf-8 -*-
"""Endpoints read-only. Toda leitura passa por whitelist (base/chart)."""
import pyodbc
from fastapi import APIRouter, Depends, HTTPException, Query, Request

from .. import jobs, vertical
from ..auth import current_user
from ..config import BASES, BASE_KEYS, settings
from ..db import run_query, scrub
from ..registry import CHARTS, charts_for_base, required_tables_for_base

router = APIRouter(prefix="/api", dependencies=[Depends(current_user)])

# Login timeout curto: o health check testa 4 bases em sequencia e nao pode
# ficar pendurado nos 120s do run_query normal.
_HEALTH_TIMEOUT = 5

# SQLSTATE -> o que olhar primeiro. Erro de ODBC sozinho nao diz onde mexer.
_SQLSTATE_HINTS = {
    "08001": "Host/porta inalcancavel: confira SERVER, VPN e se o SQL Server aceita TCP/IP remoto.",
    "08S01": "Conexao caiu no meio: rede instavel ou firewall cortando a sessao.",
    "28000": "Login rejeitado: confira DB_USER/DB_PASSWORD.",
    # 4060 tambem vem como 28000, mas a causa e outra (ver _hint_for).
    "4060": "Login existe mas nao tem acesso a este database: confira o nome em "
            "DATABASE_<BASE> e se o usuario read-only tem permissao nele.",
    "42000": "Conectou no servidor mas nao abriu o database: confira o nome em DATABASE_<BASE>.",
    "IM002": "Driver ODBC nao encontrado: confira ODBC_DRIVER e o que esta instalado na maquina.",
}


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
        return _SQLSTATE_HINTS["4060"]
    return _SQLSTATE_HINTS.get(sqlstate)


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
        out["detail"] = "Faltando no .env: " + ", ".join(missing_cfg)
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
        out["detail"] = ("Conectou, mas estas tabelas nao aparecem para este usuario "
                         "(nao existem ou falta GRANT SELECT).")
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
        raise HTTPException(400, "Base inválida.")
    return charts_for_base(base)


def _resolve(chart_id: str, base: str) -> dict:
    """Whitelist de base + chart. Nada aqui aceita SQL ou nome de tabela do cliente."""
    if base not in BASE_KEYS:
        raise HTTPException(400, "Base inválida.")
    chart = CHARTS.get(chart_id)
    if chart is None:
        raise HTTPException(404, "Gráfico não encontrado.")
    if base not in chart["bases"]:
        raise HTTPException(400, "Gráfico indisponível para esta base.")
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
        raise HTTPException(500, f"Erro ao consultar dados: {scrub(e)}")


@router.get("/charts/{chart_id}/start")
def chart_start(chart_id: str, request: Request, base: str = Query(...)):
    """Enfileira a consulta e devolve `job_id`. GET de proposito: o desenho do
    projeto e read-only/GET-only e job aqui e cache de resultado, nao recurso
    de negocio."""
    chart = _resolve(chart_id, base)
    params = _params_from(request)
    job_id = jobs.start(
        f"{chart['label']} ({base})",
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
        raise HTTPException(404, "Job não encontrado ou expirado.")
    return job.public()


@router.post("/jobs/{job_id}/cancel")
def job_cancel(job_id: str):
    """Aborta a consulta: derruba a query no banco e descarta o resultado.

    POST porque muda estado no servidor — o resto da API e' GET-only por ser
    leitura pura, o que nao e' o caso aqui.
    """
    job = jobs.stop(job_id)
    if job is None:
        raise HTTPException(404, "Job não encontrado ou expirado.")
    return job.public(with_result=False)
