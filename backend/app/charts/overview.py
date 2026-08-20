# -*- coding: utf-8 -*-
"""Dashboard Overview — KPIs, serie diaria e mix (pizzas) numa consulta so.

Diferente dos reports tabulares (`reports/tabular.py`), que existem para virar
CSV, aqui a saida e desenhada para leitura na tela: cada KPI ja vem com rotulo,
formato e comparacao contra o periodo anterior.

O periodo de comparacao NAO e pedido no filtro: e a janela de mesma duracao
imediatamente anterior. Comparar jul/30d com jun/30d e a pergunta que a mesa faz
99% das vezes; quem quiser dois periodos arbitrarios usa o Big Picture.

As 4 queries sao independentes e rodam duas a duas (ver `_PARALELAS`): na Zephyr com
30 dias isso fecha em ~65s contra ~130s de soma sequencial.
"""
from concurrent.futures import ThreadPoolExecutor, as_completed
from contextvars import copy_context
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Callable

from .. import vertical
from ..db import run_query
from ..sqlcat import load_sql, to_parameterized

BASES = ["Zephyr", "Quasar", "Lumen", "Kestrel"]

REQUIRED_TABLES = [
    "casino_agg_hourly", "sports_agg_hourly",
    "payments_agg_hourly", "ftd_agg", "acquisitions_agg",
]

PARAMS = {
    "date_start": {"type": "date", "label": "Início", "required": True},
    "date_end":   {"type": "date", "label": "Fim", "required": True},
}

_SQL_DIR = "_common/overview"

# Consultas simultaneas por execucao. Mais nao e mais rapido: medido na Zephyr/30d,
# 4 conexoes levaram 159s e 2 levaram 65s — as quatro brigam pelo mesmo I/O e o
# servidor ainda e compartilhado com os bots.
_PARALELAS = 2

# (chave, coluna do ov_kpis, formato)
# `formato` diz ao frontend como imprimir: moeda, inteiro, fracao 0..1 ou razao.
# Rotulo e dica vem de `vertical.py`: a mesma coluna e "GGR" na vertical de
# apostas e "Receita" na de e-commerce. A `chave` nao muda — o frontend usa ela.
_KPI_SPEC = [
    ("ggr",       "GGR",       "currency"),
    ("ngr",       "NGR",       "currency"),
    ("turnover",  "Turnover",  "currency"),
    ("margem",    "Margem",    "percent"),
    ("hold",      "Hold",      "percent"),
    ("depositos", "Depositos", "currency"),
    ("saques",    "Saques",    "currency"),
    ("netcash",   "Netcash",   "currency"),
    ("ftds",      "FTDs",      "int"),
    ("registros", "Registros", "int"),
    ("uap",       "UAP",       "int"),
    ("arpu",      "ARPU",      "currency"),
]


def _num(v) -> float:
    """pyodbc devolve Decimal; JSON nao aceita. None vira 0 para nao quebrar soma."""
    if v is None:
        return 0.0
    if isinstance(v, Decimal):
        return float(v)
    return float(v)


def _parse_date(raw: str, field: str) -> date:
    try:
        return datetime.strptime((raw or "").strip(), "%Y-%m-%d").date()
    except (ValueError, TypeError):
        raise ValueError(f"Data inválida em '{field}' (use AAAA-MM-DD).")


def _periodos(params: dict) -> tuple[dict, str, str]:
    """Valida o periodo e deriva a janela de comparacao (mesma duracao, colada)."""
    ini = _parse_date(params.get("date_start"), "date_start")
    fim = _parse_date(params.get("date_end"), "date_end")
    if fim < ini:
        raise ValueError("Período inválido: fim antes do início.")

    dias = (fim - ini).days + 1
    fim2 = ini - timedelta(days=1)
    ini2 = fim2 - timedelta(days=dias - 1)

    fmt = "%d/%m/%Y"
    values = {
        "start1": ini.isoformat(), "end1": fim.isoformat(),
        "start2": ini2.isoformat(), "end2": fim2.isoformat(),
    }
    return (values,
            f"{ini.strftime(fmt)} – {fim.strftime(fmt)}",
            f"{ini2.strftime(fmt)} – {fim2.strftime(fmt)}")


def _delta(atual: float, anterior: float, formato: str) -> tuple[float | None, str]:
    """Variacao contra o periodo anterior.

    Percentual (Hold/Margem) varia em pontos percentuais — dizer que o hold
    'subiu 12%' quando foi de 60% para 67% confunde a mesa. Os demais variam em %.
    Sem base de comparacao (anterior = 0) nao existe variacao: devolve None em vez
    de infinito.
    """
    if formato == "percent":
        return (atual - anterior) * 100, "pp"
    if anterior == 0:
        return None, "pct"
    return (atual - anterior) / abs(anterior) * 100, "pct"


def _kpis(p1: dict, p2: dict) -> list[dict]:
    out = []
    for key, col, formato in _KPI_SPEC:
        atual, anterior = _num(p1.get(col)), _num(p2.get(col))
        variacao, unidade = _delta(atual, anterior, formato)
        out.append({
            "key": key, "label": vertical.t(key), "format": formato,
            "hint": vertical.t(f"{key}_hint"),
            "value": atual, "previous": anterior,
            "delta": variacao, "delta_unit": unidade,
            # Saque/custo subindo nao e boa noticia: o frontend colore por isto,
            # nao pelo sinal da variacao.
            "higher_is_better": key not in ("saques",),
        })
    return out


def _serie(rows: list[dict]) -> list[dict]:
    """Serie diaria enxuta. Semana/mes sao agregados no frontend."""
    return [{
        "dia": r["Dia"].isoformat() if isinstance(r["Dia"], (date, datetime)) else str(r["Dia"]),
        "ggr": _num(r["GGR"]),
        "ggr_casino": _num(r["GGR_Casino"]),
        "ggr_sports": _num(r["GGR_Sports"]),
        "ngr": _num(r["NGR"]),
        "turnover": _num(r["Turnover"]),
        "depositos": _num(r["Depositos"]),
        "saques": _num(r["Saques"]),
        "netcash": _num(r["Netcash"]),
        "ftds": int(_num(r["FTDs"])),
    } for r in rows]


def _donut(donut_id: str, label: str, descricao: str, metricas: list[dict],
           slices: list[dict]) -> dict:
    """Pizza com mais de uma metrica: o frontend troca sem voltar ao banco."""
    return {
        "id": donut_id, "label": label, "description": descricao,
        "metrics": metricas,
        "slices": [s for s in slices if any(s["values"].get(m["key"]) for m in metricas)],
    }


def _mix(provider_rows: list[dict], channel_rows: list[dict]) -> list[dict]:
    verticais = [r for r in provider_rows if r["Escopo"] == "Vertical"]
    provedores = [r for r in provider_rows if r["Escopo"] == "Provedor"]

    metricas_jogo = [
        {"key": "ggr", "label": vertical.t("ggr"), "format": "currency"},
        {"key": "turnover", "label": vertical.t("turnover"), "format": "currency"},
        {"key": "apostas", "label": vertical.t("itens"), "format": "int"},
    ]
    # `Nome` do escopo Vertical vem do SQL como 'Casino'/'Sportsbook' (literal no
    # ov_provider.sql, que nao e alterado): `traduz` troca pelo par da vertical.
    fatia_jogo = lambda r: {                                    # noqa: E731
        "label": vertical.traduz(r["Nome"]),
        "values": {"ggr": _num(r["GGR"]), "turnover": _num(r["Turnover"]),
                   "apostas": _num(r["Apostas"])},
    }

    return [
        _donut("vertical", vertical.t("donut_vertical"),
               vertical.t("donut_vertical_desc"),
               metricas_jogo, [fatia_jogo(r) for r in verticais]),
        _donut("provedor", vertical.t("donut_provedor"),
               vertical.t("donut_provedor_desc"),
               metricas_jogo, [fatia_jogo(r) for r in provedores]),
        _donut("canal", vertical.t("donut_canal"),
               vertical.t("donut_canal_desc"),
               [{"key": "ggr", "label": vertical.t("ggr"), "format": "currency"},
                {"key": "ftds", "label": vertical.t("ftds"), "format": "int"},
                {"key": "registros", "label": vertical.t("registros"), "format": "int"},
                {"key": "ativos", "label": vertical.t("uap"), "format": "int"}],
               [{
                   "label": vertical.traduz(r["Canal"]),
                   "values": {"ggr": _num(r["GGR"]), "ftds": _num(r["FTDs"]),
                              "registros": _num(r["Registros"]),
                              "ativos": _num(r["Jogadores_Ativos"])},
               } for r in channel_rows]),
    ]


def _notas(p1: dict) -> list[str]:
    """Avisos sobre o dado, nao sobre a consulta. Aparecem no rodape do painel."""
    notas = []
    if _num(p1.get("GGR_Sports")) != 0 and _num(p1.get("NGR_Sports")) == 0:
        notas.append(vertical.t("nota_ngr_zero"))
    return notas


def load(base_key: str, params: dict, on_progress: Callable | None = None) -> dict:
    values, periodo, periodo_anterior = _periodos(params)

    consultas = [
        ("kpis",       "ov_kpis",       "Indicadores do período"),
        ("timeseries", "ov_timeseries", "Série diária"),
        ("channel",    "ov_channel",    "Canais de aquisição"),
        ("provider",   "ov_provider",   "Provedores e verticais"),
    ]

    feito = 0

    def executar(item):
        chave, arquivo, _ = item
        sql, sql_params = to_parameterized(load_sql(f"{_SQL_DIR}/{arquivo}.sql"), values)
        return chave, run_query(base_key, sql, sql_params)

    resultados: dict[str, list[dict]] = {}
    if on_progress:
        on_progress(2, "Consultando " + ", ".join(c[2].lower() for c in consultas))

    # `as_completed` e nao `map`: com map o progresso so andaria na ordem da lista
    # e a fila inteira ficaria presa atras da consulta mais lenta (a de KPIs).
    # `copy_context()` por tarefa: sem isso as threads filhas não sabem a qual job
    # pertencem e o "encerrar consulta" não derrubaria estas queries. Um contexto
    # por submit — o mesmo objeto Context não pode ser executado em paralelo.
    with ThreadPoolExecutor(max_workers=_PARALELAS, thread_name_prefix="ov") as pool:
        futuros = {pool.submit(copy_context().run, executar, c): c for c in consultas}
        for futuro in as_completed(futuros):
            chave, rows = futuro.result()
            resultados[chave] = rows
            feito += 1
            if on_progress:
                rotulo = futuros[futuro][2]
                on_progress(int(feito / len(consultas) * 100), f"{rotulo} ({feito}/{len(consultas)})")

    linhas = {r["Periodo"]: r for r in resultados["kpis"]}
    p1, p2 = linhas.get("P1", {}), linhas.get("P2", {})
    serie = _serie(resultados["timeseries"])

    return {
        "base": base_key,
        "kind": "dashboard",
        "periodo": periodo,
        "periodo_anterior": periodo_anterior,
        "empty": not serie and not _num(p1.get("GGR")),
        "kpis": _kpis(p1, p2),
        "series": serie,
        "donuts": _mix(resultados["provider"], resultados["channel"]),
        "notes": _notas(p1),
        # Vocabulario para a linha do tempo: as chaves da serie sao fixas
        # (`ggr`, `ggr_casino`, ...) e o rotulo depende da vertical. Vai no proprio
        # payload para o frontend nao precisar de uma segunda chamada.
        "labels": vertical.meta()["series"],
        "verticais": vertical.meta()["verticais"],
    }
