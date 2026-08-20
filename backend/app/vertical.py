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

O idioma e uma segunda dimensao, ortogonal: a vertical decide QUAL conceito
("GGR" ou "Receita"), o idioma decide em que lingua ele sai ("Receita",
"Ingresos", "Revenue"). Os dois catalogos moram em `vocab/` e o idioma corrente
vem do `ContextVar` de `i18n.py`.

Por que traducao na saida e nao SQL separado: o catalogo e a parte densa do
projeto (15,5 mil linhas de T-SQL). Duplicar para trocar rotulo dobraria a
manutencao e faria as duas versoes divergirem no primeiro ajuste.

A chave interna da base NAO muda com a vertical (`Zephyr`, `Quasar`, `Lumen`,
`Kestrel`): ela nomeia a pasta do catalogo (`app/sql/Zephyr/...`) e o database.
Trocar exigiria mexer no SQL. O que o usuario ve e o `label`.
"""
import os

from . import i18n
from .vocab import GLOSSARIO, TERMOS

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

BASES = [{"key": k, "label": l} for k, l in _BASES[VERTICAL]]

# O rotulo da base NAO entra no i18n: `Nordika` e nome de operacao, nao palavra.


def _conferir_termos() -> None:
    """Os 6 blocos de `vocab/terms.py` precisam ter as mesmas chaves.

    Roda no import por escolha: chave faltando num idioma so apareceria quando
    alguem abrisse aquela tela naquela lingua, e ai como KeyError no meio da
    consulta."""
    base = set(TERMOS[VERTICAIS[0]][i18n.PADRAO])
    for vert in VERTICAIS:
        for lang in i18n.LANGS:
            try:
                chaves = set(TERMOS[vert][lang])
            except KeyError:
                raise ValueError(f"vocab/terms.py: falta [{vert}][{lang}].")
            faltando, sobrando = base - chaves, chaves - base
            if faltando or sobrando:
                raise ValueError(
                    f"vocab/terms.py [{vert}][{lang}]: faltando={sorted(faltando)} "
                    f"sobrando={sorted(sobrando)}"
                )


_conferir_termos()


def t(chave: str) -> str:
    """Termo da vertical corrente, no idioma corrente. Chave desconhecida e erro
    de programacao, nao de configuracao — melhor estourar do que exibir a chave
    crua na tela."""
    try:
        return TERMOS[VERTICAL][i18n.lang()][chave]
    except KeyError:
        raise KeyError(
            f"Termo {chave!r} nao existe em {VERTICAL!r}/{i18n.lang()!r}."
        )


# --- traducao do texto que vem do SQL --------------------------------------- #
# O catalogo devolve nome de coluna ('GGR', 'Turnover', 'Var % GGR') e valor de
# celula ('Internal Traffic', 'InfluenciadoresZephyr') em vocabulario de apostas
# e em ingles, e ele nao pode ser alterado. A substituicao acontece na saida; as
# listas de regras (por vertical x idioma, com a ordem que importa) estao em
# `vocab/glossary.py`.


def regras() -> list:
    """Substituicoes ativas: vertical corrente x idioma corrente."""
    return GLOSSARIO[VERTICAL][i18n.lang()]


def traduz(texto):
    """Traduz texto vindo do SQL (nome de coluna, valor de celula).

    Em `bet`/`pt` a lista de regras e vazia e a funcao devolve o proprio objeto —
    nao ha custo nem risco na combinacao padrao.

    Valor que nao e texto passa direto: numero e data ja vem formatados pelo
    loader e nao tem vocabulario para traduzir.
    """
    ativas = regras()
    if not ativas or not isinstance(texto, str):
        return texto
    for de, para in ativas:
        if de in texto:
            texto = texto.replace(de, para)
    return texto


def meta() -> dict:
    """Descricao da vertical para o frontend (`GET /api/meta`)."""
    return {
        "vertical": VERTICAL,
        # O frontend precisa saber em que idioma este payload veio: ele monta o
        # seletor de bandeiras a partir daqui, sem lista hardcoded.
        "lang": i18n.lang(),
        "langs": list(i18n.LANGS),
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
