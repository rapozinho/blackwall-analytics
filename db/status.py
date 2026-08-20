# -*- coding: utf-8 -*-
"""Quantas linhas tem cada base, e de qual versao do seed.

    docker compose run --rm --entrypoint python dbinit status.py

Serve para responder "o dado carregou?" sem abrir cliente SQL. Le com o mesmo
login somente leitura que o backend usa — se este script funciona, o backend
tambem conecta.
"""
import os

import pyodbc

from bases import BASES, ORDEM, TABELAS

DRIVER = os.getenv("ODBC_DRIVER", "ODBC Driver 18 for SQL Server")
SERVIDOR = os.getenv("SEED_SERVER", "sqlserver")
USUARIO = os.getenv("DB_USER", "blackwall_ro")
SENHA = os.environ["DB_PASSWORD"]

TABS = list(TABELAS) + ["affiliate_manager_lumen"]
COLUNAS = ["Zephyr", "Quasar", "Lumen", "Kestrel"]


def contar(base_key: str) -> tuple[dict[str, int], str]:
    conn = pyodbc.connect(
        f"DRIVER={{{DRIVER}}};SERVER={SERVIDOR};DATABASE={BASES[base_key]['database']};"
        f"UID={USUARIO};PWD={SENHA};Encrypt=yes;TrustServerCertificate=yes;",
        timeout=15, autocommit=True)
    cur = conn.cursor()
    out: dict[str, int] = {}
    for tabela in TABS:
        # -1 = a tabela nao existe nesta base (a de gerentes so existe na Lumen).
        cur.execute(f"IF OBJECT_ID('dbo.{tabela}','U') IS NULL SELECT -1 "
                    f"ELSE SELECT COUNT(*) FROM dbo.{tabela}")
        out[tabela] = cur.fetchval()
    cur.execute("SELECT TOP 1 Seed_Version FROM dbo.blackwall_seed ORDER BY Loaded_At DESC")
    versao = cur.fetchval() or "?"
    conn.close()
    return out, versao


def main() -> None:
    dados, versoes = {}, {}
    for base_key in ORDEM:
        dados[base_key], versoes[base_key] = contar(base_key)

    largura = max(len(t) for t in TABS) + 2
    print(f"{'tabela':<{largura}}" + "".join(f"{c:>14}" for c in COLUNAS))
    print("-" * (largura + 14 * len(COLUNAS)))
    total = 0
    for tabela in TABS:
        linha = f"{tabela:<{largura}}"
        for base_key in COLUNAS:
            n = dados[base_key][tabela]
            linha += f"{'-':>14}" if n < 0 else f"{n:>14,}"
            total += max(n, 0)
        print(linha)
    print("-" * (largura + 14 * len(COLUNAS)))
    print(f"{'TOTAL':<{largura}}{total:>14,}")
    print("\nversao do seed: " + ", ".join(f"{b}={versoes[b]}" for b in COLUNAS))


if __name__ == "__main__":
    main()
