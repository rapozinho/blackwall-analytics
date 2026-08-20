# -*- coding: utf-8 -*-
"""Perfil economico e vocabulario do dado gerado, por vertical.

O schema e o mesmo nas duas (`VERTICAL=bet|ecommerce`): mesma tabela, mesma
coluna, mesmo SQL. O que muda e a *ordem de grandeza* e o significado:

  | coluna             | bet                  | ecommerce                     |
  |--------------------|----------------------|-------------------------------|
  | Turnover           | volume apostado      | GMV do pedido                 |
  | GGR                | ganho da casa        | comissao 3P / margem bruta 1P |
  | NGR                | GGR - bonus          | receita - cupom               |
  | Bet_Count          | apostas na hora      | itens do pedido               |
  | casino_agg_hourly  | Casino               | Marketplace (3P)              |
  | sports_agg_hourly  | Sportsbook           | Loja propria (1P)             |
  | Provider_Name      | provedor de jogo     | seller / marca                |
  | ftd_agg            | primeiro deposito    | primeira compra               |
  | payments_agg       | deposito / saque     | pagamento / reembolso         |

A diferenca que mais aparece no dado nao e o valor, e a *frequencia*: apostador
ativo joga varias horas no mesmo dia (varias linhas), cliente de e-commerce faz
um pedido e volta semanas depois. Por isso `linhas_dia_*` e `dias_mes` sao bem
menores no e-commerce — o volume total cai, e e assim que deve ser.

Os valores de texto exigidos por filtro do catalogo (`affiliate_manager`,
`channel_type`, `'Others'`, `'Quasarbet'`) NAO estao aqui: eles vivem em
`bases.py` e sao iguais nas duas verticais, porque o `.sql` compara com eles.
Quando o termo carrega marca de apostas, quem troca e a exibicao
(`backend/app/vertical.py::traduz`), nao o dado.
"""
import os

VERTICAL = (os.getenv("VERTICAL") or "bet").strip().lower()
if VERTICAL not in ("bet", "ecommerce"):
    raise ValueError(f"VERTICAL invalida: {VERTICAL!r}. Use 'bet' ou 'ecommerce'.")

# Provedores de casino / sellers do marketplace — ficticios, 15 para o Overview
# mostrar top 12 + "Outros".
_PROVIDERS = {
    "bet": [
        "Auralis Gaming", "NimbusPlay", "Vortex Studios", "IronBell Slots", "Solaria Live",
        "PixelReef", "Zenith Live", "Kobold Games", "Marea Slots", "Tectonic Play",
        "NovaSpin", "Halcyon Studios", "Driftwood Games", "Emberly", "Cascade Live",
    ],
    "ecommerce": [
        "Nordeq", "CasaViva", "TecnoLar", "Vestra", "Bruma Home",
        "Ferragem Sul", "Kinetik", "Aurora Kids", "PetVale", "Ovelha Azul",
        "Mundo Trilha", "Cozinha Nove", "Lumina Beleza", "Fio & Trama", "Bravo Sports",
    ],
}

# Canais de aquisicao de forma livre (usados na base Zephyr/Nordika, a unica cujo
# catalogo nao filtra por canal).
_CANAIS_LIVRES = {
    "bet": ["Organic", "Paid Search", "Paid Social", "Influencers",
            "Affiliates", "Direct", "Marketing interno", "Tráfego externo"],
    "ecommerce": ["Organic", "Paid Search", "Paid Social", "Influencers",
                  "Affiliates", "Direct", "Email/CRM", "Comparadores"],
}

# --- perfil economico ------------------------------------------------------- #
# `_a` = tabela casino_agg_hourly (Casino / Marketplace 3P)
# `_b` = tabela sports_agg_hourly (Sportsbook / Loja propria 1P)
_PERFIS = {
    "bet": {
        # Atividade: apostador volta muito no mes e joga varias horas por dia.
        "dias_mes": ([1, 3, 6, 10, 16, 24], [16, 20, 22, 19, 15, 8]),
        "linhas_dia_a": ([1, 2, 3, 4, 6, 9], [18, 22, 20, 16, 15, 9]),
        "linhas_dia_b": ([1, 2, 3, 5], [42, 28, 20, 10]),
        "honeymoon": 1.9,
        "p_ativo": 0.90,
        "decay": 0.88,
        "p_participa_a": 0.86,          # joga casino
        "p_participa_b": 0.47,          # joga sports
        # Dispersao de porte entre jogadores: aposta tem cauda longa de verdade
        # (o "whale" gasta ordens de grandeza mais que a mediana).
        "escala_sigma": 0.95,

        # Valor: turnover por linha, e o "tamanho" de cada aposta.
        "valor_a": 120.0, "valor_sigma_a": 0.80,
        "unitario_a": 3.20, "unitario_sigma_a": 0.5,
        "valor_b": 95.0, "valor_sigma_b": 0.85,
        "unitario_b": 22.0, "unitario_sigma_b": 0.6,

        # Margem da casa: por jogador (media 4,2%) e por linha do sportsbook.
        "margem_a": (0.042, 0.030), "margem_a_ruido": 0.14,
        "margem_b": (0.068, 0.160),

        # Pagamentos.
        "p_pagamento": 0.55, "valor_pagamento": 55.0,
        "p_reembolso": 0.22, "valor_reembolso": 90.0,
        "valor_ftd": 42.0,
    },
    "ecommerce": {
        # Cliente compra e volta depois: ~1,7 dia com pedido por mes ativo, quase
        # sempre 1 pedido no dia. O mesmo dia pode gerar um pedido no marketplace e
        # outro na loja propria, entao a media efetiva fica em ~2,5 pedidos/mes.
        #
        # Este numero foi calibrado olhando o KPI, nao chutado: com a frequencia de
        # apostas o GMV por cliente ativo dava R$ 3,9 mil/mes; varejo de massa fica
        # na casa de R$ 500-900.
        "dias_mes": ([1, 2, 3, 5, 8], [60, 25, 9, 4, 2]),
        "linhas_dia_a": ([1, 2], [90, 10]),
        "linhas_dia_b": ([1, 2], [94, 6]),
        # Primeira compra puxa recompra rapida (pos-venda, cupom de boas-vindas),
        # mas nada perto do engajamento de aposta.
        "honeymoon": 1.5,
        "p_ativo": 0.86,
        "decay": 0.90,
        "p_participa_a": 0.88,          # compra no marketplace
        "p_participa_b": 0.42,          # compra na loja propria
        # Varejo e MUITO menos disperso que aposta: nao existe cliente que gasta
        # 100x a mediana todo mes. Com o sigma de apostas, o GMV por cliente ativo
        # saia em ~R$ 3,9 mil/mes, o que nao acontece em loja de massa.
        "escala_sigma": 0.50,

        # Ticket do pedido e preco medio do item.
        "valor_a": 150.0, "valor_sigma_a": 0.55,
        "unitario_a": 58.0, "unitario_sigma_a": 0.55,
        "valor_b": 195.0, "valor_sigma_b": 0.55,
        "unitario_b": 82.0, "unitario_sigma_b": 0.50,

        # Receita sobre GMV: comissao do 3P ~16%, margem bruta do 1P ~30%.
        "margem_a": (0.160, 0.040), "margem_a_ruido": 0.05,
        "margem_b": (0.300, 0.080),

        # Pagamento aprovado por pedido; reembolso/devolucao ~7% dos dias com
        # pedido (taxa de devolucao real de varejo online fica na casa de 5%-10%).
        "p_pagamento": 0.92, "valor_pagamento": 175.0,
        "p_reembolso": 0.07, "valor_reembolso": 190.0,
        "valor_ftd": 120.0,
    },
}

PERFIL = _PERFIS[VERTICAL]
PROVIDERS = _PROVIDERS[VERTICAL]
CANAIS_LIVRES = _CANAIS_LIVRES[VERTICAL]
