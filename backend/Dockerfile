# BlackWall Analytics — API (FastAPI + pyodbc)
#
# O que costuma dar errado ao subir isto e por que o Dockerfile e assim:
#   - pyodbc precisa do driver ODBC da Microsoft; ele NAO vem no python:slim.
#   - o driver 18 criptografa por padrao. Se o SQL Server interno usa certificado
#     autoassinado, defina DB_TRUST_SERVER_CERTIFICATE=yes (ver .env.example).
#   - a imagem nao carrega .env: as credenciais entram por variavel de ambiente
#     ou secret do orquestrador.
FROM python:3.11-slim AS base

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

# Driver ODBC 18 + 17: o 17 fica disponivel para ambientes que ainda dependem do
# comportamento antigo de TLS (basta trocar ODBC_DRIVER).
# ACCEPT_EULA e exigido pelo pacote da Microsoft.
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl gnupg ca-certificates \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
    && echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" \
        > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
        msodbcsql18 msodbcsql17 unixodbc \
        `# libgssapi-krb5-2 nao vem por dependencia e o driver carrega por dlopen:` \
        `# sem ela o erro e "Can't open lib ... file not found", que parece falta` \
        `# do arquivo do driver e nao de uma biblioteca dele.` \
        libgssapi-krb5-2 \
    && apt-get purge -y curl gnupg \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

# Usuario sem privilegio: um RCE no processo nao vira root no container.
RUN useradd --system --uid 10001 --home /app --shell /usr/sbin/nologin blackwall \
    && chown -R blackwall:blackwall /app
USER blackwall

EXPOSE 8000

# O /health nao toca no banco — serve para o orquestrador saber se o processo
# subiu. Saude das bases fica em /api/health/db, que e' lento de proposito.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=4).status == 200 else 1)"

# Sem --reload. 2 workers uvicorn NAO servem aqui: o estado dos jobs vive na
# memoria do processo, entao um worker so' — escalar exige trocar por Redis
# antes (ver jobs.py).
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
