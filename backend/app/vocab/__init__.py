# -*- coding: utf-8 -*-
"""Catalogos de texto. Dados, nao logica — quem os usa e `i18n.py` e
`vertical.py`.

    terms.py     vocabulario de negocio por vertical e idioma (KPI, donut, aba)
    glossary.py  substituicao no texto que vem do SQL, por vertical e idioma
    messages.py  texto de produto por idioma (filtro, progresso, erro, insight)
"""
from .glossary import GLOSSARIO
from .messages import MENSAGENS
from .terms import TERMOS

__all__ = ["GLOSSARIO", "MENSAGENS", "TERMOS"]
