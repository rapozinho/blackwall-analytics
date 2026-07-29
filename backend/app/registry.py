# -*- coding: utf-8 -*-
"""Registry de gráficos. Adicionar gráfico = adicionar 1 entrada aqui.

Cada entrada: id, label, description, bases suportadas, params (spec p/ o form)
e loader `load(base_key, params) -> dict`. O frontend descobre tudo via /api.
"""
from .charts import retention_cohort

CHARTS = {
    "retention_cohort": {
        "id": "retention_cohort",
        "label": "Retention Cohort",
        "description": "Retenção de cohorts por GGR, Turnover, Deposits e Netcash.",
        "bases": ["F12", "Luva", "BrasilBet"],  # GaleraBet: habilitar quando tiver retention
        "params": retention_cohort.PARAMS,
        "load": retention_cohort.load,
    },
    # Próximos gráficos entram aqui (bpa, monitoring, ...).
}


def public_meta(chart: dict) -> dict:
    """Versão serializável (sem o callable `load`)."""
    return {k: chart[k] for k in ("id", "label", "description", "bases", "params")}


def charts_for_base(base_key: str) -> list[dict]:
    return [public_meta(c) for c in CHARTS.values() if base_key in c["bases"]]
