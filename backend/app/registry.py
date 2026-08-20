# -*- coding: utf-8 -*-
"""Registry de gráficos e reports. Adicionar = adicionar 1 entrada aqui.

Cada entrada: id, label, description, bases suportadas, params (spec p/ o form),
`kind` (como o frontend renderiza) e loader `load(base_key, params, on_progress=None)`.
O frontend descobre tudo via /api.

Rotulo, descricao e spec de filtro NAO ficam prontos aqui: dependem do idioma
da requisicao (e a descricao, tambem da vertical). O registry guarda a chave e o
callable; `public_meta()` resolve na hora de responder.

`kind`:
  - "dashboard" -> painel de leitura (KPIs, série, pizzas)
  - "chart"     -> view dedicada (ex.: RetentionCohortView)
  - "tables"    -> tabelas genéricas (reports portados do bot), saída p/ CSV

O `kind` também separa as duas seções da galeria: "dashboard"/"chart" ficam em
Dashboards; "tables" em Extrações.
"""
from functools import partial

from . import vertical
from .charts import overview, retention_cohort
from .i18n import msg
from .reports import report_master, tabular

CHARTS = {
    "overview": {
        "id": "overview",
        # `label_msg`/`desc_termo` sao chaves, nao texto: o rotulo depende do
        # idioma e a descricao tambem da vertical, e as duas coisas so' se sabem
        # na requisicao. Nome proprio (Monitoring, Report Master) fica em `label`.
        "label_msg": "chart_overview",
        "desc_termo": "overview_desc",
        "bases": overview.BASES,
        "kind": "dashboard",
        "params": overview.params,
        "load": overview.load,
        "required_tables": overview.REQUIRED_TABLES,
    },
    "retention_cohort": {
        "id": "retention_cohort",
        "label": "Retention Cohort",
        "desc_termo": "retention_desc",
        "bases": ["Zephyr", "Quasar", "Lumen"],  # Kestrel: habilitar quando tiver retention
        "kind": "chart",
        "params": retention_cohort.params,
        "load": retention_cohort.load,
        "required_tables": retention_cohort.REQUIRED_TABLES,
    },
}

CHARTS["report_master"] = {
    "id": "report_master",
    "label": "Report Master",
    "desc_termo": "report_master_desc",
    "bases": report_master.BASES,
    "kind": "tables",
    "params": report_master.params,
    "load": report_master.load,
    "required_tables": report_master.REQUIRED_TABLES,
}

# Reports tabulares (Monitoring, Big Picture) — mesmo SQL do kpi-bot.
for _rid, _spec in tabular.SPECS.items():
    CHARTS[_rid] = {
        "id": _rid,
        "label": _spec["label"],
        "desc_termo": _spec["desc_termo"],
        "bases": _spec["bases"],
        "kind": "tables",
        # `partial` e nao lambda: no lambda o `_rid` do for seria capturado por
        # referencia e todos os reports ficariam com o filtro do ultimo.
        "params": partial(tabular.params, _rid),
        "load": tabular.make_loader(_rid),
    }

_PUBLIC_FIELDS = ("id", "bases", "kind")


def label(chart: dict) -> str:
    """Nome do relatorio na tela. Nome proprio nao se traduz."""
    return msg(chart["label_msg"]) if "label_msg" in chart else chart["label"]


def public_meta(chart: dict) -> dict:
    """Versao serializavel (sem o callable `load`), resolvida no idioma e na
    vertical da requisicao."""
    out = {k: chart[k] for k in _PUBLIC_FIELDS}
    out["label"] = label(chart)
    out["description"] = vertical.t(chart["desc_termo"])
    out["params"] = chart["params"]()
    return out


def charts_for_base(base_key: str) -> list[dict]:
    return [public_meta(c) for c in CHARTS.values() if base_key in c["bases"]]


def required_tables_for_base(base_key: str) -> list[str]:
    """Uniao das tabelas lidas por todos os graficos habilitados na base."""
    names: set[str] = set()
    for chart in CHARTS.values():
        if base_key in chart["bases"]:
            names.update(chart.get("required_tables", ()))
    return sorted(names)
