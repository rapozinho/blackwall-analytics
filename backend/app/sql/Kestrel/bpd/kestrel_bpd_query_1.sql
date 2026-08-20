DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';

-- Variável interna para ajustar o intervalo
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

-- CTE PADRÃO: Tabela de gerentes preparada (Dedup por Username)
WITH manager_lumen_by_username AS (
    SELECT *
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY username ORDER BY id DESC) AS rn
        FROM dw_lumen.dbo.affiliate_manager_lumen WITH(NOLOCK)
        WHERE username IS NOT NULL
    ) x
    WHERE rn = 1
)

SELECT 
    categoria, 
    FTDs 
FROM (
    
    -- 1. Internal Traffic (Marketing interno)
    SELECT 
        'Internal Traffic' AS Categoria,
        COUNT(DISTINCT ftd.user_id) AS FTDs
    FROM 
        ftd_agg ftd WITH(NOLOCK)
        INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
        -- Join pelo Nome = Username
        INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
    WHERE 
        ftd.ftd_date >= @data_ini AND ftd.ftd_date < @data_fim_exclusive 
        AND am.channel_type = 'Marketing interno'

    UNION ALL

    -- 2. Affiliates (Afiliados)
    SELECT 
        'Affiliates' AS Categoria,
        COUNT(DISTINCT ftd.user_id) AS FTDs
    FROM 
        ftd_agg ftd WITH(NOLOCK)
        INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
        INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
    WHERE 
        ftd.ftd_date >= @data_ini AND ftd.ftd_date < @data_fim_exclusive 
        AND am.channel_type = 'Afiliados'

    UNION ALL

    -- 3. Organic (Orgânico - Mantém lógica direta na aquisição)
    SELECT 
        'Organic' AS Categoria,
        COUNT(DISTINCT ftd.user_id) AS FTDs
    FROM 
        ftd_agg ftd WITH(NOLOCK)
        INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
    WHERE 
        ftd.ftd_date >= @data_ini AND ftd.ftd_date < @data_fim_exclusive 
        AND acq.acquisition_channel = 'Organic'

    UNION ALL

    -- 4. External Traffic (Tráfego externo)
    SELECT 
        'External Traffic' AS Categoria,
        COUNT(DISTINCT ftd.user_id) AS FTDs
    FROM 
        ftd_agg ftd WITH(NOLOCK)
        INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
        INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
    WHERE 
        ftd.ftd_date >= @data_ini AND ftd.ftd_date < @data_fim_exclusive 
        AND am.channel_type = 'Tráfego externo'

    UNION ALL

    -- 5. Influencers (Influenciadores)
    SELECT 
        'Influencers' AS Categoria, 
        COUNT(DISTINCT ftd.user_id) AS FTDs
    FROM 
        ftd_agg ftd WITH(NOLOCK)
        INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
        INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
    WHERE 
        ftd.ftd_date >= @data_ini AND ftd.ftd_date < @data_fim_exclusive 
        AND am.channel_type = 'Influenciadores'
    UNION ALL

    SELECT 
        'Google Ads' AS Categoria, 
        COUNT(DISTINCT ftd.user_id) AS FTDs
    FROM 
        ftd_agg ftd WITH(NOLOCK)
        INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
        INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
    WHERE 
        ftd.ftd_date >= @data_ini AND ftd.ftd_date < @data_fim_exclusive 
        AND am.affiliate_manager = 'GoogleAds'


) AS resultado_final;