# -*- coding: utf-8 -*-
"""Acesso ao SQL Server — SOMENTE LEITURA e sempre parametrizado.

Regras de seguranca:
  - `base` sempre validada contra a whitelist (BASE_KEYS) antes de conectar.
  - SQL nunca recebe input do usuario por interpolacao; use `params` (pyodbc `?`).
  - Conexao com timeout; feche sempre.
"""
from typing import Any, Sequence

import pyodbc

from .config import settings, BASE_KEYS


def _conn_str(base_key: str) -> str:
    if base_key not in BASE_KEYS:
        raise ValueError(f"Base inválida: {base_key!r}")
    return (
        f"DRIVER={{{settings.ODBC_DRIVER}}};"
        f"SERVER={settings.SERVER};"
        f"DATABASE={settings.database_for(base_key)};"
        f"UID={settings.DB_USER};"
        f"PWD={settings.DB_PASSWORD};"
    )


def run_query(base_key: str, sql: str, params: Sequence[Any] = ()) -> list[dict]:
    """Executa SQL parametrizado na base e devolve lista de dicts.
    Pula result sets sem colunas (DECLARE nao retorna dados)."""
    conn = None
    try:
        conn = pyodbc.connect(_conn_str(base_key), timeout=120)
        cur = conn.cursor()
        cur.execute(sql, params)
        while cur.description is None:
            if not cur.nextset():
                return []
        cols = [c[0] for c in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]
    finally:
        if conn is not None:
            conn.close()
