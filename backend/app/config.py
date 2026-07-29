# -*- coding: utf-8 -*-
"""Configuracao via variaveis de ambiente (.env). Nunca hardcode credenciais."""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    SERVER: str = ""
    DB_USER: str = ""
    DB_PASSWORD: str = ""
    ODBC_DRIVER: str = "ODBC Driver 17 for SQL Server"

    DATABASE_F12: str = ""
    DATABASE_LUVA: str = ""
    DATABASE_BRASILBET: str = ""
    DATABASE_GALERABET: str = ""

    CORS_ORIGINS: str = "http://localhost:5173"
    AUTH_DISABLED: bool = True

    def database_for(self, base_key: str) -> str:
        return {
            "F12": self.DATABASE_F12,
            "Luva": self.DATABASE_LUVA,
            "BrasilBet": self.DATABASE_BRASILBET,
            "GaleraBet": self.DATABASE_GALERABET,
        }[base_key]

    @property
    def cors_list(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]


settings = Settings()

# Whitelist de bases (label exibido -> key interna / DATABASE_<KEY>).
BASES = [
    {"key": "F12", "label": "F12"},
    {"key": "Luva", "label": "LuvaBet"},
    {"key": "BrasilBet", "label": "BrasilBet"},
    {"key": "GaleraBet", "label": "GaleraBet"},
]
BASE_KEYS = {b["key"] for b in BASES}
