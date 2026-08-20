DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';

-- Variável interna para ajustar o intervalo
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

-- CTE: Tabela de gerentes preparada (Dedup por Username)
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
    dep_all_cohort
FROM (
    
    -- 1. Internal Traffic (Marketing interno)
    SELECT 
        'Internal Traffic' AS categoria, 
        SUM(dep.Deposits_Amount) AS dep_all_cohort
    FROM 
        payments_agg_hourly dep WITH(NOLOCK)
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE am.channel_type = 'Marketing interno'
        ) AS filtered_users ON dep.User_Id = filtered_users.User_Id
    WHERE 
        dep.Date_Agg >= @data_ini AND dep.Date_Agg < @data_fim_exclusive
        AND dep.Status = 'Completed'

    UNION ALL

    -- 2. Affiliates (Afiliados)
    SELECT 
        'Affiliates' AS categoria, 
        SUM(dep.Deposits_Amount) AS dep_all_cohort
    FROM 
        payments_agg_hourly dep WITH(NOLOCK)
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE am.channel_type = 'Afiliados'
        ) AS filtered_users ON dep.User_Id = filtered_users.User_Id
    WHERE 
        dep.Date_Agg >= @data_ini AND dep.Date_Agg < @data_fim_exclusive
        AND dep.Status = 'Completed'


    UNION ALL

    -- 3. Organic (Orgânico - Mantém lógica direta na aquisição)
    SELECT 
        'Organic' AS categoria, 
        SUM(dep.Deposits_Amount) AS dep_all_cohort
    FROM 
        payments_agg_hourly dep WITH(NOLOCK)
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            WHERE acq.acquisition_channel = 'Organic'
        ) AS filtered_users ON dep.User_Id = filtered_users.User_Id
    WHERE 
        dep.Date_Agg >= @data_ini AND dep.Date_Agg < @data_fim_exclusive
        AND dep.Status = 'Completed'

    UNION ALL

    -- 4. External Traffic (Tráfego externo)
    SELECT 
        'External Traffic' AS categoria, 
        SUM(dep.Deposits_Amount) AS dep_all_cohort
    FROM 
        payments_agg_hourly dep WITH(NOLOCK)
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE am.channel_type = 'Tráfego externo'
        ) AS filtered_users ON dep.User_Id = filtered_users.User_Id
    WHERE 
        dep.Date_Agg >= @data_ini AND dep.Date_Agg < @data_fim_exclusive
        AND dep.Status = 'Completed'

    UNION ALL

    -- 5. Influencers (Influenciadores)
    SELECT 
        'Influencers' AS categoria, 
        SUM(dep.Deposits_Amount) AS dep_all_cohort
    FROM 
        payments_agg_hourly dep WITH(NOLOCK)
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE am.channel_type = 'Influenciadores'
        ) AS filtered_users ON dep.User_Id = filtered_users.User_Id
    WHERE 
        dep.Date_Agg >= @data_ini AND dep.Date_Agg < @data_fim_exclusive
        AND dep.Status = 'Completed'

    UNION ALL

    -- 6. Google Ads (Novo filtro adicionado)
    SELECT 
        'Google Ads' AS categoria, 
        SUM(dep.Deposits_Amount) AS dep_all_cohort
    FROM 
        payments_agg_hourly dep WITH(NOLOCK)
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE am.affiliate_manager = 'GoogleAds'
        ) AS filtered_users ON dep.User_Id = filtered_users.User_Id
    WHERE 
        dep.Date_Agg >= @data_ini AND dep.Date_Agg < @data_fim_exclusive
        AND dep.Status = 'Completed'

) AS resultados;