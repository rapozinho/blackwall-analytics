DECLARE @data_ini1 DATE = '{start1}';
DECLARE @data_fim1 DATE = '{end1}';

DECLARE @data_ini2 DATE = '{start2}';
DECLARE @data_fim2 DATE = '{end2}';

DECLARE @data_fim_exclusive1 DATE = DATEADD(day, 1, @data_fim1);
DECLARE @data_fim_exclusive2 DATE = DATEADD(day, 1, @data_fim2);

-- 1. Tabela Lumen preparada (Join por Username)
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
-- 2. Agregado de GGR por Usuário
user_ggr AS (
    SELECT c.User_Id, SUM(c.GGR) AS GGR_Total, c.Date_Agg
    FROM casino_agg_hourly c WITH(NOLOCK)
    GROUP BY c.User_Id, c.Date_Agg
    UNION ALL
    SELECT s.User_Id, SUM(s.GGR) AS GGR_Total, s.Date_Agg
    FROM sports_agg_hourly s WITH(NOLOCK)
    GROUP BY s.User_Id, s.Date_Agg
),
dataset_period AS (
    -- Período 1
    SELECT
        'P1' AS periodo,
        ftd_counts.FTD_QTD,
        ggr_current.GGR_current_cohort,
        dep_current.dep_current_cohort,
        ggr_all.GGR_all_cohort,
        dep_all.dep_all_cohort
    FROM
        (SELECT COUNT(DISTINCT ftd.user_id) AS FTD_QTD
         FROM ftd_agg ftd WITH(NOLOCK)
         INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
         -- Lógica Lumen: Nome = Username
         INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
         -- FILTRO SOLICITADO
         WHERE ftd.ftd_date >= @data_ini1 AND ftd.ftd_date < @data_fim_exclusive1 
           AND am.channel_type = 'Afiliados') ftd_counts
    LEFT JOIN (
        SELECT CAST(SUM(ug.GGR_Total) AS DECIMAL(18,2)) AS GGR_current_cohort
        FROM (
            SELECT DISTINCT ftd.user_id
            FROM ftd_agg ftd WITH(NOLOCK)
            INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE ftd.ftd_date >= @data_ini1 AND ftd.ftd_date < @data_fim_exclusive1 
              AND am.channel_type = 'Afiliados'
        ) AS FTD_Users_In_Period
        INNER JOIN user_ggr ug ON ug.User_Id = FTD_Users_In_Period.user_id
        WHERE ug.Date_Agg >= @data_ini1 AND ug.Date_Agg < @data_fim_exclusive1 
    ) ggr_current ON 1=1
    LEFT JOIN (
        SELECT CAST(SUM(dep.Deposits_Amount) AS DECIMAL(18,2)) AS dep_current_cohort
        FROM (
            SELECT DISTINCT ftd.user_id
            FROM ftd_agg ftd WITH(NOLOCK)
            INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE ftd.ftd_date >= @data_ini1 AND ftd.ftd_date < @data_fim_exclusive1 
              AND am.channel_type = 'Afiliados'
        ) AS FTD_Users_In_Period
        INNER JOIN payments_agg_hourly dep WITH(NOLOCK) ON dep.User_Id = FTD_Users_In_Period.user_id
        WHERE dep.Date_Agg >= @data_ini1 AND dep.Date_Agg < @data_fim_exclusive1
        AND dep.Status = 'Completed'
    ) dep_current ON 1=1
    LEFT JOIN (
        SELECT CAST(SUM(ug.GGR_Total) AS DECIMAL(18,2)) AS GGR_all_cohort
        FROM (
            SELECT DISTINCT acq.user_id
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE am.channel_type = 'Afiliados'
        ) AS Acquired_Users
        INNER JOIN user_ggr ug ON ug.User_Id = Acquired_Users.user_id
        WHERE ug.Date_Agg >= @data_ini1 AND ug.Date_Agg < @data_fim_exclusive1 
    ) ggr_all ON 1=1
    LEFT JOIN (
        SELECT CAST(SUM(dep.Deposits_Amount) AS DECIMAL(18,2)) AS dep_all_cohort
        FROM (
            SELECT DISTINCT acq.user_id
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE am.channel_type = 'Afiliados'
        ) AS Acquired_Users
        INNER JOIN payments_agg_hourly dep WITH(NOLOCK) ON dep.User_Id = Acquired_Users.user_id
        WHERE dep.Date_Agg >= @data_ini1 AND dep.Date_Agg < @data_fim_exclusive1
        AND dep.Status = 'Completed'
    ) dep_all ON 1=1

    UNION ALL

    -- Período 2
    SELECT
        'P2' AS periodo,
        ftd_counts.FTD_QTD,
        ggr_current.GGR_current_cohort,
        dep_current.dep_current_cohort,
        ggr_all.GGR_all_cohort,
        dep_all.dep_all_cohort
    FROM
        (SELECT COUNT(DISTINCT ftd.user_id) AS FTD_QTD
         FROM ftd_agg ftd WITH(NOLOCK)
         INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
         INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
         WHERE ftd.ftd_date >= @data_ini2 AND ftd.ftd_date < @data_fim_exclusive2 
           AND am.channel_type = 'Afiliados') ftd_counts
    LEFT JOIN (
        SELECT CAST(SUM(ug.GGR_Total) AS DECIMAL(18,2)) AS GGR_current_cohort
        FROM (
            SELECT DISTINCT ftd.user_id
            FROM ftd_agg ftd WITH(NOLOCK)
            INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE ftd.ftd_date >= @data_ini2 AND ftd.ftd_date < @data_fim_exclusive2 
              AND am.channel_type = 'Afiliados'
        ) AS FTD_Users_In_Period
        INNER JOIN user_ggr ug ON ug.User_Id = FTD_Users_In_Period.user_id
        WHERE ug.Date_Agg >= @data_ini2 AND ug.Date_Agg < @data_fim_exclusive2 
    ) ggr_current ON 1=1
    LEFT JOIN (
        SELECT CAST(SUM(dep.Deposits_Amount) AS DECIMAL(18,2)) AS dep_current_cohort
        FROM (
            SELECT DISTINCT ftd.user_id
            FROM ftd_agg ftd WITH(NOLOCK)
            INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE ftd.ftd_date >= @data_ini2 AND ftd.ftd_date < @data_fim_exclusive2 
              AND am.channel_type = 'Afiliados'
        ) AS FTD_Users_In_Period
        INNER JOIN payments_agg_hourly dep WITH(NOLOCK) ON dep.User_Id = FTD_Users_In_Period.user_id
        WHERE dep.Date_Agg >= @data_ini2 AND dep.Date_Agg < @data_fim_exclusive2
        AND dep.Status = 'Completed' 
    ) dep_current ON 1=1
    LEFT JOIN (
        SELECT CAST(SUM(ug.GGR_Total) AS DECIMAL(18,2)) AS GGR_all_cohort
        FROM (
            SELECT DISTINCT acq.user_id
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE am.channel_type = 'Afiliados'
        ) AS Acquired_Users
        INNER JOIN user_ggr ug ON ug.User_Id = Acquired_Users.user_id
        WHERE ug.Date_Agg >= @data_ini2 AND ug.Date_Agg < @data_fim_exclusive2 
    ) ggr_all ON 1=1
    LEFT JOIN (
        SELECT CAST(SUM(dep.Deposits_Amount) AS DECIMAL(18,2)) AS dep_all_cohort
        FROM (
            SELECT DISTINCT acq.user_id
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
            WHERE am.channel_type = 'Afiliados'
        ) AS Acquired_Users
        INNER JOIN payments_agg_hourly dep WITH(NOLOCK) ON dep.User_Id = Acquired_Users.user_id
        WHERE dep.Date_Agg >= @data_ini2 AND dep.Date_Agg < @data_fim_exclusive2
        AND dep.Status = 'Completed'
    ) dep_all ON 1=1
)
SELECT
    'Affiliates' AS Source,
    -- FTD
    COALESCE(p2.FTD_QTD, 0) AS FTD_QTD,
    CAST(((COALESCE(p2.FTD_QTD, 0) - COALESCE(p1.FTD_QTD, 0)) * 100.0 / NULLIF(COALESCE(p1.FTD_QTD, 0), 0)) AS DECIMAL(10,2)) AS FTD_Percent,

    -- Deposits Current Cohort
    COALESCE(p2.dep_current_cohort, 0) AS dep_current_cohort,
    CAST(((COALESCE(p2.dep_current_cohort, 0) - COALESCE(p1.dep_current_cohort, 0)) * 100.0 / NULLIF(COALESCE(p1.dep_current_cohort, 0), 0)) AS DECIMAL(10,2)) AS dep_current_Percent,

    -- Deposits All Cohort
    COALESCE(p2.dep_all_cohort, 0) AS dep_all_cohort,
    CAST(((COALESCE(p2.dep_all_cohort, 0) - COALESCE(p1.dep_all_cohort, 0)) * 100.0 / NULLIF(COALESCE(p1.dep_all_cohort, 0), 0)) AS DECIMAL(10,2)) AS dep_all_Percent,

    -- GGR Current Cohort
    COALESCE(p2.GGR_current_cohort, 0) AS GGR_current_cohort,
    CAST(((COALESCE(p2.GGR_current_cohort, 0) - COALESCE(p1.GGR_current_cohort, 0)) * 100.0 / NULLIF(COALESCE(p1.GGR_current_cohort, 0), 0)) AS DECIMAL(10,2)) AS GGR_current_Percent,
    
    -- GGR All Cohort
    COALESCE(p2.GGR_all_cohort, 0) AS GGR_all_cohort,
    CAST(((COALESCE(p2.GGR_all_cohort, 0) - COALESCE(p1.GGR_all_cohort, 0)) * 100.0 / NULLIF(COALESCE(p1.GGR_all_cohort, 0), 0)) AS DECIMAL(10,2)) AS GGR_all_Percent
    
FROM
    dataset_period p1
JOIN
    dataset_period p2 ON p1.periodo = 'P1' AND p2.periodo = 'P2';