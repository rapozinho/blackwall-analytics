DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';

-- Variável interna para ajustar o intervalo
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

-- CTE para agrupar GGR por usuário (casino + sports)
WITH user_ggr AS (
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

    -- Internal Traffic
    SELECT
        'Internal Traffic' AS categoria,
        ug.GGR_Total
    FROM
        user_ggr ug
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
            WHERE aff.affiliate_manager IN ('GoogleAds', 'GoogleAdsNOVO', 'MetaAds', 'MetaAdsNOVO', 'TráfegoGeral')
        ) AS filtered_users
        ON ug.User_Id = filtered_users.User_Id

    UNION ALL

    -- Affiliates
    SELECT
        'Affiliates' AS categoria,
        ug.GGR_Total
    FROM
        user_ggr ug
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
            WHERE aff.affiliate_manager IN ('AfiliadosAtivosCpa', 'AfiliadosAtivosHib', 'AfiliadosAtivosRev', 'Afiliadosinativos', 'PeaklineMedia', 'DistratoRev', 'VertexGroup')
        ) AS filtered_users
        ON ug.User_Id = filtered_users.User_Id

    UNION ALL

    -- Organic
    SELECT
        'Organic' AS categoria,
        ug.GGR_Total
    FROM
        user_ggr ug
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
            WHERE aff.affiliate_id is NULL
        ) AS filtered_users
        ON ug.User_Id = filtered_users.User_Id

    UNION ALL

    -- External Traffic
    SELECT
        'External Traffic' AS categoria,
        ug.GGR_Total
    FROM
        user_ggr ug
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
            WHERE aff.affiliate_manager = 'parceiroadmin'
        ) AS filtered_users
        ON ug.User_Id = filtered_users.User_Id

    UNION ALL

    -- Influencers
    SELECT
        'Influencers' AS categoria,
        ug.GGR_Total
    FROM
        user_ggr ug
        INNER JOIN (
            SELECT DISTINCT acq.User_Id
            FROM acquisitions_agg acq WITH(NOLOCK)
            LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
            WHERE aff.affiliate_manager = 'InfluenciadoresZephyr'
        ) AS filtered_users
        ON ug.User_Id = filtered_users.User_Id

) AS resultados
GROUP BY
    categoria;
