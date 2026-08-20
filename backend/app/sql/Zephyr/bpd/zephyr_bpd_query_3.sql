DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';

-- Variável interna para ajustar o intervalo (não precisa mexer aqui)
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

SELECT categoria, dep_all_cohort
FROM (
    -- Internal Traffic
    SELECT 'Internal Traffic' AS categoria, SUM(dep.Deposits_Amount) AS dep_all_cohort
    FROM payments_agg_hourly dep
    INNER JOIN (
        SELECT DISTINCT acq.User_Id
        FROM acquisitions_agg acq WITH(NOLOCK)
        LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
        WHERE aff.affiliate_manager IN ('GoogleAds', 'GoogleAdsNOVO', 'MetaAds', 'MetaAdsNOVO', 'TráfegoGeral')
    ) AS filtered_users ON dep.User_Id = filtered_users.User_Id
    WHERE dep.Date_Agg >= @data_ini AND dep.Date_Agg < @data_fim_exclusive
    AND dep.Status = 'Completed'

    UNION ALL

    -- Affiliates
    SELECT 'Affiliates' AS categoria, SUM(dep.Deposits_Amount) AS dep_all_cohort
    FROM payments_agg_hourly dep
    INNER JOIN (
        SELECT DISTINCT acq.User_Id
        FROM acquisitions_agg acq WITH(NOLOCK)
        LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
        WHERE aff.affiliate_manager IN ('AfiliadosAtivosCpa', 'AfiliadosAtivosHib', 'AfiliadosAtivosRev', 'Afiliadosinativos', 'PeaklineMedia', 'DistratoRev', 'VertexGroup')
    ) AS filtered_users ON dep.User_Id = filtered_users.User_Id
    WHERE dep.Date_Agg >= @data_ini AND dep.Date_Agg < @data_fim_exclusive
    AND dep.Status = 'Completed'

    UNION ALL

    -- Organic
    SELECT 'Organic' AS categoria, SUM(dep.Deposits_Amount) AS dep_all_cohort
    FROM payments_agg_hourly dep
    INNER JOIN (
        SELECT DISTINCT acq.User_Id
        FROM acquisitions_agg acq WITH(NOLOCK)
        LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
        WHERE aff.affiliate_id is NULL
    ) AS filtered_users ON dep.User_Id = filtered_users.User_Id
    WHERE dep.Date_Agg >= @data_ini AND dep.Date_Agg < @data_fim_exclusive
    AND dep.Status = 'Completed'

    UNION ALL

    -- External Traffic
    SELECT 'External Traffic' AS categoria, SUM(dep.Deposits_Amount) AS dep_all_cohort
    FROM payments_agg_hourly dep
    INNER JOIN (
        SELECT DISTINCT acq.User_Id
        FROM acquisitions_agg acq WITH(NOLOCK)
        LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
        WHERE aff.affiliate_manager = 'parceiroadmin'
    ) AS filtered_users ON dep.User_Id = filtered_users.User_Id
    WHERE dep.Date_Agg >= @data_ini AND dep.Date_Agg < @data_fim_exclusive
    AND dep.Status = 'Completed'

    UNION ALL

    -- Influencers
    SELECT 'Influencers' AS categoria, SUM(dep.Deposits_Amount) AS dep_all_cohort
    FROM payments_agg_hourly dep
    INNER JOIN (
        SELECT DISTINCT acq.User_Id
        FROM acquisitions_agg acq WITH(NOLOCK)
        LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
        WHERE aff.affiliate_manager = 'InfluenciadoresZephyr'
    ) AS filtered_users ON dep.User_Id = filtered_users.User_Id
    WHERE dep.Date_Agg >= @data_ini AND dep.Date_Agg < @data_fim_exclusive
    AND dep.Status = 'Completed'

) AS resultados;
