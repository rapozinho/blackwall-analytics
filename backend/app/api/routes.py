# -*- coding: utf-8 -*-
"""Endpoints read-only. Toda leitura passa por whitelist (base/chart)."""
from fastapi import APIRouter, Depends, HTTPException, Query, Request

from ..auth import current_user
from ..config import BASES, BASE_KEYS
from ..registry import CHARTS, charts_for_base

router = APIRouter(prefix="/api", dependencies=[Depends(current_user)])


@router.get("/bases")
def list_bases():
    return BASES


@router.get("/charts")
def list_charts(base: str = Query(...)):
    if base not in BASE_KEYS:
        raise HTTPException(400, "Base inválida.")
    return charts_for_base(base)


@router.get("/charts/{chart_id}/data")
def chart_data(chart_id: str, request: Request, base: str = Query(...)):
    if base not in BASE_KEYS:
        raise HTTPException(400, "Base inválida.")
    chart = CHARTS.get(chart_id)
    if chart is None:
        raise HTTPException(404, "Gráfico não encontrado.")
    if base not in chart["bases"]:
        raise HTTPException(400, "Gráfico indisponível para esta base.")

    # params = query string exceto 'base'; 'metrics' aceita CSV.
    params = {k: v for k, v in request.query_params.items() if k != "base"}
    try:
        return chart["load"](base, params)
    except ValueError as e:  # validação de params
        raise HTTPException(400, str(e))
    except Exception as e:  # falha de DB/execução
        raise HTTPException(500, f"Erro ao consultar dados: {e}")
