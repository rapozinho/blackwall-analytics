# -*- coding: utf-8 -*-
"""Gráfico: Retention Cohort por GGR/Turnover/Deposits/Netcash.

Lógica portada do kpi-bot (Queries/Graphics/retention_cohort.py).
O SQL vive no catálogo (`app/sql/graphics/retention_cohort.sql`, convenção de
placeholders do bot) e é PARAMETRIZADO por `sqlcat.to_parameterized()` antes de
executar — datas nunca interpoladas.

  - Cohort  = usuários cujo FTD (ftd_agg.FTD_Date) cai no mês de aquisição.
  - Mes-idx = DATEDIFF(month, Cohort_Month, Month_Ref); começa em 0.
  - GGR/Turnover = casino+sports; Deposits/Netcash = payments (Completed).
"""
from datetime import datetime

from .. import vertical
from ..db import run_query
from ..sqlcat import load_sql, to_parameterized

# --- catálogo de métricas -------------------------------------------------- #
# `players` = qual contador de jogadores divide a métrica na variante média.
# Quem aposta e quem deposita não são o mesmo conjunto: dividir GGR pelo total de
# quem movimentou pagamento incluiria quem depositou e não jogou.
_METRICS = {
    "ggr":      {"label": vertical.t("ggr"),      "col": "ggr",      "players": "players_jogo"},
    "turnover": {"label": vertical.t("turnover"), "col": "turnover", "players": "players_jogo"},
    "deposits": {"label": vertical.t("cohort_metric_deposits"), "col": "deposit",
                 "players": "players_pagto"},
    "netcash":  {"label": vertical.t("cohort_metric_netcash"),  "col": "netcash",
                 "players": "players_pagto"},
}
_METRIC_ORDER = ["ggr", "turnover", "deposits", "netcash"]

# --- variantes ------------------------------------------------------------- #
# total     -> soma da safra no mês (comportamento original)
# avg       -> soma / jogadores ativos da safra naquele mês
# agregado  -> soma corrida das médias ao longo dos meses (curva de LTV)
_VARIANTS = {
    "total": {
        "label": "Total",
        "hint": "Soma da métrica por safra em cada mês.",
        # "k": o gráfico plota em milhar; "abs": plota o valor cheio.
        "unit": "k",
        "suffix": "",
        "axis": vertical.t("cohort_eixo_total"),
    },
    "avg": {
        "label": vertical.t("cohort_variant_avg"),
        "hint": vertical.t("cohort_variant_avg_hint"),
        "unit": "abs",
        "suffix": "_medio",
        "axis": vertical.t("cohort_eixo_medio"),
    },
    "agregado": {
        "label": "Agregado",
        "hint": (f"Média por {vertical.t('unidade_cliente')} acumulada mês a mês "
                 "(mês 1 = mês 0 + mês 1)."),
        "unit": "abs",
        "suffix": "_medio_acumulado",
        "axis": vertical.t("cohort_eixo_acum"),
    },
}
_VARIANT_ORDER = ["total", "avg", "agregado"]

# --- spec de parâmetros (o frontend monta o form a partir disto) ----------- #
PARAMS = {
    "date_start": {"type": "date", "label": "Início", "required": True},
    "date_end":   {"type": "date", "label": "Fim", "required": True},
    "variant": {
        "type": "select", "label": "Visão", "required": True,
        "default": "total",
        "options": [
            {"value": k, "label": _VARIANTS[k]["label"], "hint": _VARIANTS[k]["hint"]}
            for k in _VARIANT_ORDER
        ],
    },
    "metrics": {
        "type": "multiselect", "label": "Métricas", "required": True,
        "default": ["ggr"],
        "options": [{"value": k, "label": _METRICS[k]["label"]} for k in _METRIC_ORDER],
    },
}

# Tabelas lidas pelo _SQL. Usado por /api/health/db para checar grants/nomes.
REQUIRED_TABLES = ("ftd_agg", "casino_agg_hourly", "sports_agg_hourly", "payments_agg_hourly")

# "jogador" na vertical de apostas, "cliente" no e-commerce.
_UNIDADE = vertical.t("unidade_cliente")

_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


def _cohort_label(c: str) -> str:
    y, m = c.split("-")
    return f"{_MONTHS[int(m) - 1]}-{y[2:]}"


def _fmt_k(v):
    if v is None:
        return "-"
    if abs(v) < 1e-9:
        return "0"
    a = abs(v)
    if a >= 1000:
        return f"{v / 1000:.1f}".rstrip("0").rstrip(".") + "M"
    if abs(v - round(v)) < 1e-9:
        return f"{int(round(v))}k"
    return f"{v:.1f}k"


_SQL_FILE = "graphics/retention_cohort.sql"


def _pontos(linhas: list[dict], spec: dict, variant: str) -> list[list]:
    """Pontos [mes_index, valor_plotado, valor_exato] de um cohort.

    No "total" o gráfico plota em milhar (herdado do bot) e o valor exato vai no
    tooltip. Nas variantes por jogador os dois são o mesmo número: dividir uma
    média de R$ 500 por mil viraria 0,5k na escala.
    """
    col, players_col = spec["col"], spec["players"]
    dados = sorted(
        ((int(r["mes_index"]), float(r[col] or 0), int(r[players_col] or 0)) for r in linhas),
        key=lambda t: t[0],
    )

    pts: list[list] = []
    acumulado = 0.0
    for mes, valor, players in dados:
        if variant == "total":
            pts.append([mes, round(valor / 1000.0, 2), round(valor, 2)])
            continue

        # Mês sem jogador ativo não tem média — o ponto some da curva em vez de
        # virar zero, que leria como "faturou nada" em vez de "ninguém jogou".
        if players <= 0:
            continue

        media = valor / players
        if variant == "avg":
            pts.append([mes, round(media, 2), round(media, 2)])
        else:                                   # agregado: soma corrida das médias
            acumulado += media
            pts.append([mes, round(acumulado, 2), round(acumulado, 2)])

    return pts


def _fmt_brl(v) -> str:
    """R$ 1.234,56 — usado nas variantes por jogador, onde o valor é pequeno e
    plotar em milhar viraria '0,5k'."""
    if v is None:
        return "-"
    s = f"{v:,.2f}".replace(",", "\x00").replace(".", ",").replace("\x00", ".")
    return f"R$ {s}"


def _fmt(v, unit: str) -> str:
    return _fmt_k(v) if unit == "k" else _fmt_brl(v)


def _analytics(series: dict, ml: str, variant: str, unit: str) -> dict:
    labels = list(series.keys())
    n = len(labels)
    ymap = {c: {p[0]: p[1] for p in pts} for c, pts in series.items()}

    # No agregado o ponto já vem acumulado: somar de novo contaria duas vezes.
    if variant == "agregado":
        acum = {c: d[max(d)] for c, d in ymap.items() if d}
    else:
        acum = {c: sum(d.values()) for c, d in ymap.items()}

    m0 = [d.get(0) for d in ymap.values() if d.get(0) is not None]
    m0_mean = sum(m0) / len(m0) if m0 else None
    decays = [1 - d[1] / d[0] for d in ymap.values() if d.get(0) and d[0] > 0 and 1 in d]
    decay_mean = sum(decays) / len(decays) if decays else None
    best = max(acum, key=acum.get) if acum else None
    worst = min(acum, key=acum.get) if acum else None
    maturity = {c: max(d.keys()) + 1 for c, d in ymap.items()}
    recent = labels[-1] if labels else None
    neg = sum(1 for d in ymap.values() for y in d.values() if y < 0)

    comuns = [{"label": "Cohorts analisados", "value": str(n)}]
    recente = {"label": "Cohort mais recente",
               "value": f"{recent} · {maturity[recent]} m" if recent else "-"}

    if variant == "total":
        kpis = comuns + [
            {"label": f"{ml} total (período)", "value": _fmt(sum(acum.values()), unit)},
            {"label": f"{ml} médio no mês 0", "value": _fmt(m0_mean, unit)},
            {"label": "Queda média M0→M1",
             "value": f"{decay_mean*100:.0f}%" if decay_mean is not None else "-"},
            {"label": f"Melhor cohort ({ml} acum.)",
             "value": f"{best} · {_fmt(acum[best], unit)}" if best else "-"},
            recente,
        ]
    elif variant == "avg":
        kpis = comuns + [
            {"label": f"{ml} médio no mês 0 (por {_UNIDADE})", "value": _fmt(m0_mean, unit)},
            {"label": "Queda média M0→M1",
             "value": f"{decay_mean*100:.0f}%" if decay_mean is not None else "-"},
            {"label": "Melhor cohort (soma das médias)",
             "value": f"{best} · {_fmt(acum[best], unit)}" if best else "-"},
            recente,
        ]
    else:                                     # agregado
        kpis = comuns + [
            {"label": f"{ml} médio no mês 0 (por {_UNIDADE})", "value": _fmt(m0_mean, unit)},
            {"label": "Melhor cohort (acumulado final)",
             "value": f"{best} · {_fmt(acum[best], unit)}" if best else "-"},
            {"label": "Pior cohort (acumulado final)",
             "value": f"{worst} · {_fmt(acum[worst], unit)}" if worst else "-"},
            recente,
        ]

    por_cliente = f" por {_UNIDADE} ativo" if variant != "total" else ""
    ins = []
    if n:
        ins.append(f"{n} cohort(s) no período; mais recente ({recent}) com {maturity[recent]} mês(es).")
    if best and worst and best != worst:
        rotulo = "acumulado final" if variant == "agregado" else "acumulado"
        ins.append(f"Maior {ml}{por_cliente} {rotulo}: <b>{best}</b> ({_fmt(acum[best], unit)}); "
                   f"menor: <b>{worst}</b> ({_fmt(acum[worst], unit)}).")
    if decay_mean is not None and variant != "agregado":
        t = "forte" if decay_mean >= 0.6 else ("moderada" if decay_mean >= 0.3 else "suave")
        ins.append(f"Queda {t} do mês 0 para o 1: em média <b>{decay_mean*100:.0f}%</b>.")
    if variant == "avg":
        ins.append("A curva mede quem <b>continuou ativo</b>: o denominador encolhe junto com a "
                   "safra, então subir aqui não significa mais receita — significa receita mais "
                   "concentrada em quem ficou.")
    if variant == "agregado":
        ins.append("Curva sempre crescente por construção: cada mês soma a média do anterior. "
                   "O que importa é a <b>inclinação</b> — onde ela achata, a safra parou de render.")
    if neg:
        ins.append(f"⚠️ {neg} ponto(s) com {ml} negativo.")
    if not ins:
        ins.append("Sem dados suficientes para insights.")
    return {"kpis": kpis, "insights": ins}


def load(base_key: str, params: dict, on_progress=None) -> dict:
    """Valida params, roda query parametrizada e devolve JSON do gráfico.

    `on_progress(pct, step)` vem do job runner; query única, então só marca
    início e fim."""
    start = (params.get("date_start") or "").strip()
    end = (params.get("date_end") or "").strip()
    try:
        d_ini = datetime.strptime(start, "%Y-%m-%d")
        d_fim = datetime.strptime(end, "%Y-%m-%d")
    except (ValueError, TypeError):
        raise ValueError("Datas inválidas (use AAAA-MM-DD).")
    if d_fim < d_ini:
        raise ValueError("Período inválido: fim antes do início.")

    raw = params.get("metrics") or ["ggr"]
    if isinstance(raw, str):
        raw = [m.strip() for m in raw.split(",") if m.strip()]
    metrics = [k for k in _METRIC_ORDER if k in set(raw)]  # whitelist + ordem
    if not metrics:
        raise ValueError("Selecione ao menos uma métrica.")

    variant = (params.get("variant") or "total").strip()
    if variant not in _VARIANTS:
        raise ValueError(f"Visão inválida: {variant!r}.")
    spec_var = _VARIANTS[variant]

    if on_progress:
        on_progress(0, "Consultando retenção")
    sql, sql_params = to_parameterized(
        load_sql(_SQL_FILE), {"start1": start, "end1": end}
    )
    rows = run_query(base_key, sql, sql_params)  # parametrizado

    periodo = f"{d_ini.strftime('%d/%m/%Y')} – {d_fim.strftime('%d/%m/%Y')}"
    if not rows:
        return {"base": base_key, "periodo": periodo, "empty": True,
                "message": "Sem dados de retenção para o período."}

    out_metrics = []
    cohorts = sorted({r["cohort"] for r in rows if r.get("cohort")})
    for k in metrics:
        spec = _METRICS[k]
        series = {}
        for coh in cohorts:
            pts = _pontos([r for r in rows if r["cohort"] == coh], spec, variant)
            if pts:
                series[_cohort_label(coh)] = pts
        a = _analytics(series, spec["label"], variant, spec_var["unit"])
        out_metrics.append({
            "key": k,
            "label": spec["label"],
            # `col` nomeia a coluna na tabela e no CSV: precisa dizer qual visão é.
            "col": spec["col"] + spec_var["suffix"],
            "unit": spec_var["unit"],
            "axis": spec_var["axis"].format(m=spec["label"]),
            "series": [{"label": l, "points": p} for l, p in series.items()],
            "kpis": a["kpis"], "insights": a["insights"],
        })

    return {
        "base": base_key, "periodo": periodo, "empty": False,
        "variant": variant, "variant_label": spec_var["label"],
        # "jogador" / "cliente": o texto do subtítulo depende da vertical.
        "unidade_ativo": _UNIDADE,
        "metrics": out_metrics,
    }
