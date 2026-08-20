# -*- coding: utf-8 -*-
"""Compila todo o catalogo de SQL contra as bases de demonstracao.

Por que existe: as bases ficticias foram modeladas a partir dos 292 arquivos de
T-SQL do catalogo, nao o contrario. Uma coluna que falte no schema so aparece
quando a query roda — e algumas rodam so num report que leva minutos. Este script
faz o servidor *compilar* cada arquivo (`SET NOEXEC ON`: resolve tabela, coluna e
tipo, sem executar) e lista o que quebrou, em segundos.

Uso (de dentro do container `dbinit`, que tem o driver ODBC):

    docker compose run --rm --entrypoint python dbinit verify_catalog.py
    docker compose run --rm --entrypoint python dbinit verify_catalog.py --executar

`--executar` roda de verdade os arquivos usados pelo Overview e pelo Retention
Cohort e mostra quantas linhas cada um devolveu — serve para checar se o dado
gerado casa com os filtros do catalogo (report vazio e falha de dado, nao de
schema).
"""
import os
import re
import sys
import time
from pathlib import Path

import pyodbc

from bases import BASES

CATALOGO = Path(os.getenv("SQL_CATALOG", "/catalog"))
SERVIDOR = os.getenv("SEED_SERVER", "sqlserver")
DRIVER = os.getenv("ODBC_DRIVER", "ODBC Driver 18 for SQL Server")
USUARIO = os.getenv("DB_USER", "blackwall_ro")
SENHA = os.environ["DB_PASSWORD"]

# Periodo de teste: dois meses dentro da janela dos dados gerados.
VALORES = {"start1": "2026-06-01", "end1": "2026-06-30",
           "start2": "2026-05-01", "end2": "2026-05-31"}

# Arquivos que o backend nunca carrega: sao os dumps de referencia trazidos do
# bot (nomes de tabela de outro sistema). Ficam no repositorio como documentacao.
IGNORADOS = {"queries.sql", "casino.sql", "sports.sql", "crm.sql", "acquisition-all.sql"}

# Vazio esperado: o `.sql` de bonus da Lumen esta inteiro comentado no catalogo,
# porque aquela base nao tem a coluna `turnover_bonus`. Devolver nada e o
# comportamento correto, e o Report Master deixa a celula em branco.
VAZIO_ESPERADO = {"Lumen/report_master/casino/lumen_rmc_bonus.sql"}

_PLACEHOLDER = re.compile(r"'\{(start1|end1|start2|end2)\}'|\{(start1|end1|start2|end2)\}")


def preparar(sql: str) -> str:
    """Troca os placeholders do catalogo por literais de data.

    O backend usa `sqlcat.to_parameterized()` (marcador posicional + pyodbc);
    aqui o literal basta e mantem o script independente do backend.
    """
    return _PLACEHOLDER.sub(lambda m: f"'{VALORES[m.group(1) or m.group(2)]}'", sql)


def base_do_arquivo(rel: Path) -> str | None:
    """`Zephyr/bpa/...` -> Zephyr. `_common/` e `graphics/` valem para as 4."""
    topo = rel.parts[0]
    return topo if topo in BASES else None


def conectar(base_key: str) -> pyodbc.Connection:
    return pyodbc.connect(
        f"DRIVER={{{DRIVER}}};SERVER={SERVIDOR};DATABASE={BASES[base_key]['database']};"
        f"UID={USUARIO};PWD={SENHA};Encrypt=yes;TrustServerCertificate=yes;",
        timeout=15, autocommit=True)


def arquivos() -> list[Path]:
    return sorted(p for p in CATALOGO.rglob("*.sql") if p.name not in IGNORADOS)


def compilar(executar: bool = False) -> int:
    todos = arquivos()
    if not todos:
        print(f"nenhum .sql em {CATALOGO} — monte o catalogo no container.")
        return 2

    conexoes = {b: conectar(b) for b in BASES}
    falhas: list[tuple[str, str]] = []
    vazios: list[str] = []
    total = 0
    inicio = time.monotonic()

    for caminho in todos:
        rel = caminho.relative_to(CATALOGO)
        base = base_do_arquivo(rel)
        # Arquivo base-agnostico: compila nas 4, que e onde ele roda de verdade.
        alvos = [base] if base else list(BASES)
        sql = preparar(caminho.read_text(encoding="utf-8"))

        for alvo in alvos:
            total += 1
            # `Zephyr/bpa/x.sql` ja diz a base; so o arquivo comum precisa do prefixo.
            rotulo = str(rel) if base else f"{alvo}: {rel}"
            cur = conexoes[alvo].cursor()
            try:
                if executar:
                    cur.execute(sql)
                    linhas = 0
                    while cur.description is None and cur.nextset():
                        pass
                    if cur.description is not None:
                        linhas = len(cur.fetchall())
                    if linhas == 0 and str(rel).replace("\\", "/") not in VAZIO_ESPERADO:
                        vazios.append(rotulo)
                else:
                    cur.execute("SET NOEXEC ON;\n" + sql + "\nSET NOEXEC OFF;")
            except pyodbc.Error as e:
                msg = " ".join(str(e).split())
                falhas.append((rotulo, msg[:220]))
            finally:
                cur.close()

    dur = time.monotonic() - inicio
    modo = "executados" if executar else "compilados"
    print(f"\n{total} arquivos {modo} em {dur:.1f}s — {len(falhas)} com erro")
    for nome, msg in falhas:
        print(f"\n  X {nome}\n    {msg}")
    if executar and vazios:
        print(f"\n{len(vazios)} devolveram 0 linhas (dado nao casa com o filtro):")
        for nome in vazios:
            print(f"  - {nome}")
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(compilar(executar="--executar" in sys.argv))
