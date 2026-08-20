# -*- coding: utf-8 -*-
"""Acesso ao SQL Server — SOMENTE LEITURA e sempre parametrizado.

Regras de seguranca:
  - `base` sempre validada contra a whitelist (BASE_KEYS) antes de conectar.
  - SQL nunca recebe input do usuario por interpolacao; use `params` (pyodbc `?`).
  - Conexao com timeout; feche sempre.
"""
from typing import Any, Sequence

import pyodbc

from . import cancel
from .config import BASE_KEYS, settings
from .i18n import msg


def _conn_str(base_key: str) -> str:
    if base_key not in BASE_KEYS:
        raise ValueError(msg("erro_base_valor", b=repr(base_key)))
    partes = [
        f"DRIVER={{{settings.ODBC_DRIVER}}}",
        f"SERVER={settings.SERVER}",
        f"DATABASE={settings.database_for(base_key)}",
        f"UID={settings.DB_USER}",
        f"PWD={settings.DB_PASSWORD}",
    ]
    # Só entram se configurados: omitir preserva o padrão do driver instalado, e
    # forçar Encrypt=yes contra um servidor sem TLS derruba a conexão.
    if settings.DB_ENCRYPT:
        partes.append(f"Encrypt={settings.DB_ENCRYPT}")
    if settings.DB_TRUST_SERVER_CERTIFICATE:
        partes.append(f"TrustServerCertificate={settings.DB_TRUST_SERVER_CERTIFICATE}")
    return ";".join(partes) + ";"


def scrub(msg: Any) -> str:
    """Remove a senha do texto antes de expor em resposta HTTP/log."""
    out = str(msg)
    if settings.DB_PASSWORD:
        out = out.replace(settings.DB_PASSWORD, "***")
    return out


def run_query(
    base_key: str,
    sql: str,
    params: Sequence[Any] = (),
    timeout: int = 120,
) -> list[dict]:
    """Executa SQL parametrizado na base e devolve lista de dicts.
    Pula result sets sem colunas (DECLARE nao retorna dados).
    `timeout` = login timeout em segundos (health check usa valor curto)."""
    # Job já abortado: nem abre conexão. Vale para a 2a consulta de um loader
    # que roda várias em sequência.
    if cancel.is_cancelled(cancel.current_job.get()):
        raise cancel.Cancelled("Consulta encerrada pelo usuário.")

    conn = None
    job_id = None
    cur = None
    try:
        conn = pyodbc.connect(_conn_str(base_key), timeout=timeout)
        cur = conn.cursor()
        # A partir daqui a consulta é cancelável: o cursor fica visível para
        # `cancel.cancel()`, que dispara SQLCancel e derruba o execute abaixo.
        job_id = cancel.register(cur)
        cur.execute(sql, params)
        while cur.description is None:
            if not cur.nextset():
                return []
        cols = [c[0] for c in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]
    except pyodbc.Error:
        # SQLCancel chega aqui como erro de driver; só é "cancelado" se alguém
        # de fato pediu — senão é falha de verdade e segue como erro.
        if cancel.is_cancelled(job_id or cancel.current_job.get()):
            raise cancel.Cancelled("Consulta encerrada pelo usuário.")
        raise
    finally:
        cancel.unregister(job_id, cur)
        if conn is not None:
            conn.close()
