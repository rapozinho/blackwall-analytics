# -*- coding: utf-8 -*-
"""Autenticacao (stub). Em producao: integrar SSO Microsoft Entra (OIDC) e
remover o bypass AUTH_DISABLED.

Camadas alem disto: VPN + reverse proxy interno + TLS. VPN sozinha NAO basta.
"""
from fastapi import Depends, HTTPException, status

from .i18n import msg
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from .config import settings

_bearer = HTTPBearer(auto_error=False)


async def current_user(cred: HTTPAuthorizationCredentials | None = Depends(_bearer)) -> dict:
    if settings.AUTH_DISABLED:
        return {"sub": "dev", "name": "dev"}
    if cred is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, msg("erro_nao_autenticado"))
    # TODO: validar token OIDC (Entra) — assinatura, aud, exp, grupos.
    raise HTTPException(status.HTTP_501_NOT_IMPLEMENTED, msg("erro_sso"))
