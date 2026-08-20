# Semeador das bases de demonstracao.
#
# Sobe uma vez (servico `dbinit` do compose), cria as bases, o login read-only e
# carrega os dados ficticios; depois sai. O backend so comeca depois que este
# container termina com codigo 0.
#
# Mesma base do container da API: precisa do driver ODBC da Microsoft, que nao
# vem no python:slim.
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl gnupg ca-certificates \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
    && echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" \
        > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
        msodbcsql18 unixodbc libgssapi-krb5-2 \
    && apt-get purge -y curl gnupg \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir "pyodbc==5.1.0"

WORKDIR /db
COPY *.py *.sql ./

# O catalogo entra por bind mount (compose) para o verify_catalog.py alcancar os
# 292 `.sql` sem copiar a arvore do backend para esta imagem.
CMD ["python", "init.py"]
