# -*- coding: utf-8 -*-
"""Configuracao via variaveis de ambiente (.env). Nunca hardcode credenciais."""
from pydantic_settings import BaseSettings, SettingsConfigDict

from . import vertical


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    SERVER: str = ""
    DB_USER: str = ""
    DB_PASSWORD: str = ""
    ODBC_DRIVER: str = "ODBC Driver 17 for SQL Server"

    # TLS na conexao com o banco. Vazio = nao entra na string de conexao, e o
    # driver decide (o 17 nao criptografa por padrao; o 18 criptografa).
    # Em producao: DB_ENCRYPT=yes. TRUST_SERVER_CERTIFICATE=yes so quando o
    # certificado for autoassinado — ele desliga a validacao, nao a criptografia.
    DB_ENCRYPT: str = ""
    DB_TRUST_SERVER_CERTIFICATE: str = ""

    DATABASE_ZEPHYR: str = ""
    DATABASE_QUASAR: str = ""
    DATABASE_LUMEN: str = ""
    DATABASE_KESTREL: str = ""

    CORS_ORIGINS: str = "http://localhost:5173"
    AUTH_DISABLED: bool = True

    def database_for(self, base_key: str) -> str:
        return {
            "Zephyr": self.DATABASE_ZEPHYR,
            "Quasar": self.DATABASE_QUASAR,
            "Lumen": self.DATABASE_LUMEN,
            "Kestrel": self.DATABASE_KESTREL,
        }[base_key]

    @property
    def cors_list(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]


settings = Settings()

# Whitelist de bases. A `key` e interna e fixa (nomeia a pasta do catalogo em
# `app/sql/<key>/` e o `DATABASE_<KEY>`); o `label` e o nome exibido, e muda com a
# vertical (`VERTICAL=bet|ecommerce`, ver `vertical.py`).
BASES = vertical.BASES
BASE_KEYS = {b["key"] for b in BASES}
