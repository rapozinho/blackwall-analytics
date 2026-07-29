# -*- coding: utf-8 -*-
"""BlackWall Analytics — API (FastAPI). Read-only, atrás de VPN + proxy interno."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .api.routes import router

app = FastAPI(title="BlackWall Analytics", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_list,   # restrito à origem interna do frontend
    allow_methods=["GET"],
    allow_headers=["*"],
)

app.include_router(router)


@app.get("/health")
def health():
    return {"status": "ok"}
