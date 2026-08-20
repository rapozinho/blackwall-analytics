# -*- coding: utf-8 -*-
"""Prepara o SQL Server de demonstracao: bases, login read-only, schema e carga.

Roda como o servico `dbinit` do compose, uma vez, antes do backend subir. E
idempotente: se a base ja tem o marcador `blackwall_seed` da versao atual, nao
gera nem carrega nada — `docker compose up` de novo nao duplica dado.

Ordem: Lumen primeiro, porque as queries da Kestrel leem a tabela de gerentes
dela por nome de 3 partes.

Este e o unico lugar do projeto que escreve no banco. O backend continua
read-only, e o login que ele usa (`DB_USER`) so entra em `db_datareader`.
"""
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path

import pyodbc

from bases import BASES, ORDEM, SEED_VERSION, TABELAS
from generate import DATA_FIM, DATA_INI, gerar_tudo
from verticals import VERTICAL

# A vertical entra na versao: trocar `VERTICAL=bet` por `ecommerce` muda o dado,
# entao o marcador precisa mudar tambem — senao o `up` seguinte acharia que a base
# ja esta carregada e o portal mostraria numero de aposta com rotulo de varejo.
VERSAO = f"{SEED_VERSION}-{VERTICAL}"

AQUI = Path(__file__).resolve().parent

SERVIDOR = os.getenv("SEED_SERVER", "sqlserver")
SA_PASSWORD = os.environ["MSSQL_SA_PASSWORD"]
DRIVER = os.getenv("ODBC_DRIVER", "ODBC Driver 18 for SQL Server")

# Login que o backend usa. Somente leitura, criado aqui.
RO_USER = os.getenv("DB_USER", "blackwall_ro")
RO_PASSWORD = os.environ["DB_PASSWORD"]

# Pasta compartilhada com o container do SQL Server: o Python escreve o CSV e o
# BULK INSERT le do mesmo caminho, de dentro do servidor.
DADOS = Path(os.getenv("SEED_DATA_DIR", "/seed"))
DADOS_NO_SERVIDOR = os.getenv("SEED_DATA_DIR_SERVER", str(DADOS))

ESPERA_MAX = int(os.getenv("SEED_WAIT_SECONDS", "180"))


def log(msg: str) -> None:
    print(f"[dbinit] {msg}", flush=True)


def conectar(database: str = "master", timeout: int = 5) -> pyodbc.Connection:
    conn = pyodbc.connect(
        f"DRIVER={{{DRIVER}}};SERVER={SERVIDOR};DATABASE={database};"
        f"UID=sa;PWD={SA_PASSWORD};Encrypt=yes;TrustServerCertificate=yes;",
        timeout=timeout, autocommit=True,
    )
    return conn


def esperar_servidor() -> pyodbc.Connection:
    """O container do SQL Server aceita TCP antes de aceitar login: tentar
    conectar em loop e a unica checagem que vale."""
    limite = time.monotonic() + ESPERA_MAX
    ultimo = ""
    while time.monotonic() < limite:
        try:
            conn = conectar()
            log("SQL Server respondeu.")
            return conn
        except pyodbc.Error as e:
            ultimo = str(e).splitlines()[0][:160]
            time.sleep(3)
    raise SystemExit(f"[dbinit] SQL Server nao respondeu em {ESPERA_MAX}s: {ultimo}")


def lotes(sql: str):
    """Divide o script em lotes pelo separador `GO`, como o sqlcmd faz."""
    atual: list[str] = []
    for linha in sql.splitlines():
        if linha.strip().upper() == "GO":
            if any(l.strip() for l in atual):
                yield "\n".join(atual)
            atual = []
        else:
            atual.append(linha)
    if any(l.strip() for l in atual):
        yield "\n".join(atual)


def _identificador(nome: str, rotulo: str) -> str:
    """Nome de objeto vem de variavel de ambiente e entra em DDL por f-string
    (`CREATE LOGIN` nao aceita parametro). Entao valida antes."""
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.\-]{0,60}", nome):
        raise SystemExit(f"[dbinit] {rotulo} invalido: {nome!r}")
    return nome


def criar_bases(cur) -> None:
    for base_key in ORDEM:
        db = _identificador(BASES[base_key]["database"], "nome de database")
        cur.execute("SELECT DB_ID(?)", db)
        if cur.fetchval() is None:
            cur.execute(f"CREATE DATABASE [{db}]")
        # SIMPLE: num ambiente de demonstracao nao existe backup de log, e a
        # carga em massa nao infla o transaction log.
        cur.execute(f"ALTER DATABASE [{db}] SET RECOVERY SIMPLE")
        log(f"base {db} pronta")


def criar_login(cur) -> None:
    """Login somente leitura que o backend usa.

    `CREATE LOGIN` nao aceita parametro nem `EXEC()` com chamada de funcao, entao
    o nome e validado (`_identificador`) e a senha tem a aspa duplicada.
    CHECK_POLICY=OFF: a senha vem do compose, e a politica do container recusaria
    troca de senha em ambiente local.
    """
    usuario = _identificador(RO_USER, "DB_USER")
    senha = RO_PASSWORD.replace("'", "''")
    cur.execute("SELECT 1 FROM sys.server_principals WHERE name = ?", usuario)
    if cur.fetchval() is None:
        cur.execute(f"CREATE LOGIN [{usuario}] WITH PASSWORD = '{senha}', "
                    f"CHECK_POLICY = OFF")
    log(f"login {usuario} pronto")


def dar_acesso(base_key: str) -> None:
    """Usuario do login em cada base, com db_datareader e nada mais.

    Precisa existir nas 4 bases mesmo que o backend conecte em uma: as queries da
    Kestrel leem `dw_lumen.dbo.affiliate_manager_lumen`, e permissao
    cross-database e resolvida na base de destino.
    """
    db = BASES[base_key]["database"]
    usuario = _identificador(RO_USER, "DB_USER")
    with conectar(db) as conn:
        cur = conn.cursor()
        cur.execute("SELECT 1 FROM sys.database_principals WHERE name = ?", usuario)
        if cur.fetchval() is None:
            cur.execute(f"CREATE USER [{usuario}] FOR LOGIN [{usuario}]")
        cur.execute(f"ALTER ROLE db_datareader ADD MEMBER [{usuario}]")


def descartar_tabelas(base_key: str) -> None:
    """Apaga as tabelas da base antes de reaplicar o schema.

    O schema usa `IF OBJECT_ID(...) IS NULL CREATE TABLE`, que nao acrescenta
    coluna em tabela que ja existe. Quando `SEED_VERSION` muda — sinal de que o
    modelo mudou — recriar do zero e mais honesto que tentar migrar um banco de
    demonstracao. Sem isto, mexer no schema exigiria `docker compose down -v`.
    """
    cfg = BASES[base_key]
    tabelas = list(TABELAS) + ["blackwall_seed"]
    if cfg["manager_table"]:
        tabelas.append("affiliate_manager_lumen")
    with conectar(cfg["database"], timeout=30) as conn:
        cur = conn.cursor()
        for tabela in tabelas:
            cur.execute(f"DROP TABLE IF EXISTS dbo.{tabela}")


def aplicar_schema(base_key: str) -> None:
    cfg = BASES[base_key]
    db = cfg["database"]
    scripts = [AQUI / "schema.sql"]
    if cfg["manager_table"]:
        scripts.append(AQUI / "schema_manager.sql")

    with conectar(db, timeout=30) as conn:
        cur = conn.cursor()
        for script in scripts:
            sql = script.read_text(encoding="utf-8").replace("{db}", db)
            for lote in lotes(sql):
                cur.execute(lote)
        # A base Lumen nao tem `turnover_bonus` — o `.sql` de bonus dela esta
        # inteiro comentado no catalogo por causa disso. Reproduzir a ausencia da
        # coluna e o que mantem o report identico ao do ambiente original.
        if not cfg["tem_turnover_bonus"]:
            for tabela in ("casino_agg_hourly", "sports_agg_hourly"):
                cur.execute(
                    f"IF COL_LENGTH('dbo.{tabela}', 'turnover_bonus') IS NOT NULL "
                    f"ALTER TABLE dbo.{tabela} DROP COLUMN turnover_bonus")
    log(f"schema aplicado em {db}")


def ja_semeada(base_key: str) -> bool:
    db = BASES[base_key]["database"]
    with conectar(db) as conn:
        cur = conn.cursor()
        cur.execute("IF OBJECT_ID('dbo.blackwall_seed','U') IS NULL SELECT 0 ELSE "
                    "SELECT COUNT(*) FROM dbo.blackwall_seed WHERE Seed_Version = ?",
                    VERSAO)
        return (cur.fetchval() or 0) > 0


def carregar(base_key: str, contagens: dict[str, int]) -> None:
    cfg = BASES[base_key]
    db = cfg["database"]
    tabelas = list(TABELAS) + (["affiliate_manager_lumen"] if cfg["manager_table"] else [])

    with conectar(db, timeout=30) as conn:
        conn.timeout = 900          # BULK INSERT de tabela grande
        cur = conn.cursor()
        for tabela in tabelas:
            arquivo = f"{DADOS_NO_SERVIDOR}/{base_key}.{tabela}.csv"
            cur.execute(f"DELETE FROM dbo.{tabela}")
            # KEEPNULLS: campo vazio no CSV vira NULL, e nao '' nem 0. O catalogo
            # depende disso (`affiliate_id IS NULL` = jogador organico,
            # `Status` nulo em payments).
            # Sem CODEPAGE: a opcao nao existe no SQL Server para Linux. O arquivo
            # ja vem em CP1252 (ver `generate.ENCODING_CARGA`), que e o collation
            # padrao do servidor.
            cur.execute(f"""
                BULK INSERT dbo.{tabela}
                FROM '{arquivo}'
                WITH (FIELDTERMINATOR = '|', ROWTERMINATOR = '0x0a',
                      KEEPNULLS, TABLOCK, BATCHSIZE = 50000)
            """)
            cur.execute(f"SELECT COUNT(*) FROM dbo.{tabela}")
            n = cur.fetchval()
            esperado = contagens.get(tabela, 0)
            if n != esperado:
                raise SystemExit(f"[dbinit] {db}.{tabela}: carregou {n}, esperava {esperado}")
            log(f"{db}.{tabela}: {n:,} linhas")
            cur.execute(f"UPDATE STATISTICS dbo.{tabela} WITH FULLSCAN")

        resumo = ", ".join(f"{t}={contagens.get(t, 0)}" for t in tabelas)
        cur.execute("DELETE FROM dbo.blackwall_seed WHERE Seed_Version = ?", VERSAO)
        cur.execute("INSERT INTO dbo.blackwall_seed (Seed_Version, Loaded_At, Row_Summary) "
                    "VALUES (?, ?, ?)", VERSAO, datetime.now(), resumo[:400])


def main() -> int:
    inicio = time.monotonic()
    conn = esperar_servidor()
    cur = conn.cursor()
    criar_bases(cur)
    criar_login(cur)
    conn.close()

    # Quem ja esta na versao corrente nao e tocado; o resto e recriado do zero.
    pendentes = [b for b in ORDEM if not ja_semeada(b)]
    for base_key in ORDEM:
        dar_acesso(base_key)
        if base_key in pendentes:
            descartar_tabelas(base_key)
        aplicar_schema(base_key)

    if not pendentes:
        log(f"dados {VERSAO} ja carregados nas 4 bases; nada a fazer.")
        return 0

    log(f"vertical={VERTICAL} | gerando dados ficticios ({DATA_INI} .. {DATA_FIM}) "
        f"para: {', '.join(pendentes)}")
    DADOS.mkdir(parents=True, exist_ok=True)
    contagens = gerar_tudo(DADOS, pendentes)
    for base_key in pendentes:
        # 0666/0777: o processo do SQL Server roda com outro usuario e precisa ler
        # os arquivos do volume compartilhado.
        for arquivo in DADOS.glob(f"{base_key}.*.csv"):
            arquivo.chmod(0o644)
        carregar(base_key, contagens[base_key])
        for arquivo in DADOS.glob(f"{base_key}.*.csv"):
            arquivo.unlink()

    log(f"pronto em {time.monotonic() - inicio:.0f}s")
    return 0


if __name__ == "__main__":
    try:
        os.umask(0o022)
        sys.exit(main())
    except pyodbc.Error as e:
        log(f"ERRO de banco: {str(e)[:500]}")
        sys.exit(1)
