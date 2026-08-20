# -*- coding: utf-8 -*-
"""Configuracao das 4 bases de demonstracao.

Os valores de texto NAO sao decorativos: o catalogo em `backend/app/sql/` filtra
por eles (`affiliate_manager IN (...)`, `channel_type = 'Afiliados'`,
`acquisition_channel = 'Others'`). Mudar um nome aqui sem mudar no `.sql` faz o
report voltar vazio — e por isso cada dominio abaixo tem o arquivo que o exige.

Cada base tambem carrega as *idiossincrasias* que o codigo do backend trata:
  - Zephyr  : sportsbook grava NGR = 0; boa parte de payments vem sem Status.
  - Quasar  : affiliate_manager tem o id no proprio nome ('GoogleAds (444)').
  - Lumen   : nao tem a coluna `turnover_bonus`; canal organico e 'Others'.
  - Kestrel : mesma modelagem da Lumen, canal organico e 'Organic'; le a tabela
              de gerentes da Lumen por nome de 3 partes (cross-database).
"""
import os
from datetime import date

from verticals import CANAIS_LIVRES, PROVIDERS, VERTICAL  # noqa: F401 (re-export)

# Janela dos dados: 18 meses fechados + o mes corrente ate DATA_FIM.
DATA_FIM = date(2026, 8, 7)
MESES = 18

# Versao do dado gerado. Mudou o schema ou a geracao? Suba a versao: o
# `init.py` recria as tabelas da base e recarrega, sem precisar de `down -v`.
SEED_VERSION = "1.6.0"

# Multiplicador de volume. `SEED_ESCALA=3` triplica os jogadores (e o tempo de
# carga) sem mexer em codigo; a semente do RNG nao muda, entao a base menor
# continua sendo um prefixo da maior.
ESCALA = float(os.getenv("SEED_ESCALA", "1"))

# PROVIDERS (provedor de casino / seller do marketplace) e CANAIS_LIVRES vem de
# `verticals.py`, porque mudam com a vertical. Os dominios abaixo NAO mudam: o
# catalogo compara com eles literalmente.

# --- dominios por base ------------------------------------------------------ #
# Zephyr: affiliates_agg.Affiliate_Manager sem sufixo de id.
# Exigido por: Zephyr/bpa/zephyr_bpa_query_{2,3,4,5}.sql, bpd/*.sql
ZEPHYR_MANAGERS = [
    ("GoogleAds", 444), ("GoogleAdsNOVO", 501), ("MetaAds", 447), ("MetaAdsNOVO", 502),
    ("TráfegoGeral", 460), ("parceiroadmin", 445), ("InfluenciadoresZephyr", 446),
    ("AfiliadosAtivosCpa", 434), ("AfiliadosAtivosHib", 435), ("AfiliadosAtivosRev", 436),
    ("Afiliadosinativos", 443), ("PeaklineMedia", 437), ("VertexGroup", 439),
    ("DistratoRev", 529),
]

# Quasar: o id entra no proprio texto do manager.
# Exigido por: Quasar/bpa/quasar_bpa_query_{2,3,4,5}.sql, bpd/*.sql
QUASAR_MANAGERS = [
    ("GoogleAds (444)", 444), ("GoogleAdsNOVO (501)", 501), ("MetaAds (447)", 447),
    ("MetaAdsNOVO (502)", 502), ("ScoreWire (448)", 448), ("TaboolaAds (481)", 481),
    ("TikTokAds (449)", 449), ("parceiroadmin (445)", 445),
    ("InfluenciadoresQuasar (446)", 446), ("AfiliadosAtivosCpa (434)", 434),
    ("AfiliadosAtivosHib (435)", 435), ("AfiliadosAtivosRev (436)", 436),
    ("Afiliadosinativos (443)", 443), ("PeaklineMedia (437)", 437),
    ("VertexGroup (439)", 439), ("DistratoRev (529)", 529),
]

# Lumen/Kestrel: o gerente vem da tabela `affiliate_manager_lumen`, casada por
# `acquisitions_agg.affiliate_name = username`. As 4 categorias de channel_type
# alimentam bpa_query_{2,3,4,5} e bpd_query_{1,2,3} das duas bases.
# (username, affiliate_manager, channel_type)
LUMEN_MANAGER_TABLE = [
    ("GoogleAds",       "GoogleAds",            "Marketing interno"),
    ("MetaAds",         "MetaAds",              "Marketing interno"),
    ("TaboolaAds",      "TaboolaAds",           "Marketing interno"),
    ("ScoreWireAds",    "ScoreWireAds",         "Marketing interno"),
    ("CriteoAds BR",    "CriteoAds",            "Marketing interno"),
    ("Peakline Media",  "AfiliadosAtivosRev",   "Afiliados"),
    ("Vertex",          "AfiliadosAtivosCpa",   "Afiliados"),
    ("Somma Ads",       "AfiliadosAtivosHib",   "Afiliados"),
    ("Basalt",          "AfiliadosAtivosRev",   "Afiliados"),
    ("ParceiroAlfaAff", "InfluenciadoresLumen", "Influenciadores"),
    ("Polaris",         "InfluenciadoresLumen", "Influenciadores"),
    ("LiveOdds",        "TráfegoExterno",       "Tráfego externo"),
    ("Ravena",          "TráfegoExterno",       "Tráfego externo"),
    ("Ascend",          "TráfegoExterno",       "Tráfego externo"),
    ("ZP0902CAMP26",    "TráfegoExterno",       "Tráfego externo"),
]

# Canais de aquisicao que aparecem no filtro de bpa_query_5 da Lumen — sao os
# parceiros, nao as plataformas de midia.
LUMEN_PARTNER_CHANNELS = [u for u, _, ct in LUMEN_MANAGER_TABLE if ct != "Marketing interno"]

BASES = {
    "Zephyr": {
        "database": "dw_zephyr",
        "jogadores": 6000,
        "rng_seed": 1001,
        "managers": ZEPHYR_MANAGERS,
        "manager_suffix": False,
        # Canal de cadastro: livre (nenhuma query da Zephyr filtra por ele), entao
        # o rotulo pode acompanhar a vertical.
        "canais": CANAIS_LIVRES,
        "canal_organico": "Organic",
        "tem_turnover_bonus": True,
        # Idiossincrasia real da base: o sportsbook grava NGR zerado. O Overview
        # detecta e avisa na tela (`charts/overview.py::_notas`).
        "sports_ngr_zero": True,
        # ... e a maioria das linhas de payments vem sem Status, o que obriga o
        # filtro `Status = 'Completed'` em todo o catalogo.
        "pct_status_nulo": 0.55,
        "manager_table": None,
    },
    "Quasar": {
        "database": "dw_quasar",
        "jogadores": 4400,
        "rng_seed": 1002,
        "managers": QUASAR_MANAGERS,
        "manager_suffix": True,
        # 'organic', 'Default' e 'Quasarbet' sao exigidos por quasar_bpa_query_6
        # e pelos tres bpd.
        "canais": ["organic", "Default", "Quasarbet", "Influencers", "Affiliates",
                   "Paid Social", "Paid Search"],
        "canal_organico": "organic",
        "tem_turnover_bonus": True,
        "sports_ngr_zero": False,
        "pct_status_nulo": 0.08,
        "manager_table": None,
    },
    "Lumen": {
        "database": "dw_lumen",
        "jogadores": 5200,
        "rng_seed": 1003,
        # affiliates_agg da Lumen guarda a plataforma de midia; o gerente de
        # afiliado real vem da tabela `affiliate_manager_lumen`.
        "managers": [("GoogleAds", 444), ("MetaAds", 447), ("TaboolaAds", 481),
                     ("ScoreWireAds", 448), ("CriteoAds", 450)],
        "manager_suffix": False,
        "canais": None,          # derivado de LUMEN_MANAGER_TABLE
        "canal_organico": "Others",
        # A base nao tem a coluna: o `.sql` de bonus da Lumen esta inteiro
        # comentado por causa disso (ver README).
        "tem_turnover_bonus": False,
        "sports_ngr_zero": False,
        "pct_status_nulo": 0.05,
        "manager_table": LUMEN_MANAGER_TABLE,
    },
    "Kestrel": {
        "database": "dw_kestrel",
        "jogadores": 3000,
        "rng_seed": 1004,
        "managers": [("GoogleAds", 444), ("MetaAds", 447), ("TaboolaAds", 481),
                     ("ScoreWireAds", 448), ("CriteoAds", 450)],
        "manager_suffix": False,
        "canais": None,
        # Diferenca de modelagem em relacao a Lumen: aqui o organico e 'Organic'
        # (kestrel_bpd_query_{1,2,3}).
        "canal_organico": "Organic",
        "tem_turnover_bonus": True,
        "sports_ngr_zero": False,
        "pct_status_nulo": 0.05,
        # Le a tabela da Lumen por nome de 3 partes; nao tem tabela propria.
        "manager_table": None,
    },
}

# Ordem de carga: Lumen primeiro, porque Kestrel depende da tabela de gerentes
# dela (`dw_lumen.dbo.affiliate_manager_lumen`).
ORDEM = ["Lumen", "Zephyr", "Quasar", "Kestrel"]

TABELAS = ["acquisitions_agg", "affiliates_agg", "ftd_agg",
           "casino_agg_hourly", "sports_agg_hourly", "payments_agg_hourly"]
