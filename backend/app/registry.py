# -*- coding: utf-8 -*-
"""Registry de gráficos e reports. Adicionar = adicionar 1 entrada aqui.

Cada entrada: id, label, description, bases suportadas, params (spec p/ o form),
`kind` (como o frontend renderiza) e loader `load(base_key, params, on_progress=None)`.
O frontend descobre tudo via /api.

`kind`:
  - "dashboard" -> painel de leitura (KPIs, série, pizzas)
  - "chart"     -> view dedicada (ex.: RetentionCohortView)
  - "tables"    -> tabelas genéricas (reports portados do bot), saída p/ CSV

O `kind` também separa as duas seções da galeria: "dashboard"/"chart" ficam em
Dashboards; "tables" em Extrações.
"""
from . import vertical
from .charts import overview, retention_cohort
from .reports import report_master, tabular

CHARTS = {
    "overview": {
        "id": "overview",
        "label": "Overview operacional",
        # Descricao vem da vertical: o mesmo painel fala de GGR ou de receita.
        "description": vertical.t("overview_desc"),
        "bases": overview.BASES,
        "kind": "dashboard",
        "params": overview.PARAMS,
        "load": overview.load,
        "required_tables": overview.REQUIRED_TABLES,
    },
    "retention_cohort": {
        "id": "retention_cohort",
        "label": "Retention Cohort",
        "description": vertical.t("retention_desc"),
        "bases": ["Zephyr", "Quasar", "Lumen"],  # Kestrel: habilitar quando tiver retention
        "kind": "chart",
        "params": retention_cohort.PARAMS,
        "load": retention_cohort.load,
        "required_tables": retention_cohort.REQUIRED_TABLES,
    },
}

CHARTS["report_master"] = {
    "id": "report_master",
    "label": "Report Master",
    "description": vertical.t("report_master_desc"),
    "bases": report_master.BASES,
    "kind": "tables",
    "params": report_master.PARAMS,
    "load": report_master.load,
    "required_tables": report_master.REQUIRED_TABLES,
}

# Reports tabulares (Monitoring, Big Picture) — mesmo SQL do kpi-bot.
for _rid, _spec in tabular.SPECS.items():
    _params = dict(tabular._PERIOD_1)
    if _spec["dual_period"]:
        _params.update(tabular._PERIOD_2)
    CHARTS[_rid] = {
        "id": _rid,
        "label": _spec["label"],
        "description": _spec["description"],
        "bases": _spec["bases"],
        "kind": "tables",
        "params": _params,
        "load": tabular.make_loader(_rid),
    }

_PUBLIC_FIELDS = ("id", "label", "description", "bases", "kind", "params")


def public_meta(chart: dict) -> dict:
    """Versão serializável (sem o callable `load`)."""
    return {k: chart[k] for k in _PUBLIC_FIELDS}


def charts_for_base(base_key: str) -> list[dict]:
    return [public_meta(c) for c in CHARTS.values() if base_key in c["bases"]]


def required_tables_for_base(base_key: str) -> list[str]:
    """Uniao das tabelas lidas por todos os graficos habilitados na base."""
    names: set[str] = set()
    for chart in CHARTS.values():
        if base_key in chart["bases"]:
            names.update(chart.get("required_tables", ()))
    return sorted(names)
