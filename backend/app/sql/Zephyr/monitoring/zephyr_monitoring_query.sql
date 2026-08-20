-- Monitoring - Zephyr (Batendo com o Bi!)
DECLARE @data_ini_mes1 DATE = '{start1}';
DECLARE @data_fim_mes1 DATE = '{end1}';

DECLARE @data_ini_mes2 DATE = '{start2}';
DECLARE @data_fim_mes2 DATE = '{end2}';

-- Variáveis internas para ajustar o intervalo (não precisa mexer aqui)
DECLARE @data_fim_exclusive1 DATE = DATEADD(day, 1, @data_fim_mes1);
DECLARE @data_fim_exclusive2 DATE = DATEADD(day, 1, @data_fim_mes2);

WITH UserAffiliateManager AS (
    SELECT DISTINCT
        ftd.user_id,
        CASE WHEN aff.Affiliate_Id IS NULL THEN 'Organic' ELSE aff.affiliate_manager END AS affiliate_manager,
        CASE
            WHEN ftd.ftd_date >= @data_ini_mes1 AND ftd.ftd_date < @data_fim_exclusive1 THEN 'mes1'
            WHEN ftd.ftd_date >= @data_ini_mes2 AND ftd.ftd_date < @data_fim_exclusive2 THEN 'mes2'
        END AS periodo
    FROM ftd_agg ftd WITH(NOLOCK)
    INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
    WHERE (
        (ftd.ftd_date >= @data_ini_mes1 AND ftd.ftd_date < @data_fim_exclusive1) OR
        (ftd.ftd_date >= @data_ini_mes2 AND ftd.ftd_date < @data_fim_exclusive2)
    )
    AND (aff.Affiliate_Id IS NULL OR aff.affiliate_manager IS NOT NULL)
),
UserGGR AS (
    SELECT
        c.User_Id,
        CASE
            WHEN c.Date_Agg >= @data_ini_mes1 AND c.Date_Agg < @data_fim_exclusive1 THEN 'mes1'
            WHEN c.Date_Agg >= @data_ini_mes2 AND c.Date_Agg < @data_fim_exclusive2 THEN 'mes2'
        END AS periodo,
        SUM(c.GGR) AS GGR_Total
    FROM casino_agg_hourly c WITH(NOLOCK)
    WHERE (c.Date_Agg >= @data_ini_mes1 AND c.Date_Agg < @data_fim_exclusive1)
       OR (c.Date_Agg >= @data_ini_mes2 AND c.Date_Agg < @data_fim_exclusive2)
    GROUP BY c.User_Id,
             CASE
                 WHEN c.Date_Agg >= @data_ini_mes1 AND c.Date_Agg < @data_fim_exclusive1 THEN 'mes1'
                 WHEN c.Date_Agg >= @data_ini_mes2 AND c.Date_Agg < @data_fim_exclusive2 THEN 'mes2'
             END
    UNION ALL
    SELECT
        s.User_Id,
        CASE
            WHEN s.Date_Agg >= @data_ini_mes1 AND s.Date_Agg < @data_fim_exclusive1 THEN 'mes1'
            WHEN s.Date_Agg >= @data_ini_mes2 AND s.Date_Agg < @data_fim_exclusive2 THEN 'mes2'
        END AS periodo,
        SUM(GGR) AS GGR_Total
    FROM sports_agg_hourly s WITH(NOLOCK)
    WHERE (s.Date_Agg >= @data_ini_mes1 AND s.Date_Agg < @data_fim_exclusive1)
       OR (s.Date_Agg >= @data_ini_mes2 AND s.Date_Agg < @data_fim_exclusive2)
    GROUP BY s.User_Id,
             CASE
                 WHEN s.Date_Agg >= @data_ini_mes1 AND s.Date_Agg < @data_fim_exclusive1 THEN 'mes1'
                 WHEN s.Date_Agg >= @data_ini_mes2 AND s.Date_Agg < @data_fim_exclusive2 THEN 'mes2'
             END
),
UserDeposits AS (
    SELECT
        dep.User_Id,
        CASE
            WHEN dep.Date_Agg >= @data_ini_mes1 AND dep.Date_Agg < @data_fim_exclusive1 THEN 'mes1'
            WHEN dep.Date_Agg >= @data_ini_mes2 AND dep.Date_Agg < @data_fim_exclusive2 THEN 'mes2'
        END AS periodo,
        SUM(dep.Deposits_Amount) AS Deposits_Total
    FROM payments_agg_hourly dep WITH(NOLOCK)
    WHERE (
        (dep.Date_Agg >= @data_ini_mes1 AND dep.Date_Agg < @data_fim_exclusive1) OR
        (dep.Date_Agg >= @data_ini_mes2 AND dep.Date_Agg < @data_fim_exclusive2)
    )
    AND dep.status = 'Completed'
    GROUP BY dep.User_Id,
             CASE
                 WHEN dep.Date_Agg >= @data_ini_mes1 AND dep.Date_Agg < @data_fim_exclusive1 THEN 'mes1'
                 WHEN dep.Date_Agg >= @data_ini_mes2 AND dep.Date_Agg < @data_fim_exclusive2 THEN 'mes2'
             END
),
ftd_counts_by_period AS (
    SELECT
        uam.affiliate_manager,
        uam.periodo,
        COUNT(DISTINCT uam.user_id) AS FTD_QTD
    FROM UserAffiliateManager uam
    GROUP BY uam.affiliate_manager, uam.periodo
),
ggr_avg_by_period AS (
    SELECT
        uam.affiliate_manager,
        uam.periodo,
        CAST(SUM(ug.GGR_Total) / NULLIF(COUNT(DISTINCT uam.User_Id), 0) AS DECIMAL(10, 2)) AS Avg_GGR
    FROM UserAffiliateManager uam
    INNER JOIN UserGGR ug ON uam.User_Id = ug.User_Id AND uam.periodo = ug.periodo
    GROUP BY uam.affiliate_manager, uam.periodo
),
ggr_total_by_period AS (
    SELECT
        uam.affiliate_manager,
        uam.periodo,
        SUM(ug.GGR_Total) AS Total_GGR
    FROM UserAffiliateManager uam
    INNER JOIN UserGGR ug ON uam.User_Id = ug.User_Id AND uam.periodo = ug.periodo
    GROUP BY uam.affiliate_manager, uam.periodo
),
dep_avg_by_period AS (
    SELECT
        uam.affiliate_manager,
        uam.periodo,
        CAST(SUM(ud.Deposits_Total) / NULLIF(COUNT(DISTINCT uam.User_Id), 0) AS DECIMAL(10, 2)) AS Avg_Dep
    FROM UserAffiliateManager uam
    INNER JOIN UserDeposits ud ON uam.User_Id = ud.User_Id AND uam.periodo = ud.periodo
    GROUP BY uam.affiliate_manager, uam.periodo
),
dep_total_by_period AS (
    SELECT
        uam.affiliate_manager,
        uam.periodo,
        SUM(ud.Deposits_Total) AS Total_Dep
    FROM UserAffiliateManager uam
    INNER JOIN UserDeposits ud ON uam.User_Id = ud.User_Id AND uam.periodo = ud.periodo
    GROUP BY uam.affiliate_manager, uam.periodo
),
-- Mapeia TODOS os jogadores (qualquer cohort/FTD) ao affiliate_manager
AllUserAffiliateManager AS (
    SELECT DISTINCT
        ftd.user_id,
        CASE WHEN aff.Affiliate_Id IS NULL THEN 'Organic' ELSE aff.affiliate_manager END AS affiliate_manager
    FROM ftd_agg ftd WITH(NOLOCK)
    INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
    WHERE aff.Affiliate_Id IS NULL OR aff.affiliate_manager IS NOT NULL
),
-- GGR do periodo 2 (mes2) somando TODO o cohort, nao so os FTDs do periodo
ggr_all_cohort_mes2 AS (
    SELECT
        aum.affiliate_manager,
        SUM(ug.GGR_Total) AS Total_GGR_All
    FROM AllUserAffiliateManager aum
    INNER JOIN UserGGR ug ON aum.user_id = ug.User_Id
    WHERE ug.periodo = 'mes2'
    GROUP BY aum.affiliate_manager
)
SELECT
    COALESCE(g_base.affiliate_manager, d1.affiliate_manager, f1.affiliate_manager, f2.affiliate_manager) AS Affiliate_Manager,
    --Mes1
    COALESCE(f1.FTD_QTD, 0) AS FTD_QTD_Mes1,
    COALESCE(gt1.Total_GGR, 0.00) AS Total_GGR_Mes1,
    COALESCE(g1.Avg_GGR, 0.00) AS Avg_GGR_Mes1,
    COALESCE(dt1.Total_Dep, 0.00) AS Total_Dep_Mes1,
    COALESCE(d1.Avg_Dep, 0.00) AS Avg_Dep_Mes1,

    --Mes2
    COALESCE(f2.FTD_QTD, 0) AS FTD_QTD_Mes2,
    CAST(CASE WHEN COALESCE(f1.FTD_QTD, 0) = 0 THEN 0 ELSE (CAST(COALESCE(f2.FTD_QTD, 0) AS FLOAT) - COALESCE(f1.FTD_QTD, 0)) * 100.0 / COALESCE(f1.FTD_QTD, 1) END AS DECIMAL(10,2)) AS [Var % FTDs],
    COALESCE(gt2.Total_GGR, 0.00) AS Total_GGR_Mes2,
    COALESCE(g2.Avg_GGR, 0.00) AS Avg_GGR_Mes2,
    CAST((CASE WHEN COALESCE(g1.Avg_GGR, 0.00) = 0 THEN 0.00 ELSE ((COALESCE(g2.Avg_GGR, 0.00) - COALESCE(g1.Avg_GGR, 0.00)) / NULLIF(COALESCE(g1.Avg_GGR, 0.00), 0)) * 100 END) AS DECIMAL(10,2)) AS [Var % GGR],
    COALESCE(dt2.Total_Dep, 0.00) AS Total_Dep_Mes2,
    COALESCE(d2.Avg_Dep, 0.00) AS Avg_Dep_Mes2,
    CAST((CASE WHEN COALESCE(d1.Avg_Dep, 0.00) = 0 THEN 0.00 ELSE ((COALESCE(d2.Avg_Dep, 0.00) - COALESCE(d1.Avg_Dep, 0.00)) / NULLIF(COALESCE(d1.Avg_Dep, 0.00), 0)) * 100 END) AS DECIMAL(10,2)) AS [Var % Dep],
    COALESCE(gac.Total_GGR_All, 0.00) AS [GGR All Cohort]

FROM (SELECT DISTINCT affiliate_manager FROM UserAffiliateManager) AS g_base
LEFT JOIN ggr_avg_by_period g1 ON g_base.affiliate_manager = g1.affiliate_manager AND g1.periodo = 'mes1'
LEFT JOIN ggr_total_by_period gt1 ON g_base.affiliate_manager = gt1.affiliate_manager AND gt1.periodo = 'mes1'
LEFT JOIN ggr_avg_by_period g2 ON g_base.affiliate_manager = g2.affiliate_manager AND g2.periodo = 'mes2'
LEFT JOIN ggr_total_by_period gt2 ON g_base.affiliate_manager = gt2.affiliate_manager AND gt2.periodo = 'mes2'
LEFT JOIN dep_avg_by_period d1 ON g_base.affiliate_manager = d1.affiliate_manager AND d1.periodo = 'mes1'
LEFT JOIN dep_total_by_period dt1 ON g_base.affiliate_manager = dt1.affiliate_manager AND dt1.periodo = 'mes1'
LEFT JOIN dep_avg_by_period d2 ON g_base.affiliate_manager = d2.affiliate_manager AND d2.periodo = 'mes2'
LEFT JOIN dep_total_by_period dt2 ON g_base.affiliate_manager = dt2.affiliate_manager AND dt2.periodo = 'mes2'
LEFT JOIN ftd_counts_by_period f1 ON g_base.affiliate_manager = f1.affiliate_manager AND f1.periodo = 'mes1'
LEFT JOIN ftd_counts_by_period f2 ON g_base.affiliate_manager = f2.affiliate_manager AND f2.periodo = 'mes2'
LEFT JOIN ggr_all_cohort_mes2 gac ON g_base.affiliate_manager = gac.affiliate_manager
ORDER BY Affiliate_Manager;
