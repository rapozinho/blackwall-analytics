# -*- coding: utf-8 -*-
"""Gráfico: Retention Cohort por GGR/Turnover/Deposits/Netcash.

Lógica portada do kpi_bot_telegram (Queries/Graphics/retention_cohort.py),
mas com SQL PARAMETRIZADO (pyodbc `?`) — datas nunca interpoladas.

  - Cohort  = usuários cujo FTD (ftd_agg.FTD_Date) cai no mês de aquisição.
  - Mes-idx = DATEDIFF(month, Cohort_Month, Month_Ref); começa em 0.
  - GGR/Turnover = casino+sports; Deposits/Netcash = payments (Completed).
"""
from datetime import datetime

from ..db import run_query

# --- catálogo de métricas -------------------------------------------------- #
_METRICS = {
    "ggr":      {"label": "GGR",      "col": "ggr"},
    "turnover": {"label": "Turnover", "col": "turnover"},
    "deposits": {"label": "Deposits", "col": "deposit"},
    "netcash":  {"label": "Netcash",  "col": "netcash"},
}
_METRIC_ORDER = ["ggr", "turnover", "deposits", "netcash"]

# --- spec de parâmetros (o frontend monta o form a partir disto) ----------- #
PARAMS = {
    "date_start": {"type": "date", "label": "Início", "required": True},
    "date_end":   {"type": "date", "label": "Fim", "required": True},
    "metrics": {
        "type": "multiselect", "label": "Métricas", "required": True,
        "default": ["ggr"],
        "options": [{"value": k, "label": _METRICS[k]["label"]} for k in _METRIC_ORDER],
    },
}

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


_SQL = """
DECLARE @cohort_start DATE = DATEADD(month, DATEDIFF(month, 0, CAST(? AS DATE)), 0);
DECLARE @activity_end DATE = CAST(? AS DATE);
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @activity_end);

WITH CohortUsers AS (
    SELECT DISTINCT ftd.User_Id,
           DATEADD(month, DATEDIFF(month, 0, ftd.FTD_Date), 0) AS Cohort_Month
    FROM ftd_agg ftd WITH(NOLOCK)
    WHERE ftd.FTD_Date >= @cohort_start AND ftd.FTD_Date < @data_fim_exclusive
),
CohortActivity AS (
    SELECT c.Cohort_Month, DATEADD(month, DATEDIFF(month, 0, a.Date_Agg), 0) AS Month_Ref,
           a.Turnover AS turnover, a.GGR AS ggr, 0 AS deposit, 0 AS netcash
    FROM CohortUsers c
    INNER JOIN casino_agg_hourly a WITH(NOLOCK) ON c.User_Id = a.User_Id
    WHERE a.Date_Agg >= c.Cohort_Month AND a.Date_Agg < @data_fim_exclusive
    UNION ALL
    SELECT c.Cohort_Month, DATEADD(month, DATEDIFF(month, 0, s.Date_Agg), 0),
           s.Turnover, s.GGR, 0, 0
    FROM CohortUsers c
    INNER JOIN sports_agg_hourly s WITH(NOLOCK) ON c.User_Id = s.User_Id
    WHERE s.Date_Agg >= c.Cohort_Month AND s.Date_Agg < @data_fim_exclusive
    UNION ALL
    SELECT c.Cohort_Month, DATEADD(month, DATEDIFF(month, 0, p.Date_Agg), 0),
           0, 0, p.Deposits_Amount, p.Netcash
    FROM CohortUsers c
    INNER JOIN payments_agg_hourly p WITH(NOLOCK) ON c.User_Id = p.User_Id
    WHERE p.Status = 'Completed' AND p.Date_Agg >= c.Cohort_Month AND p.Date_Agg < @data_fim_exclusive
)
SELECT FORMAT(Cohort_Month, 'yyyy-MM') AS cohort,
       DATEDIFF(month, Cohort_Month, Month_Ref) AS mes_index,
       SUM(turnover) AS turnover, SUM(ggr) AS ggr,
       SUM(deposit) AS deposit, SUM(netcash) AS netcash
FROM CohortActivity
WHERE Month_Ref >= Cohort_Month
GROUP BY Cohort_Month, DATEDIFF(month, Cohort_Month, Month_Ref)
ORDER BY cohort, mes_index;
"""


def _analytics(series: dict, ml: str) -> dict:
    labels = list(series.keys())
    n = len(labels)
    ymap = {c: {p[0]: p[1] for p in pts} for c, pts in series.items()}
    acum = {c: sum(d.values()) for c, d in ymap.items()}
    total = sum(acum.values())
    m0 = [d.get(0) for d in ymap.values() if d.get(0) is not None]
    m0_mean = sum(m0) / len(m0) if m0 else None
    decays = [1 - d[1] / d[0] for d in ymap.values() if d.get(0) and d[0] > 0 and 1 in d]
    decay_mean = sum(decays) / len(decays) if decays else None
    best = max(acum, key=acum.get) if acum else None
    worst = min(acum, key=acum.get) if acum else None
    maturity = {c: max(d.keys()) + 1 for c, d in ymap.items()}
    recent = labels[-1] if labels else None
    neg = sum(1 for d in ymap.values() for y in d.values() if y < 0)

    kpis = [
        {"label": "Cohorts analisados", "value": str(n)},
        {"label": f"{ml} total (período)", "value": _fmt_k(total)},
        {"label": f"{ml} médio no mês 0", "value": _fmt_k(m0_mean) if m0_mean is not None else "-"},
        {"label": "Queda média M0→M1", "value": f"{decay_mean*100:.0f}%" if decay_mean is not None else "-"},
        {"label": f"Melhor cohort ({ml} acum.)", "value": f"{best} · {_fmt_k(acum[best])}" if best else "-"},
        {"label": "Cohort mais recente", "value": f"{recent} · {maturity[recent]} m" if recent else "-"},
    ]
    ins = []
    if n:
        ins.append(f"{n} cohort(s) no período; mais recente ({recent}) com {maturity[recent]} mês(es).")
    if best and worst and best != worst:
        ins.append(f"Maior {ml} acumulado: <b>{best}</b> ({_fmt_k(acum[best])}); menor: <b>{worst}</b> ({_fmt_k(acum[worst])}).")
    if decay_mean is not None:
        t = "forte" if decay_mean >= 0.6 else ("moderada" if decay_mean >= 0.3 else "suave")
        ins.append(f"Queda {t} do mês 0 para o 1: em média <b>{decay_mean*100:.0f}%</b>.")
    if neg:
        ins.append(f"⚠️ {neg} ponto(s) com {ml} negativo.")
    if not ins:
        ins.append("Sem dados suficientes para insights.")
    return {"kpis": kpis, "insights": ins}


def load(base_key: str, params: dict) -> dict:
    """Valida params, roda query parametrizada e devolve JSON do gráfico."""
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

    rows = run_query(base_key, _SQL, (start, end))  # parametrizado

    periodo = f"{d_ini.strftime('%d/%m/%Y')} – {d_fim.strftime('%d/%m/%Y')}"
    if not rows:
        return {"base": base_key, "periodo": periodo, "empty": True,
                "message": "Sem dados de retenção para o período."}

    out_metrics = []
    for k in metrics:
        col = _METRICS[k]["col"]
        cohorts = sorted({r["cohort"] for r in rows if r.get("cohort")})
        series = {}
        for coh in cohorts:
            pts = sorted(
                ([int(r["mes_index"]), round(float(r[col] or 0) / 1000.0, 2), round(float(r[col] or 0), 2)]
                 for r in rows if r["cohort"] == coh),
                key=lambda p: p[0],
            )
            series[_cohort_label(coh)] = pts
        a = _analytics(series, _METRICS[k]["label"])
        out_metrics.append({
            "key": k, "label": _METRICS[k]["label"], "col": col,
            "series": [{"label": l, "points": p} for l, p in series.items()],
            "kpis": a["kpis"], "insights": a["insights"],
        })

    return {"base": base_key, "periodo": periodo, "empty": False, "metrics": out_metrics}
