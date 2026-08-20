# -*- coding: utf-8 -*-
"""Idioma da requisicao: `pt` (padrao), `es` ou `en`.

    GET /api/charts/overview/data?base=Zephyr&lang=en

O idioma vive num `ContextVar` e nao num parametro carregado de funcao em
funcao: quem precisa dele e a *saida* — rotulo de KPI, aba de report, frase de
insight, mensagem de erro —, e isso esta espalhado por todo o caminho da
consulta. Passar `lang` a mao significaria mudar a assinatura de cada loader e
de cada helper de formatacao.

Consequencia pratica: quem sai da thread da requisicao precisa levar o contexto.
`charts/overview.py` e `reports/report_master.py` ja usavam `copy_context()` para
o job id (ver `cancel.py`) e por isso o idioma vai de carona; `jobs.py` copia o
contexto ao enfileirar, pelo mesmo motivo.

O texto propriamente dito esta em dois lugares, por origem:

  * `vocab/messages.py` — texto de produto (filtro, progresso, erro, insight);
  * `vocab/terms.py` + `vocab/glossary.py` — vocabulario de negocio, que muda
    com a vertical antes de mudar com o idioma. Ver `vertical.py`.
"""
import re
from contextvars import ContextVar

from .vocab.messages import MENSAGENS

LANGS = ("pt", "es", "en")
PADRAO = "pt"

# --- conferencia dos catalogos, no import ----------------------------------- #
# Chave faltando ou placeholder trocado na traducao viraria erro no meio de uma
# consulta de 3 minutos. Aqui custa um for e falha no start do processo.
_CAMPOS = re.compile(r"{(\w+)}")


def _campos(texto: str) -> set[str]:
    return set(_CAMPOS.findall(texto))


def _conferir_mensagens() -> None:
    base = set(MENSAGENS[PADRAO])
    for lang in LANGS:
        if lang not in MENSAGENS:
            raise ValueError(f"vocab/messages.py: falta o idioma {lang!r}.")
        faltando = base - set(MENSAGENS[lang])
        sobrando = set(MENSAGENS[lang]) - base
        if faltando or sobrando:
            raise ValueError(
                f"vocab/messages.py [{lang}]: faltando={sorted(faltando)} "
                f"sobrando={sorted(sobrando)}"
            )
    for chave in base:
        esperado = _campos(MENSAGENS[PADRAO][chave])
        for lang in LANGS:
            achado = _campos(MENSAGENS[lang][chave])
            if achado != esperado:
                raise ValueError(
                    f"vocab/messages.py [{lang}][{chave}]: placeholders {sorted(achado)} "
                    f"!= {sorted(esperado)} do {PADRAO}."
                )


_conferir_mensagens()

# --- idioma corrente -------------------------------------------------------- #
_lang: ContextVar[str] = ContextVar("lang", default=PADRAO)


def normaliza(codigo: str | None) -> str:
    """`pt-BR` -> `pt`; desconhecido -> padrao.

    Idioma vem da query string, ou seja, de fora: valor invalido nao e erro de
    requisicao — a tela em portugues e uma resposta melhor do que um 400.
    """
    if not codigo:
        return PADRAO
    curto = codigo.strip().lower().replace("_", "-").split("-")[0]
    return curto if curto in LANGS else PADRAO


def set_lang(codigo: str | None) -> str:
    """Fixa o idioma desta requisicao e devolve o codigo normalizado."""
    lang = normaliza(codigo)
    _lang.set(lang)
    return lang


def lang() -> str:
    return _lang.get()


def msg(chave: str, **fmt) -> str:
    """Mensagem no idioma corrente. Chave inexistente e erro de programacao."""
    try:
        texto = MENSAGENS[lang()][chave]
    except KeyError:
        raise KeyError(f"Mensagem {chave!r} nao existe em {lang()!r}.")
    return texto.format(**fmt) if fmt else texto


def meses() -> list[str]:
    """Abreviacao de mes para o rotulo de cohort ('Jul-26')."""
    return msg("meses").split(",")


def decimal_ponto() -> bool:
    """`True` onde o separador decimal e ponto (en). O dado e em real, e o
    simbolo continua R$ nos tres idiomas — quem muda e a pontuacao."""
    return lang() == "en"
