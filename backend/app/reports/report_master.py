# -*- coding: utf-8 -*-
"""Report Master — replica da planilha do kpi-bot.

O bot gera um xlsx com 5 abas; cada aba e uma LINHA larga (Date, Site, Order e
~50 metricas). Aqui sai a mesma coisa em JSON: uma tabela por aba, cabecalhos na
ordem da referencia, para o front renderizar e exportar CSV.

Diferencas em relacao ao bot, todas deliberadas:

  - As formulas do Excel (`=F2+G2`) sao calculadas em Python. O CSV do bot leva
    formula; aqui leva numero, que e o que serve para conferir.
  - Percentual sai como numero de 0 a 100 (o SQL devolve fracao). O front so
    acrescenta o "%", entao a conversao precisa acontecer antes.
  - As 76 queries rodam duas a duas (ver `_PARALELAS`), nao em sequencia.

Cada `.sql` devolve uma linha unica com uma ou mais colunas nomeadas; o dicionario
`valores` junta todas com a chave em minusculas, do mesmo jeito que o bot monta o
`rm_values`. As duas queries multi-linha (top 5 btags, online marketing) viram
linhas extras na aba de aquisicao.
"""
from concurrent.futures import ThreadPoolExecutor, as_completed
from contextvars import copy_context
from datetime import date, datetime
from decimal import Decimal
from typing import Callable

from .. import vertical
from ..db import run_query
from ..i18n import msg
from ..sqlcat import load_sql, to_parameterized

# Kestrel nao tem Report Master no catalogo do bot.
BASES = ["Zephyr", "Quasar", "Lumen"]

REQUIRED_TABLES = ("casino_agg_hourly", "sports_agg_hourly", "payments_agg_hourly",
                   "ftd_agg", "acquisitions_agg")

def params() -> dict:
    """Spec do filtro. Funcao porque o rotulo depende do idioma da requisicao."""
    return {
        "date_start": {"type": "date", "label": msg("param_inicio"), "required": True},
        "date_end":   {"type": "date", "label": msg("param_fim"), "required": True},
    }

# Duas conexoes: mesmo motivo do Overview — mais paralelismo briga pelo mesmo I/O
# e o servidor e compartilhado com os bots.
_PARALELAS = 2

# --- catalogo de queries (mesma lista do bot) ------------------------------- #
_OO = ["ngr", "ngr_pct", "narpu", "ggr", "ggr_pct", "arpu", "turnover", "turnover_pct", "toau",
       "ngr_dep", "ngr_dep_pct", "unique_gamblers", "uap_pct", "gamblers_daily_avg",
       "gamblers_casino_daily_avg", "gamblers_sports_daily_avg", "margin", "margin_pct",
       "netcash", "netcash_pct", "deposits", "deposits_pct", "withdrawals", "registrations",
       "registrations_pct", "ftds", "ftds_pct", "hold", "hold_pct", "hold_casino", "hold_sports"]
_CASINO = ["ngr", "ngr_pct", "ggr", "ggr_pct", "turnover", "margin_pct", "avg_bet", "avg_bet_pct",
           "unique_gamblers", "unique_gamblers_pct", "bonus"]
_SPORTS = ["ngr", "ngr_pct", "ggr", "ggr_pct", "turnover", "gamblers_daily_avg",
           "gamblers_daily_avg_pct", "unique_mtd", "avg_bet", "avg_bet_pct", "margin_pct"]
_CRM = ["active_players", "active_players_pct", "retention_rate", "retention_rate_pct",
        "reativations", "reativations_pct", "churn", "ggr", "gamblers_ngr"]
_ACQ = ["registrations", "ftds", "global_ggr", "ggr_all_cohort", "ggr_cohort",
        "ggr_all_cohort_global", "ggr_cohort_global", "global_turnover", "turnover_all_cohort",
        "turnover_cohort", "turnover_all_cohort_global", "turnover_cohort_global",
        "top5_btags", "online_marketing"]

_GRUPOS = [
    ("operational_overview", "rm", _OO),
    ("casino", "rmc", _CASINO),
    ("sports", "rms", _SPORTS),
    ("crm", "rmcrm", _CRM),
    ("acquisition", "rma", _ACQ),
]

# Estas devolvem varias linhas (uma por btag / por canal), nao um escalar.
_MULTILINHA = {"top5_btags", "online_marketing"}


def _arquivos(base_key: str) -> list[tuple[str, str]]:
    """(relpath, rotulo) de cada query do relatorio, na ordem do bot."""
    p = base_key.lower()
    out = [(f"{base_key}/report_master/{pasta}/{p}_{prefixo}_{nome}.sql", f"{pasta}/{nome}")
           for pasta, prefixo, nomes in _GRUPOS for nome in nomes]
    # Cohort de GGR da propria base (pasta "Acquisition - <Base>" no bot).
    out.append((f"{base_key}/report_master/acquisition/{p}_acq_cohort_ggr.sql",
                "acquisition/cohort_ggr"))
    return out


# --- layout das abas -------------------------------------------------------- #
# `dados` mapeia coluna da planilha -> nome da coluna devolvida pelo SQL (minusculas).
# `percent` sao as colunas que o Excel formata como 0.00% — o valor vem em fracao
# e e multiplicado por 100 aqui.
# `formulas` substituem as formulas do Excel; a ORDEM importa (Y alimenta U/W/X).
_ABAS = [
    {
        "nome": "Operational Overview",
        "headers": [
            "Date", "Site", "Order", "NGR", "NGR %", "NGR - Casino", "NGR - Sports", "NARPU/Unique",
            "GGR", "GGR %", "GGR - Casino", "GGR - Sports", "ARPU/Unique",
            "Turnover", "Turnover %", "Turnover - Casino", "Turnover - Sports", "TOAU/Unique",
            "NGR/DEP", "NGR/DEP %", "Generosity", "Generosity %", "Generosity - Casino",
            "Generosity - Sports", "Bonus", "Bonus - Casino", "Bonus - Sports",
            "Unique Gamblers MTD", "Unique Gamblers MTD %", "Gamblers (Daily AVG)",
            "Gamblers Casino (Daily AVG)", "Gamblers Sports (Daily AVG)",
            "Margin", "Margin %", "Margin - Casino", "Margin - Sports",
            "Netcash", "Netcash %", "Deposits", "Deposits %", "withdrawals",
            "Registration", "Registration %", "FTDs", "FTDs %",
            "Hold (NGR/GGR)", "Hold (NGR/GGR) %", "Hold (NGR/GGR) - Casino", "Hold (NGR/GGR) - Sports",
        ],
        "dados": {
            "E": "ngr %", "F": "ngr_casino", "G": "ngr_sportsbook", "H": "narpu/unique",
            "I": "ggr_total", "J": "ggr %", "K": "casino_ggr", "L": "sports_ggr",
            "M": "arpu/unique", "N": "total_turnover", "O": "turnover %",
            "P": "casino_turnover", "Q": "sports_turnover", "R": "toau_unique",
            "S": "ngr/dep", "T": "ngr/dep %", "Z": "bonus - casino", "AA": "bonus - sports",
            "AB": "uap", "AC": "unique gamblers mtd %", "AD": "media_diaria_uap",
            "AE": "media_diaria_casino", "AF": "media_diaria_sports",
            "AG": "margin", "AH": "margin %", "AK": "netcash", "AL": "netcash %",
            "AM": "deposits", "AN": "deposits %", "AO": "withdrawals",
            "AP": "qtd_registros", "AQ": "registration %", "AR": "ftds", "AS": "ftds %",
            "AT": "hold (ngr/ggr)", "AU": "hold (ngr/ggr) %",
            "AV": "hold (ngr/ggr) - casino", "AW": "hold (ngr/ggr) - sports",
        },
        "formulas": [
            ("D", lambda v: _soma(v, "F", "G")),      # NGR = casino + sports
            ("Y", lambda v: _soma(v, "Z", "AA")),     # Bonus = casino + sports
            ("U", lambda v: _div(v, "Y", "I")),       # Generosity = bonus / GGR
            ("W", lambda v: _div(v, "Z", "K")),
            ("X", lambda v: _div(v, "AA", "L")),
            ("AI", lambda v: _div(v, "K", "P")),      # Margin casino = GGR / turnover
            ("AJ", lambda v: _div(v, "L", "Q")),
        ],
        "percent": {"E", "J", "O", "S", "T", "U", "V", "W", "X", "AC", "AG", "AH", "AI", "AJ",
                    "AL", "AN", "AQ", "AS", "AT", "AU", "AV", "AW"},
    },
    {
        "nome": "Casino",
        "headers": [
            "Data", "Site", "Order", "NGR - Casino", "NGR - Casino %", "GGR - Casino",
            "GGR - Casino %", "Turnover - Casino", "Margin - Casino", "Margin - Casino %",
            "AVG Bet", "AVG Bet %", "Unique Gamblers", "Unique Gamblers %",
            "Generosity", "Generosity %", "Bonus - Casino",
        ],
        "dados": {
            "D": "ngr - casino", "E": "ngr - casino %", "F": "ggr - casino",
            "G": "ggr - casino %", "H": "turnover - casino", "J": "margin - casino %",
            "K": "avg bet", "L": "avg bet %", "M": "unique gamblers",
            "N": "unique gamblers %", "Q": "bonus - casino",
        },
        "formulas": [
            ("I", lambda v: _div(v, "F", "H")),       # Margin = GGR / turnover
            ("O", lambda v: _div(v, "Q", "F")),       # Generosity = bonus / GGR
        ],
        "percent": {"E", "G", "I", "J", "L", "N", "O", "P"},
    },
    {
        "nome": "Sports",
        "headers": [
            "Data", "Site", "Order", "NGR - Sports", "NGR - Sports %", "GGR - Sports",
            "GGR - Sports %", "Turnover - Sports", "Gamblers (Daily AVG)", "Gamblers (Daily AVG) %",
            "Unique MTD - Sports", "AVG Bet - Sports (Amount)", "AVG Bet - Sports (Amount) %",
            "Margin - Sports", "Margin - Sports %", "Generosity - Sports", "Generosity - Sports %",
            "Bonus - Sports",
        ],
        "dados": {
            "D": "ngr - sports", "E": "ngr - sports %", "F": "ggr - sports",
            "G": "ggr - sports %", "H": "turnover - sports", "I": "gamblers (daily avg)",
            "J": "gamblers (daily avg) %", "K": "unique mtd - sports",
            "L": "avg bet - sports (amount)", "M": "avg bet - sports (amount) %",
            "O": "margin - sports %", "R": "bonus - sports",
        },
        "formulas": [
            ("N", lambda v: _div(v, "F", "H")),
            ("P", lambda v: _div(v, "R", "F")),
        ],
        "percent": {"E", "G", "J", "M", "N", "O", "P", "Q"},
    },
    {
        "nome": "CRM",
        "headers": [
            "Data", "Site", "Order", "Cost", "Active Players", "Active Players %",
            "Retention Rate", "Retention Rate %", "Reactivations", "Reactivations Rate",
            "Reactivations %", "Churn", "Generosity", "Generosity %", "Bonus", "GGR",
            "Segment", "Gamblers", "% Base", "NGR",
        ],
        "dados": {
            "E": "active players", "F": "active players %", "G": "retention rate",
            "H": "retention rate %", "I": "reactivations", "K": "reactivations %",
            "L": "churn", "P": "ggr",
        },
        "formulas": [
            ("J", lambda v: _div(v, "I", "E")),       # Reactivations Rate
        ],
        "percent": {"F", "G", "H", "J", "K", "L", "M", "S"},
        # A aba tem 3 linhas extras (um segmento por linha), como na referencia.
        "segmentos": {
            "coluna": "Q",
            "linhas": [
                {"rotulo": "Negative", "valores": {"R": "negative", "T": "ngr negative"}},
                {"rotulo": "Core", "valores": {"R": "core", "T": "ngr core"}},
                {"rotulo": "VIP", "valores": {"R": "vip", "T": "ngr vip"}},
            ],
            # % Base divide sempre pelo Active Players da primeira linha.
            "formula_pct_base": "S",
        },
    },
    {
        "nome": "Acquisition - All",
        "headers": [
            "Date", "Site", "Order", "Registrations", "FTDs", "Investiment", "CPA", "Global GGR",
            "GGR All Cohort", "GGR All Cohort (Global)", "GGR/FTD", "GGR Cohort",
            "GGR Cohort (Global)", "% GGR",
            "Global Turnover", "Turnover All Cohort", "Turnover All Cohort (Global)",
            "Turnover Cohort", "Turnover Cohort (Global)", "% Turnover",
            "Top 5 Btags", "FTDs Top 5", "% FTDs", "Online Marketing",
            "Investiment - Online", "FTDs - Online", "CPA - Online", "LTV - Online", "ROI - Online",
        ],
        "dados": {
            "D": "registrations", "E": "ftds", "H": "global ggr", "I": "ggr all cohort",
            "J": "ggr all cohort (global)", "L": "ggr cohort", "M": "ggr cohort (global)",
            "O": "global turnover", "P": "turnover all cohort",
            "Q": "turnover all cohort (global)", "R": "turnover cohort",
            "S": "turnover cohort (global)",
        },
        "formulas": [
            ("G", lambda v: _div(v, "F", "E")),       # CPA = investimento / FTDs
            ("K", lambda v: _div(v, "L", "E")),       # GGR/FTD
            ("N", lambda v: _div(v, "L", "H")),       # % GGR
            ("T", lambda v: _div(v, "R", "O")),       # % Turnover
        ],
        "percent": {"N", "T", "W"},
        # Dois blocos multi-linha lado a lado, cada um com seu proprio comprimento.
        "grupos": [
            {"rotulo_col": "U", "rotulo_key": "top 5 btags",
             "valor_col": "V", "valor_key": "ftds top 5", "pct_col": "W"},
            {"rotulo_col": "X", "rotulo_key": "online marketing",
             "valor_col": "Z", "valor_key": "ftds - online", "pct_col": None},
        ],
    },
]


# --- utilidades ------------------------------------------------------------- #
def _num(v):
    """Decimal/None -> float/None. Texto passa direto (rotulo de btag, canal)."""
    if v is None:
        return None
    if isinstance(v, Decimal):
        return float(v)
    if isinstance(v, (int, float)) and not isinstance(v, bool):
        return float(v)
    if isinstance(v, (datetime, date)):
        return v.isoformat()
    return v


def _soma(vals: dict, *cols: str):
    partes = [vals.get(c) for c in cols]
    numeros = [p for p in partes if isinstance(p, (int, float))]
    return sum(numeros) if numeros else None


def _div(vals: dict, num: str, den: str):
    a, b = vals.get(num), vals.get(den)
    if not isinstance(a, (int, float)) or not isinstance(b, (int, float)) or b == 0:
        return None
    return a / b


def _letra(indice: int) -> str:
    """0 -> A, 25 -> Z, 26 -> AA. Casa a posicao do header com a letra do Excel."""
    nome = ""
    indice += 1
    while indice:
        indice, resto = divmod(indice - 1, 26)
        nome = chr(65 + resto) + nome
    return nome


def _parse_date(raw: str, campo: str) -> datetime:
    try:
        return datetime.strptime((raw or "").strip(), "%Y-%m-%d")
    except (ValueError, TypeError):
        raise ValueError(msg("erro_data_campo", campo=campo))


# --- montagem das abas ------------------------------------------------------ #
def _colunas_percentuais(aba: dict) -> list[str]:
    """Nomes de header das colunas percentuais — o front usa isto para o sufixo %."""
    return [aba["headers"][i] for i in range(len(aba["headers"]))
            if _letra(i) in aba.get("percent", set())]


def _linha(aba: dict, celulas: dict) -> list:
    """Converte {letra: valor} na lista de celulas na ordem dos headers."""
    percent = aba.get("percent", set())
    saida = []
    for i in range(len(aba["headers"])):
        letra = _letra(i)
        v = celulas.get(letra)
        # Percentual chega como fracao (0,0250) e sai como 2,50.
        if letra in percent and isinstance(v, (int, float)):
            v = v * 100
        saida.append(v)
    return saida


def _tabela(aba: dict, base_key: str, valores: dict, frames: dict, dia: str) -> dict:
    base_cells: dict = {"A": dia, "B": base_key, "C": 1}

    for letra, chave in aba["dados"].items():
        base_cells[letra] = valores.get(chave)
    for letra, formula in aba["formulas"]:
        base_cells[letra] = formula(base_cells)

    linhas = [_linha(aba, base_cells)]

    # CRM: um segmento por linha, repetindo Date/Site e numerando a ordem.
    seg = aba.get("segmentos")
    if seg:
        linhas = []
        ativos = base_cells.get("E")
        for i, item in enumerate(seg["linhas"]):
            celulas = dict(base_cells) if i == 0 else {"A": dia, "B": base_key}
            celulas["C"] = i + 1
            celulas[seg["coluna"]] = item["rotulo"]
            for letra, chave in item["valores"].items():
                celulas[letra] = valores.get(chave)
            gamblers = celulas.get("R")
            if isinstance(gamblers, (int, float)) and isinstance(ativos, (int, float)) and ativos:
                celulas[seg["formula_pct_base"]] = gamblers / ativos
            linhas.append(_linha(aba, celulas))

    # Acquisition: os blocos multi-linha definem quantas linhas a aba tem.
    grupos = aba.get("grupos")
    if grupos:
        alturas = [len(frames.get(g["rotulo_key"], [])) for g in grupos]
        total = max([1] + alturas)
        linhas = []
        ftds = base_cells.get("E")
        for i in range(total):
            celulas = dict(base_cells) if i == 0 else {"A": dia, "B": base_key}
            celulas["C"] = i + 1
            for g in grupos:
                rotulos = frames.get(g["rotulo_key"], [])
                numeros = frames.get(g["valor_key"], [])
                if i < len(rotulos):
                    celulas[g["rotulo_col"]] = rotulos[i]
                if i < len(numeros):
                    celulas[g["valor_col"]] = numeros[i]
                    if g["pct_col"] and isinstance(numeros[i], (int, float)) \
                            and isinstance(ftds, (int, float)) and ftds:
                        celulas[g["pct_col"]] = numeros[i] / ftds
            linhas.append(_linha(aba, celulas))

    # Vocabulario da vertical. Os headers sao os da planilha de referencia
    # ('GGR', 'Turnover', 'Unique Gamblers'); no e-commerce viram receita, GMV e
    # clientes. As chaves de `dados`/`formulas` NAO passam por aqui: elas casam com
    # o nome que o SQL devolve, que nao muda. `bet` = identidade.
    nome = vertical.traduz(aba["nome"])
    headers = [vertical.traduz(h) for h in aba["headers"]]
    percentuais = [vertical.traduz(c) for c in _colunas_percentuais(aba)]
    if vertical.VERTICAL != "bet":
        linhas = [[vertical.traduz(v) for v in linha] for linha in linhas]

    return {
        "name": nome,
        # Nome do arquivo segue a aba original: CSV baixado em duas verticais
        # diferentes não colide, e o rótulo da tela já diz qual é.
        "file": aba["nome"].lower().replace(" - ", "_").replace(" ", "_") + ".csv",
        "sources": [nome],
        "columns": headers,
        "percent_columns": percentuais,
        "rows": linhas,
    }


def load(base_key: str, params: dict, on_progress: Callable | None = None) -> dict:
    ini = _parse_date(params.get("date_start"), "date_start")
    fim = _parse_date(params.get("date_end"), "date_end")
    if fim < ini:
        raise ValueError(msg("erro_periodo"))

    valores_sql = {"start1": ini.strftime("%Y-%m-%d"), "end1": fim.strftime("%Y-%m-%d")}
    arquivos = _arquivos(base_key)

    def executar(item):
        relpath, rotulo = item
        sql, sql_params = to_parameterized(load_sql(relpath), valores_sql)
        return rotulo, run_query(base_key, sql, sql_params)

    valores: dict = {}          # metrica escalar -> valor
    frames: dict = {}           # coluna multi-linha -> lista de valores
    feito = 0

    with ThreadPoolExecutor(max_workers=_PARALELAS, thread_name_prefix="rm") as pool:
        futuros = {pool.submit(copy_context().run, executar, a): a for a in arquivos}
        for futuro in as_completed(futuros):
            rotulo, linhas = futuro.result()
            for linha in linhas:
                for coluna, valor in linha.items():
                    chave = str(coluna).lower()
                    if len(linhas) > 1 or chave in ("top 5 btags", "ftds top 5",
                                                    "online marketing", "ftds - online",
                                                    "investiment - online"):
                        frames.setdefault(chave, []).append(_num(valor))
                    else:
                        valores[chave] = _num(valor)
            feito += 1
            if on_progress:
                on_progress(int(feito / len(arquivos) * 100),
                            f"{rotulo} ({feito}/{len(arquivos)})")

    dia = fim.strftime("%Y-%m-%d")
    tabelas = [_tabela(aba, base_key, valores, frames, dia) for aba in _ABAS]

    return {
        "base": base_key,
        "kind": "tables",
        "periodo": f"{ini.strftime('%d/%m/%Y')} – {fim.strftime('%d/%m/%Y')}",
        "empty": not valores,
        "tables": tabelas,
    }
