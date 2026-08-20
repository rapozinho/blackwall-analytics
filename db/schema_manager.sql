-- Tabela de gerentes de afiliado — existe SO na base Lumen.
--
-- As queries da Lumen e da Kestrel a leem por nome de 3 partes
-- (`dw_lumen.dbo.affiliate_manager_lumen`), casando `username` com
-- `acquisitions_agg.affiliate_name`. E a unica leitura cross-database do
-- projeto, e o motivo pelo qual o login read-only precisa de usuario em todas as
-- bases, nao so na que ele conecta.
--
-- `id` existe porque o catalogo deduplica com
-- `ROW_NUMBER() OVER (PARTITION BY username ORDER BY id DESC)`: a tabela tem
-- username repetido, e a linha mais nova ganha.

USE [{db}];
GO

IF OBJECT_ID('dbo.affiliate_manager_lumen', 'U') IS NULL
CREATE TABLE dbo.affiliate_manager_lumen (
    id                INT          NOT NULL,
    username          VARCHAR(80)  NULL,
    affiliate_manager VARCHAR(80)  NULL,
    channel_type      VARCHAR(40)  NULL
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'SK01_affiliate_manager_lumen')
    CREATE CLUSTERED INDEX SK01_affiliate_manager_lumen
        ON dbo.affiliate_manager_lumen (username, id);
GO
