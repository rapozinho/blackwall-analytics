# -*- coding: utf-8 -*-
"""Reports tabulares: N arquivos SQL -> N tabelas.

Portado do kpi-bot, que gera xlsx com uma aba por arquivo `.sql`. Aqui
a saida e JSON e o frontend renderiza uma tabela por arquivo. Sem pandas: o
`run_query` ja devolve lista de dicts.

Diferenca proposital em relacao ao bot: o bot monta o SQL com `.format()`; aqui
passa por `sqlcat.to_parameterized()` (marcador posicional + pyodbc).
"""
import re
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path
from typing import Callable

from .. import vertical
from ..db import run_query
from ..sqlcat import list_sql, load_sql, to_parameterized

ALL_BASES = ["Zephyr", "Quasar", "Lumen", "Kestrel"]

# --- specs de parametros --------------------------------------------------- #
_PERIOD_1 = {
    "date_start": {"type": "date", "label": "Início", "required": True},
    "date_end":   {"type": "date", "label": "Fim", "required": True},
}
_PERIOD_2 = {
    "date_start2": {"type": "date", "label": "Início (comparação)", "required": True},
    "date_end2":   {"type": "date", "label": "Fim (comparação)", "required": True},
}

# --- catalogo de reports --------------------------------------------------- #
# `files` = lista fixa; `prefix` = varre a pasta (numero de queries varia por base).
SPECS = {
    "monitoring": {
        "label": "Monitoring",
        "description": vertical.t("monitoring_desc"),
        "bases": ALL_BASES,
        "folder": "monitoring",
        "files": ["{p}_monitoring_query.sql", "{p}_monitoring_affiliates_query.sql"],
        "dual_period": True,
        "labels": {"monitoring_query": "Geral", "monitoring_affiliates_query": "Afiliados"},
    },
    "bp_acquisition": {
        "label": "Big Picture - Acquisition",
        "description": vertical.t("bpa_desc"),
        "bases": ALL_BASES,
        "folder": "bpa",
        "prefix": "{p}_bpa_query_",
        "dual_period": True,
        # Cada bpa_query_N devolve 1 linha (um canal) com o MESMO schema — no bot
        # sao abas separadas, aqui viram uma tabela unica. `merge_label` nomeia a
        # 1a coluna, que vem sem nome do SQL.
        "merge": {"name": vertical.t("bpa_merge_nome"), "file": "bpa.csv",
                  "first_column": "Canal"},
    },
    "bp_distribution": {
        "label": "Big Picture - Distribution",
        "description": vertical.t("bpd_desc"),
        "bases": ALL_BASES,
        "folder": "bpd",
        "prefix": "{p}_bpd_query_",
        "dual_period": False,
    },
}


# Nome de coluna que indica percentual: `FTD_Percent`, `[Var % GGR]`, ...
_PERCENT_NAME = re.compile(r"percent|%", re.IGNORECASE)


def _percent_columns(columns: list[str], rows: list[list]) -> list[str]:
    """Colunas a exibir com sufixo '%'.

    O SQL devolve numero puro (o `+ '%'` foi removido do catalogo) e o simbolo
    e formatacao do frontend. Exige valores numericos: se alguma linha vier como
    texto a coluna nao entra, para nao gerar '12,34%%'.
    """
    out = []
    for i, name in enumerate(columns):
        if not _PERCENT_NAME.search(name or ""):
            continue
        vals = [r[i] for r in rows if r[i] is not None]
        if vals and all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in vals):
            out.append(name)
    return out


def _jsonable(v):
    """pyodbc devolve Decimal/datetime; JSON nao aceita nenhum dos dois."""
    if isinstance(v, Decimal):
        return float(v)
    if isinstance(v, (datetime, date)):
        return v.isoformat()
    if isinstance(v, (bytes, bytearray)):
        return v.hex()
    return v


def _parse_date(raw: str, field: str) -> datetime:
    try:
        return datetime.strptime((raw or "").strip(), "%Y-%m-%d")
    except (ValueError, TypeError):
        raise ValueError(f"Data inválida em '{field}' (use AAAA-MM-DD).")


def _values(spec: dict, params: dict) -> tuple[dict, str]:
    """Valida params e devolve (valores p/ placeholders, descricao do periodo)."""
    ini = _parse_date(params.get("date_start"), "date_start")
    fim = _parse_date(params.get("date_end"), "date_end")
    if fim < ini:
        raise ValueError("Período inválido: fim antes do início.")

    fmt = "%d/%m/%Y"
    values = {"start1": ini.strftime("%Y-%m-%d"), "end1": fim.strftime("%Y-%m-%d")}
    periodo = f"{ini.strftime(fmt)} – {fim.strftime(fmt)}"

    if spec["dual_period"]:
        ini2 = _parse_date(params.get("date_start2"), "date_start2")
        fim2 = _parse_date(params.get("date_end2"), "date_end2")
        if fim2 < ini2:
            raise ValueError("Período de comparação inválido: fim antes do início.")
        values["start2"] = ini2.strftime("%Y-%m-%d")
        values["end2"] = fim2.strftime("%Y-%m-%d")
        periodo += f"  vs  {ini2.strftime(fmt)} – {fim2.strftime(fmt)}"

    return values, periodo


def _files(spec: dict, base_key: str) -> list[str]:
    """Catalogo e organizado por base: `sql/<Base>/<report>/<base>_....sql`.

    O prefixo do nome do arquivo e redundante com a pasta, mas mantem o nome
    identico ao do kpi-bot — facilita diff quando o SQL mudar la.
    """
    prefix = base_key.lower()          # Zephyr -> zephyr, Lumen -> lumen
    folder = f"{base_key}/{spec['folder']}"
    if "prefix" in spec:
        return list(list_sql(folder, spec["prefix"].format(p=prefix)))
    return [f"{folder}/{f.format(p=prefix)}" for f in spec["files"]]


def _table_label(spec: dict, relpath: str, base_key: str) -> str:
    """`zephyr_bpa_query_3.sql` -> 'Query 3'; monitoring usa rotulo do spec."""
    stem = Path(relpath).stem
    suffix = stem[len(base_key) + 1:] if stem.lower().startswith(base_key.lower()) else stem
    explicit = spec.get("labels", {}).get(suffix)
    if explicit:
        # Passa pelo vocabulario da vertical como qualquer outro texto de saida:
        # a aba "Afiliados" e "Parceiros" no e-commerce.
        return vertical.traduz(explicit)
    tail = suffix.split("_")[-1]
    if tail.isdigit():
        return f"Query {tail}"
    return vertical.traduz(suffix.replace("_", " ").title())


def _table(spec: dict, relpath: str, base_key: str, rows: list[dict]) -> dict:
    # Sem linhas o pyodbc nao entrega nomes de coluna: tabela vazia sem header.
    columns = list(rows[0].keys()) if rows else []
    name = Path(relpath).name
    out_rows = [[_jsonable(r.get(c)) for c in columns] for r in rows]

    # Vocabulario da vertical: o SQL devolve 'Total_GGR' e 'Internal Traffic';
    # no e-commerce a tela mostra 'Total_Receita' e 'Tráfego interno'. Na vertical
    # `bet` `traduz` e identidade. As colunas sao traduzidas ANTES do
    # `_percent_columns` porque a deteccao de percentual olha o nome — e os nomes
    # traduzidos preservam o `%`/`Percent`.
    columns = [vertical.traduz(c) for c in columns]
    if vertical.VERTICAL != "bet":
        out_rows = [[vertical.traduz(v) for v in linha] for linha in out_rows]

    return {
        "name": _table_label(spec, relpath, base_key),
        "file": name,
        "sources": [name],
        "columns": columns,
        "percent_columns": _percent_columns(columns, out_rows),
        "rows": out_rows,
    }


def _merge(tables: list[dict], cfg: dict) -> list[dict]:
    """Junta tabelas de mesmo schema numa so (bpa: 1 linha por arquivo).

    Se algum schema divergir devolve as tabelas separadas — melhor mostrar
    N tabelas do que empilhar colunas trocadas.
    """
    schemas = {tuple(t["columns"]) for t in tables if t["columns"]}
    if len(schemas) != 1:
        return tables

    columns = list(next(iter(schemas)))
    if cfg.get("first_column") and columns and not columns[0]:
        columns[0] = cfg["first_column"]

    rows = [r for t in tables for r in t["rows"]]
    return [{
        "name": cfg["name"],
        "file": cfg["file"],
        "sources": [s for t in tables for s in t["sources"]],
        "columns": columns,
        # Recalcula no conjunto unido: se uma das origens trouxer texto na coluna,
        # ela deixa de ser percentual para todas.
        "percent_columns": _percent_columns(columns, rows),
        "rows": rows,
    }]


def make_loader(report_id: str) -> Callable:
    """Devolve o `load(base, params, on_progress=None)` do report."""
    spec = SPECS[report_id]

    def load(base_key: str, params: dict, on_progress: Callable | None = None) -> dict:
        values, periodo = _values(spec, params)
        files = _files(spec, base_key)
        if not files:
            raise ValueError(f"Nenhum SQL no catálogo para {report_id}/{base_key}.")

        tables = []
        for i, relpath in enumerate(files):
            label = _table_label(spec, relpath, base_key)
            if on_progress:
                on_progress(int(i / len(files) * 100), f"{label} ({i + 1}/{len(files)})")
            sql, sql_params = to_parameterized(load_sql(relpath), values)
            tables.append(_table(spec, relpath, base_key, run_query(base_key, sql, sql_params)))

        if spec.get("merge") and len(tables) > 1:
            tables = _merge(tables, spec["merge"])

        return {
            "base": base_key,
            "periodo": periodo,
            "kind": "tables",
            "empty": all(not t["rows"] for t in tables),
            "tables": tables,
        }

    load.__name__ = f"load_{report_id}"
    return load
