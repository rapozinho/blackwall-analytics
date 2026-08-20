# -*- coding: utf-8 -*-
"""Catalogo de SQL em arquivo (`app/sql/`).

Os `.sql` usam a convencao de placeholders do kpi-bot (`{start1}`,
`{end1}`, ...) para que o mesmo arquivo sirva aos dois projetos. O bot injeta
com `.format()`; aqui NUNCA interpolamos: `to_parameterized()` troca cada
placeholder por `?` e devolve os valores na ordem, para o pyodbc.

Adicionar SQL novo = criar o arquivo em `app/sql/<grupo>/<nome>.sql`.
"""
import re
from functools import lru_cache
from pathlib import Path

SQL_DIR = Path(__file__).resolve().parent / "sql"

# Placeholders suportados. `affiliate_ids` fica de fora de proposito: no catalogo
# do bot ele aparece em duas formas (`IN ({affiliate_ids})` e `= {affiliate_ids}`)
# e a conversao correta depende de qual. Tratar quando portar esses reports.
_NAMES = ("start1", "end1", "start2", "end2")
_ALT = "|".join(_NAMES)

# Casa `'{start1}'` (aspas do bot) e `{start1}` (sem aspas). As aspas somem junto
# com o placeholder: `'?'` seria literal de string, nao parametro.
_PLACEHOLDER = re.compile(rf"'\{{({_ALT})\}}'|\{{({_ALT})\}}")

_UNSUPPORTED = re.compile(r"\{(affiliate_ids)\}")


@lru_cache(maxsize=None)
def load_sql(relpath: str) -> str:
    """Le um `.sql` do catalogo. Cacheado: o arquivo nao muda em runtime.

    `relpath` e relativo a `app/sql/` (ex.: "graphics/retention_cohort.sql")
    e nunca vem do cliente — sempre hardcoded no modulo do grafico.
    """
    path = (SQL_DIR / relpath).resolve()
    if not path.is_relative_to(SQL_DIR):
        raise ValueError(f"Caminho fora do catalogo: {relpath!r}")
    if not path.is_file():
        raise FileNotFoundError(f"SQL nao encontrado no catalogo: {relpath}")
    return path.read_text(encoding="utf-8")


def _trailing_number(name: str) -> int:
    """`zephyr_bpa_query_10.sql` -> 10. Sem numero vai pro fim (mesma regra do bot)."""
    digits = "".join(c for c in Path(name).stem.split("_")[-1] if c.isdigit())
    return int(digits) if digits else 999


@lru_cache(maxsize=None)
def list_sql(subdir: str, prefix: str) -> tuple[str, ...]:
    """Relpaths dos `.sql` de `subdir` que comecam com `prefix`, em ordem numerica.

    Usado pelos reports com numero variavel de queries por base (bpa tem 6 na
    Zephyr e 7 na Lumen).
    """
    d = (SQL_DIR / subdir).resolve()
    if not d.is_relative_to(SQL_DIR) or not d.is_dir():
        raise FileNotFoundError(f"Pasta nao encontrada no catalogo: {subdir}")
    names = sorted((f.name for f in d.glob(f"{prefix}*.sql")), key=_trailing_number)
    return tuple(f"{subdir}/{n}" for n in names)


def _skip_noncode(sql: str, i: int) -> int:
    """Se `i` inicia comentario ou literal de string, devolve o fim dessa regiao.
    Senao devolve `i`. Evita trocar placeholder citado em comentario."""
    n = len(sql)
    if sql.startswith("--", i):
        j = sql.find("\n", i)
        return n if j == -1 else j
    if sql.startswith("/*", i):
        j = sql.find("*/", i)
        return n if j == -1 else j + 2
    if sql[i] == "'":
        j = i + 1
        while j < n:
            if sql[j] == "'":
                if j + 1 < n and sql[j + 1] == "'":   # '' escapado
                    j += 2
                    continue
                return j + 1
            j += 1
        return n
    return i


def to_parameterized(sql: str, values: dict) -> tuple[str, list]:
    """Converte os placeholders do catalogo em `?` posicionais.

    Devolve (sql, params) na ordem em que os placeholders aparecem — repetir o
    mesmo placeholder gera um `?` (e um valor) por ocorrencia, como o pyodbc
    espera. Comentarios e literais de string passam intactos.
    """
    params: list = []
    out: list[str] = []
    missing: set[str] = set()
    i, n = 0, len(sql)

    while i < n:
        # Placeholder primeiro: `'{start1}'` comeca com aspa e seria confundido
        # com literal de string.
        m = _PLACEHOLDER.match(sql, i)
        if m:
            name = m.group(1) or m.group(2)
            if name in values:
                params.append(values[name])
                out.append("?")
            else:
                missing.add(name)
                out.append(m.group(0))
            i = m.end()
            continue

        bad = _UNSUPPORTED.match(sql, i)
        if bad:
            raise ValueError(
                f"Placeholder {{{bad.group(1)}}} ainda nao suportado: "
                "a forma correta (IN (...) vs = ...) depende do report."
            )

        end = _skip_noncode(sql, i)
        if end > i:
            out.append(sql[i:end])
            i = end
            continue

        out.append(sql[i])
        i += 1

    if missing:
        raise ValueError("Faltando valor para: " + ", ".join(sorted(missing)))
    return "".join(out), params
