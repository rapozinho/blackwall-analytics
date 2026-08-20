DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';

-- Variável interna para ajustar o intervalo
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

-- CTE 1: Tabela de gerentes preparada (Dedup por Username)
WITH manager_lumen_by_username AS (
    SELECT *
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY username ORDER BY id DESC) AS rn
        FROM dw_lumen.dbo.affiliate_manager_lumen WITH(NOLOCK)
        WHERE username IS NOT NULL
    ) x
    WHERE rn = 1
),
-- CTE 2: Agrupa GGR por usuário (casino + sports)
user_ggr AS (
    SELECT 
        ug.User_Id, 
        SUM(ug.GGR) AS GGR_Total
    FROM (
        SELECT User_Id, GGR, Date_Agg FROM casino_agg_hourly WITH(NOLOCK)
        UNION ALL
        SELECT User_Id, GGR, Date_Agg FROM sports_agg_hourly WITH(NOLOCK)
    ) AS ug
    WHERE 
        ug.Date_Agg >= @data_ini AND ug.Date_Agg < @data_fim_exclusive
    GROUP BY 
        ug.User_Id
)

-- Seleciona o total de GGR por categoria de aquisição
SELECT 
    categoria, 
    SUM(GGR_Total) AS GGR_all_cohort
FROM (
    
    -- 1. Internal Traffic (Marketing interno)
    SELECT 
        'Internal Traffic' AS categoria, 
        ug.GGR_Total
    FROM 
        user_ggr ug
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE am.channel_type = 'Marketing interno'
        ) AS filtered_users 
        ON ug.User_Id = filtered_users.User_Id

    UNION ALL

    -- 2. Affiliates (Afiliados)
    SELECT 
        'Affiliates' AS categoria, 
        ug.GGR_Total
    FROM 
        user_ggr ug
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE am.channel_type = 'Afiliados'
        ) AS filtered_users 
        ON ug.User_Id = filtered_users.User_Id

    UNION ALL

    -- 3. Organic (Mantém lógica direta na aquisição)
    SELECT 
        'Organic' AS categoria, 
        ug.GGR_Total
    FROM 
        user_ggr ug
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            WHERE acq.acquisition_channel = 'Others'
        ) AS filtered_users 
        ON ug.User_Id = filtered_users.User_Id

    UNION ALL

    -- 4. External Traffic (Tráfego externo)
    SELECT 
        'External Traffic' AS categoria, 
        ug.GGR_Total
    FROM 
        user_ggr ug
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE am.channel_type = 'Tráfego externo'
        ) AS filtered_users 
        ON ug.User_Id = filtered_users.User_Id

    UNION ALL

    -- 5. Influencers (Influenciadores)
    SELECT 
        'Influencers' AS categoria, 
        ug.GGR_Total
    FROM 
        user_ggr ug
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE am.channel_type = 'Influenciadores'
        ) AS filtered_users 
        ON ug.User_Id = filtered_users.User_Id

    UNION ALL

    -- 6. Google Ads (Novo filtro adicionado)
    SELECT 
        'Google Ads' AS categoria, 
        ug.GGR_Total
    FROM 
        user_ggr ug
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE am.affiliate_manager = 'GoogleAds'
        ) AS filtered_users 
        ON ug.User_Id = filtered_users.User_Id

) AS resultados
GROUP BY 
    categoria;