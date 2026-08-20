-- Schema das bases de demonstracao do BlackWall Analytics.
--
-- Reproduz o data warehouse que o projeto consultava: 6 tabelas de agregado por
-- base, mais a tabela de gerentes de afiliado — que vive so na base Lumen e e
-- lida das outras por nome de 3 partes (`dw_lumen.dbo.affiliate_manager_lumen`).
--
-- Os nomes de coluna vem do catalogo em `backend/app/sql/`: 292 arquivos de
-- T-SQL rodam contra este schema sem uma linha alterada. `db/verify_catalog.py`
-- compila todos e falha se faltar coluna.
--
-- Indices: seguem o que os comentarios do catalogo descrevem — chave por
-- Date_Time (em payments, Date_Time + Status). `Date_Agg` fica SEM indice de
-- proposito: o catalogo documenta que filtrar por ela custa varredura, e a ideia
-- aqui e reproduzir o comportamento do ambiente original, nao corrigi-lo.
--
-- Sem IDENTITY nas tabelas horarias: a carga e por BULK INSERT, que mapeia os
-- campos do arquivo posicionalmente para TODAS as colunas da tabela.
--
-- `{db}` e substituido por `db/init.py` para cada base.

USE [{db}];
GO

-- Casino: um agregado por jogador / hora / provedor.
IF OBJECT_ID('dbo.casino_agg_hourly', 'U') IS NULL
CREATE TABLE dbo.casino_agg_hourly (
    User_Id        INT            NOT NULL,
    Date_Time      DATETIME       NOT NULL,
    Date_Agg       DATE           NOT NULL,
    Provider_Name  VARCHAR(60)    NULL,
    Bet_Count      INT            NOT NULL,
    Turnover       DECIMAL(18, 2) NOT NULL,
    GGR            DECIMAL(18, 2) NOT NULL,
    NGR            DECIMAL(18, 2) NOT NULL,
    turnover_bonus DECIMAL(18, 2) NULL
);
GO

-- Sportsbook: mesmo formato, sem provedor.
IF OBJECT_ID('dbo.sports_agg_hourly', 'U') IS NULL
CREATE TABLE dbo.sports_agg_hourly (
    User_Id        INT            NOT NULL,
    Date_Time      DATETIME       NOT NULL,
    Date_Agg       DATE           NOT NULL,
    Bet_Count      INT            NOT NULL,
    Turnover       DECIMAL(18, 2) NOT NULL,
    GGR            DECIMAL(18, 2) NOT NULL,
    NGR            DECIMAL(18, 2) NOT NULL,
    turnover_bonus DECIMAL(18, 2) NULL
);
GO

-- Pagamentos. `Status` e anulavel de proposito: metade do catalogo depende de
-- `Status = 'Completed'` justamente porque a base grava linha sem status.
IF OBJECT_ID('dbo.payments_agg_hourly', 'U') IS NULL
CREATE TABLE dbo.payments_agg_hourly (
    User_Id            INT            NOT NULL,
    Date_Time          DATETIME       NOT NULL,
    Date_Agg           DATE           NOT NULL,
    Status             VARCHAR(20)    NULL,
    Deposits_Amount    DECIMAL(18, 2) NOT NULL,
    Deposits_Count     INT            NOT NULL,
    Withdrawals_Amount DECIMAL(18, 2) NOT NULL,
    Withdrawals_Count  INT            NOT NULL,
    -- Deposito menos saque, ja gravado pelo ETL: o Retention Cohort le esta
    -- coluna em vez de recalcular (graphics/retention_cohort.sql).
    Netcash            DECIMAL(18, 2) NOT NULL
);
GO

-- Primeiro deposito: uma linha por jogador convertido.
IF OBJECT_ID('dbo.ftd_agg', 'U') IS NULL
CREATE TABLE dbo.ftd_agg (
    User_Id           INT            NOT NULL,
    FTD_Date          DATE           NOT NULL,
    FTD_Amount        DECIMAL(18, 2) NOT NULL,
    FTD_QTD           INT            NOT NULL,
    Affiliate_Id      INT            NULL,
    Affiliate_Name    VARCHAR(80)    NULL,
    Affiliate_Manager VARCHAR(80)    NULL
);
GO

-- Cadastro / origem do jogador.
IF OBJECT_ID('dbo.acquisitions_agg', 'U') IS NULL
CREATE TABLE dbo.acquisitions_agg (
    User_Id             INT         NOT NULL,
    Registration_Date   DATE        NOT NULL,
    Acquisition_Channel VARCHAR(60) NULL,
    Affiliate_Id        INT         NULL,
    Affiliate_Name      VARCHAR(80) NULL,
    btag                VARCHAR(60) NULL
);
GO

-- Cadastro de afiliados.
IF OBJECT_ID('dbo.affiliates_agg', 'U') IS NULL
CREATE TABLE dbo.affiliates_agg (
    Affiliate_Id      INT         NOT NULL,
    Affiliate_Name    VARCHAR(80) NOT NULL,
    Affiliate_Manager VARCHAR(80) NULL,
    -- O monitoring de afiliados deduplica por `ROW_NUMBER() ... ORDER BY
    -- update_time DESC`: o mesmo afiliado pode ter trocado de gerente.
    update_time       DATETIME    NULL
);
GO

-- Indices. O clustered fica em Date_Time nas tabelas horarias: e a coluna que o
-- catalogo usa em todo filtro de periodo.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'SK01_casino_agg_hourly')
    CREATE CLUSTERED INDEX SK01_casino_agg_hourly ON dbo.casino_agg_hourly (Date_Time);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'SK02_casino_agg_hourly')
    CREATE NONCLUSTERED INDEX SK02_casino_agg_hourly ON dbo.casino_agg_hourly (User_Id);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'SK01_sports_agg_hourly')
    CREATE CLUSTERED INDEX SK01_sports_agg_hourly ON dbo.sports_agg_hourly (Date_Time);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'SK02_sports_agg_hourly')
    CREATE NONCLUSTERED INDEX SK02_sports_agg_hourly ON dbo.sports_agg_hourly (User_Id);
GO

-- Payments: (Date_Time, Status) — o filtro do catalogo e sempre os dois juntos.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'SK01_payments_agg_hourly')
    CREATE CLUSTERED INDEX SK01_payments_agg_hourly
        ON dbo.payments_agg_hourly (Date_Time, Status);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'SK02_payments_agg_hourly')
    CREATE NONCLUSTERED INDEX SK02_payments_agg_hourly ON dbo.payments_agg_hourly (User_Id);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'SK01_ftd_agg')
    CREATE CLUSTERED INDEX SK01_ftd_agg ON dbo.ftd_agg (FTD_Date);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'SK02_ftd_agg')
    CREATE NONCLUSTERED INDEX SK02_ftd_agg ON dbo.ftd_agg (User_Id);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'SK01_acquisitions_agg')
    CREATE CLUSTERED INDEX SK01_acquisitions_agg ON dbo.acquisitions_agg (User_Id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'SK02_acquisitions_agg')
    CREATE NONCLUSTERED INDEX SK02_acquisitions_agg
        ON dbo.acquisitions_agg (Registration_Date);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'SK03_acquisitions_agg')
    CREATE NONCLUSTERED INDEX SK03_acquisitions_agg ON dbo.acquisitions_agg (Affiliate_Name);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'SK01_affiliates_agg')
    CREATE CLUSTERED INDEX SK01_affiliates_agg ON dbo.affiliates_agg (Affiliate_Id);
GO

-- Marcador de carga: `db/init.py` usa para nao semear duas vezes.
IF OBJECT_ID('dbo.blackwall_seed', 'U') IS NULL
CREATE TABLE dbo.blackwall_seed (
    Seed_Version VARCHAR(20)  NOT NULL,
    Loaded_At    DATETIME     NOT NULL,
    Row_Summary  VARCHAR(400) NULL
);
GO
