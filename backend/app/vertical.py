# -*- coding: utf-8 -*-
"""Vertical de negocio: `bet` (padrao) ou `ecommerce`.

    VERTICAL=ecommerce docker compose up -d      # ou: .\\run.ps1 ecommerce

O mesmo portal serve as duas: a modelagem do warehouse (jogador/pedido, aposta/
item, GGR/receita) tem a mesma forma, e o que muda e o vocabulario. Entao NADA de
duplicar codigo ou SQL — os 292 arquivos do catalogo continuam intocados, e o que
troca e:

  1. o rotulo das 4 bases (`BASES`);
  2. o texto de cada metrica, report e eixo (`TERMO`);
  3. o texto que vem *de dentro do SQL* — nome de coluna e valor de celula —
     traduzido por `traduz()` na saida (o SQL devolve 'GGR', a tela mostra
     'Receita');
  4. o dado gerado (`db/verticals.py`), com ordem de grandeza de e-commerce.

Por que traducao na saida e nao SQL separado: o catalogo e a parte densa do
projeto (15,5 mil linhas de T-SQL). Duplicar para trocar rotulo dobraria a
manutencao e faria as duas versoes divergirem no primeiro ajuste.

A chave interna da base NAO muda com a vertical (`Zephyr`, `Quasar`, `Lumen`,
`Kestrel`): ela nomeia a pasta do catalogo (`app/sql/Zephyr/...`) e o database.
Trocar exigiria mexer no SQL. O que o usuario ve e o `label`.
"""
import os

VERTICAIS = ("bet", "ecommerce")

VERTICAL = (os.getenv("VERTICAL") or "bet").strip().lower()
if VERTICAL not in VERTICAIS:
    raise ValueError(f"VERTICAL invalida: {VERTICAL!r}. Use uma de: {', '.join(VERTICAIS)}.")

# --- rotulo das bases ------------------------------------------------------- #
_BASES = {
    "bet": [
        ("Zephyr", "ZephyrBet"),
        ("Quasar", "QuasarBet"),
        ("Lumen", "LumenBet"),
        ("Kestrel", "KestrelBet"),
    ],
    "ecommerce": [
        ("Zephyr", "Nordika"),      # marketplace generalista
        ("Quasar", "Vellora"),      # moda
        ("Lumen", "Cintra"),        # casa & decoracao
        ("Kestrel", "Kaya"),        # esporte & outdoor
    ],
}

# --- vocabulario ------------------------------------------------------------ #
# `hint` aparece no tooltip do KPI; `label` no rotulo.
_TERMOS = {
    "bet": {
        "vertical_nome": "Apostas",
        "unidade_cliente": "jogador",
        "unidade_cliente_plural": "jogadores",
        "vertical_a": "Casino",
        "vertical_b": "Sportsbook",
        "vertical_par": "casino + sportsbook",

        "ggr": "GGR",
        "ggr_hint": "Casino + Sportsbook no período.",
        "ngr": "NGR",
        "ngr_hint": "GGR menos bônus e custos, como gravado na base.",
        "turnover": "Turnover",
        "turnover_hint": "Volume apostado.",
        "margem": "Margem",
        "margem_hint": "GGR / Turnover.",
        "hold": "Hold",
        "hold_hint": "NGR / GGR.",
        "depositos": "Depósitos",
        "depositos_hint": "Somente pagamentos com Status = Completed.",
        "saques": "Saques",
        "saques_hint": "Somente pagamentos com Status = Completed.",
        "netcash": "Netcash",
        "netcash_hint": "Depósitos menos saques.",
        "ftds": "FTDs",
        "ftds_hint": "Jogadores com primeiro depósito no período.",
        "registros": "Registros",
        "registros_hint": "Cadastros criados no período.",
        "uap": "Jogadores ativos",
        "uap_hint": "Únicos com aposta em casino ou sports.",
        "arpu": "ARPU",
        "arpu_hint": "GGR por jogador ativo.",
        "itens": "Apostas",

        "donut_vertical": "Receita por vertical",
        "donut_vertical_desc": "GGR de casino contra sportsbook no período.",
        "donut_provedor": "Receita por provedor",
        "donut_provedor_desc": "Top 12 provedores de casino por GGR; o restante soma em “Outros”.",
        "donut_canal": "Aquisição por canal",
        "donut_canal_desc": "Canal de cadastro do jogador; as métricas são do período selecionado.",

        "nota_ngr_zero": ("O NGR do sportsbook vem zerado nesta base — “NGR” e “Hold” "
                          "refletem apenas o casino."),

        "overview_desc": ("GGR, NGR, depósitos e aquisição do período, com comparação "
                          "contra a janela anterior de mesma duração."),
        "retention_desc": "Retenção de cohorts por GGR, Turnover, Deposits e Netcash.",
        "report_master_desc": ("Réplica da planilha do bot: 5 abas (Operational Overview, "
                              "Casino, Sports, CRM e Acquisition) com as métricas do "
                              "período. 76 consultas — leva vários minutos."),
        "monitoring_desc": "Performance por gerente de afiliados, comparando dois períodos.",
        "bpa_desc": "Aquisição: FTDs, depósitos e GGR por canal, dois períodos.",
        "bpd_desc": "Distribuição de FTDs e receita por canal de aquisição.",
        "bpa_merge_nome": "Aquisição por canal",

        "cohort_eixo_total": "{m} (k)",
        "cohort_eixo_medio": "{m} médio por jogador ativo (R$)",
        "cohort_eixo_acum": "{m} médio acumulado por jogador (R$)",
        "cohort_variant_avg": "Média por jogador",
        "cohort_variant_avg_hint": "Soma da safra dividida pelos jogadores ativos daquele mês.",
        "cohort_metric_deposits": "Deposits",
        "cohort_metric_netcash": "Netcash",
    },
    "ecommerce": {
        "vertical_nome": "E-commerce",
        "unidade_cliente": "cliente",
        "unidade_cliente_plural": "clientes",
        "vertical_a": "Marketplace (3P)",
        "vertical_b": "Loja própria (1P)",
        "vertical_par": "marketplace + loja própria",

        "ggr": "Receita",
        "ggr_hint": "Comissão do marketplace (3P) + margem bruta da loja própria (1P).",
        "ngr": "Margem de contribuição",
        "ngr_hint": "Receita menos cupons e descontos concedidos.",
        "turnover": "GMV",
        "turnover_hint": "Valor total transacionado nos pedidos.",
        "margem": "Take rate",
        "margem_hint": "Receita / GMV.",
        "hold": "Margem líquida",
        "hold_hint": "Margem de contribuição / Receita.",
        "depositos": "Pagamentos aprovados",
        "depositos_hint": "Somente transações com Status = Completed.",
        "saques": "Reembolsos",
        "saques_hint": "Somente transações com Status = Completed.",
        "netcash": "Receita líquida",
        "netcash_hint": "Pagamentos aprovados menos reembolsos.",
        "ftds": "Novos clientes",
        "ftds_hint": "Clientes com a primeira compra no período.",
        "registros": "Cadastros",
        "registros_hint": "Contas criadas no período.",
        "uap": "Clientes ativos",
        "uap_hint": "Únicos com pedido no marketplace ou na loja própria.",
        "arpu": "Receita por cliente",
        "arpu_hint": "Receita dividida pelos clientes ativos.",
        "itens": "Itens",

        "donut_vertical": "Receita por operação",
        "donut_vertical_desc": "Marketplace (3P) contra loja própria (1P) no período.",
        "donut_provedor": "Receita por seller",
        "donut_provedor_desc": "Top 12 sellers por receita; o restante soma em “Outros”.",
        "donut_canal": "Aquisição por canal",
        "donut_canal_desc": "Canal de cadastro do cliente; as métricas são do período selecionado.",

        "nota_ngr_zero": ("A margem da loja própria vem zerada nesta base — “Margem de "
                          "contribuição” e “Margem líquida” refletem apenas o marketplace."),

        "overview_desc": ("Receita, margem, pagamentos e aquisição do período, com "
                          "comparação contra a janela anterior de mesma duração."),
        "retention_desc": "Retenção de cohorts por Receita, GMV, Pagamentos e Receita líquida.",
        "report_master_desc": ("Planilha executiva: 5 abas (Operational Overview, "
                              "Marketplace, Loja própria, CRM e Aquisição) com as "
                              "métricas do período. 76 consultas."),
        "monitoring_desc": "Performance por gerente de parcerias, comparando dois períodos.",
        "bpa_desc": "Aquisição: novos clientes, pagamentos e receita por canal, dois períodos.",
        "bpd_desc": "Distribuição de novos clientes e receita por canal de aquisição.",
        "bpa_merge_nome": "Aquisição por canal",

        "cohort_eixo_total": "{m} (k)",
        "cohort_eixo_medio": "{m} médio por cliente ativo (R$)",
        "cohort_eixo_acum": "{m} médio acumulado por cliente (R$)",
        "cohort_variant_avg": "Média por cliente",
        "cohort_variant_avg_hint": "Soma da safra dividida pelos clientes ativos daquele mês.",
        "cohort_metric_deposits": "Pagamentos",
        "cohort_metric_netcash": "Receita líquida",
    },
}

BASES = [{"key": k, "label": l} for k, l in _BASES[VERTICAL]]
_TERMO = _TERMOS[VERTICAL]


def t(chave: str) -> str:
    """Termo da vertical corrente. Chave desconhecida e erro de programacao, nao
    de configuracao — melhor estourar do que exibir a chave crua na tela."""
    try:
        return _TERMO[chave]
    except KeyError:
        raise KeyError(f"Termo {chave!r} nao existe na vertical {VERTICAL!r}.")


# --- traducao do texto que vem do SQL --------------------------------------- #
# O catalogo devolve nome de coluna ('GGR', 'Turnover', 'Var % GGR') e valor de
# celula ('Internal Traffic', 'InfluenciadoresZephyr') em vocabulario de apostas,
# e ele nao pode ser alterado. Aqui a substituicao acontece na saida.
#
# A ORDEM importa: o mais especifico primeiro, senao 'GGR' come o 'Hold (NGR/GGR)'
# e 'FTD' come o 'FTD_Percent'.
_GLOSSARIO = {
    "bet": [],
    "ecommerce": [
        # compostos primeiro
        ("Hold (NGR/GGR)", "Margem líquida"),
        # nome de aba da planilha
        ("Operational Overview", "Visão operacional"),
        ("Acquisition - All", "Aquisição - Todos"),
        ("Acquisition", "Aquisição"),
        # "Global GGR" antes de "GGR", senao sai "Global Receita"
        ("Global GGR", "Receita global"),
        ("Global Turnover", "GMV global"),
        # `Margin` (GGR/turnover) e `NGR` sao coisas diferentes e as duas cairiam
        # em "Margem": o take rate fica com o nome de mercado e o NGR vira margem
        # de contribuicao.
        ("Margin", "Take rate"),
        ("Total_Dep", "Total_Pgto"),
        ("Avg_Dep", "Avg_Pgto"),
        ("Var % Dep", "Var % Pgto"),
        ("Cost", "Custo"),
        ("NARPU/Unique", "Margem/cliente"),
        ("ARPU/Unique", "Receita/cliente"),
        ("TOAU/Unique", "GMV/cliente"),
        ("NGR/DEP", "Margem/pagamento"),
        ("Unique Gamblers MTD", "Clientes únicos MTD"),
        ("Unique Gamblers", "Clientes únicos"),
        ("Unique MTD", "Únicos MTD"),
        ("Gamblers Casino", "Clientes Marketplace"),
        ("Gamblers Sports", "Clientes Loja própria"),
        ("Gamblers (Daily AVG)", "Clientes (média diária)"),
        ("Gamblers", "Clientes"),
        ("Active Players", "Clientes ativos"),
        ("Retention Rate", "Retenção"),
        ("Reactivations Rate", "Taxa de reativação"),
        ("Reactivations", "Reativações"),
        ("Reativations", "Reativações"),
        ("AVG Bet", "Ticket médio"),
        ("Avg bet", "Ticket médio"),
        ("Generosity", "Descontos"),
        ("Online Marketing", "Mídia online"),
        ("Internal Traffic", "Tráfego interno"),
        ("External Traffic", "Tráfego externo"),
        ("Grand Total", "Total geral"),
        ("Top 5 Btags", "Top 5 campanhas"),
        ("FTDs Top 5", "1ª compra Top 5"),
        # nomes de gerente que carregavam a marca de apostas (valor de celula)
        ("InfluenciadoresZephyr", "InfluenciadoresNordika"),
        ("InfluenciadoresQuasar", "InfluenciadoresVellora"),
        ("InfluenciadoresLumen", "InfluenciadoresCintra"),
        # colunas com sufixo tecnico: manter o sufixo, trocar so o radical
        ("FTD_Percent", "Novos_Percent"),
        ("FTD_QTD", "Novos_QTD"),
        ("FTD_Date", "Data_1a_Compra"),
        ("Affiliate_Manager", "Gerente_Parceria"),
        ("Affiliate_Name", "Parceiro"),
        ("Affiliate_Id", "Parceiro_Id"),
        # radicais
        ("FTDs", "Novos clientes"),
        ("FTD", "1ª compra"),
        ("Turnover", "GMV"),
        ("Netcash", "Receita líquida"),
        ("Deposits", "Pagamentos"),
        ("Withdrawals", "Reembolsos"),
        ("withdrawals", "Reembolsos"),
        ("Registrations", "Cadastros"),
        ("Registration", "Cadastros"),
        ("Registros", "Cadastros"),
        ("Investiment", "Investimento"),
        ("CPA", "CAC"),
        ("Btags", "Campanhas"),
        ("btag", "campanha"),
        ("Bonus", "Cupons"),
        ("NGR", "Margem contrib."),
        ("GGR", "Receita"),
        ("Sportsbook", "Loja própria"),
        ("Sports", "Loja própria"),
        ("Casino", "Marketplace"),
        ("Affiliates", "Parceiros"),
        ("Afiliados", "Parceiros"),
        ("Affiliate", "Parceiro"),
        ("Influencers", "Influenciadores"),
        ("Organic", "Orgânico"),
        ("Others", "Outros"),
    ],
}

_REGRAS = _GLOSSARIO[VERTICAL]


def traduz(texto):
    """Traduz texto vindo do SQL (nome de coluna, valor de celula).

    Fora de `ecommerce` a lista de regras e vazia e a funcao devolve o proprio
    objeto — nao ha custo nem risco na vertical padrao.

    Valor que nao e texto passa direto: numero e data ja vem formatados pelo
    loader e nao tem vocabulario para traduzir.
    """
    if not _REGRAS or not isinstance(texto, str):
        return texto
    for de, para in _REGRAS:
        if de in texto:
            texto = texto.replace(de, para)
    return texto


def meta() -> dict:
    """Descricao da vertical para o frontend (`GET /api/meta`)."""
    return {
        "vertical": VERTICAL,
        "label": t("vertical_nome"),
        "unidade_cliente": t("unidade_cliente"),
        "unidade_cliente_plural": t("unidade_cliente_plural"),
        "verticais": {"casino": t("vertical_a"), "sports": t("vertical_b")},
        "verticais_par": t("vertical_par"),
        "series": {
            "ggr": t("ggr"), "ngr": t("ngr"), "turnover": t("turnover"),
            "depositos": t("depositos"), "netcash": t("netcash"), "ftds": t("ftds"),
        },
    }
