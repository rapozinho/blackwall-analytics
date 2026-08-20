DECLARE @data_ini1 DATE = '{start1}';
DECLARE @data_fim1 DATE = '{end1}';

DECLARE @data_ini2 DATE = '{start2}';
DECLARE @data_fim2 DATE = '{end2}';

DECLARE @data_fim_exclusive1 DATE = DATEADD(day, 1, @data_fim1);
DECLARE @data_fim_exclusive2 DATE = DATEADD(day, 1, @data_fim2);

WITH user_ggr_1 AS (
    SELECT c.User_Id, SUM(c.GGR) AS GGR_Total
    FROM casino_agg_hourly c WITH(NOLOCK)
    WHERE c.Date_Agg >= @data_ini1 AND c.Date_Agg < @data_fim_exclusive1
    GROUP BY c.User_Id
    UNION ALL
    SELECT s.User_Id, SUM(s.GGR) AS GGR_Total
    FROM sports_agg_hourly s WITH(NOLOCK)
    WHERE s.Date_Agg >= @data_ini1 AND s.Date_Agg < @data_fim_exclusive1
    GROUP BY s.User_Id
),
user_ggr_2 AS (
    SELECT c.User_Id, SUM(c.GGR) AS GGR_Total
    FROM casino_agg_hourly c WITH(NOLOCK)
    WHERE c.Date_Agg >= @data_ini2 AND c.Date_Agg < @data_fim_exclusive2
    GROUP BY c.User_Id
    UNION ALL
    SELECT s.User_Id, SUM(s.GGR) AS GGR_Total
    FROM sports_agg_hourly s WITH(NOLOCK)
    WHERE s.Date_Agg >= @data_ini2 AND s.Date_Agg < @data_fim_exclusive2
    GROUP BY s.User_Id
),
dataset_period AS (
    SELECT 'P1' AS periodo,
           (SELECT COUNT(DISTINCT ftd.user_id)
            FROM ftd_agg ftd WITH(NOLOCK)
            INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
            WHERE ftd.ftd_date >= @data_ini1 AND ftd.ftd_date < @data_fim_exclusive1
              AND acq.acquisition_channel IN ('organic', 'Default', 'Quasarbet')) AS FTD_QTD,
           (SELECT SUM(cs.GGR_Total)
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN user_ggr_1 cs ON cs.User_Id = acq.User_Id
            INNER JOIN ftd_agg f ON f.User_Id = acq.User_Id
            WHERE f.FTD_Date >= @data_ini1 AND f.FTD_Date < @data_fim_exclusive1
              AND acq.acquisition_channel IN ('organic', 'Default', 'Quasarbet')) AS GGR_current_cohort,
           (SELECT SUM(dep.Deposits_Amount)
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN payments_agg_hourly dep ON dep.User_Id = acq.User_Id
            INNER JOIN ftd_agg f ON f.User_Id = acq.User_Id
            WHERE dep.Date_Agg >= @data_ini1 AND dep.Date_Agg < @data_fim_exclusive1
            AND dep.status = 'Completed'
              AND f.FTD_Date >= @data_ini1 AND f.FTD_Date < @data_fim_exclusive1
              AND acq.acquisition_channel IN ('organic', 'Default', 'Quasarbet')) AS dep_current_cohort,
           (SELECT SUM(cs.GGR_Total)
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN user_ggr_1 cs ON cs.User_Id = acq.User_Id
            WHERE acq.acquisition_channel IN ('organic', 'Default', 'Quasarbet')) AS GGR_all_cohort,
           (SELECT SUM(dep.Deposits_Amount)
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN payments_agg_hourly dep ON dep.User_Id = acq.User_Id
            WHERE dep.Date_Agg >= @data_ini1 AND dep.Date_Agg < @data_fim_exclusive1
            AND dep.status = 'Completed'
              AND acq.acquisition_channel IN ('organic', 'Default', 'Quasarbet')) AS dep_all_cohort
    UNION ALL
    SELECT 'P2',
           (SELECT COUNT(DISTINCT ftd.user_id)
            FROM ftd_agg ftd WITH(NOLOCK)
            INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
            WHERE ftd.ftd_date >= @data_ini2 AND ftd.ftd_date < @data_fim_exclusive2
              AND acq.acquisition_channel IN ('organic', 'Default', 'Quasarbet')),
           (SELECT SUM(cs.GGR_Total)
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN user_ggr_2 cs ON cs.User_Id = acq.User_Id
            INNER JOIN ftd_agg f ON f.User_Id = acq.User_Id
            WHERE f.FTD_Date >= @data_ini2 AND f.FTD_Date < @data_fim_exclusive2
              AND acq.acquisition_channel IN ('organic', 'Default', 'Quasarbet')),
           (SELECT SUM(dep.Deposits_Amount)
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN payments_agg_hourly dep ON dep.User_Id = acq.User_Id
            INNER JOIN ftd_agg f ON f.User_Id = acq.User_Id
            WHERE dep.Date_Agg >= @data_ini2 AND dep.Date_Agg < @data_fim_exclusive2
              AND dep.status = 'Completed'
              AND f.FTD_Date >= @data_ini2 AND f.FTD_Date < @data_fim_exclusive2
              AND acq.acquisition_channel IN ('organic', 'Default', 'Quasarbet')),
           (SELECT SUM(cs.GGR_Total)
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN user_ggr_2 cs ON cs.User_Id = acq.User_Id
            WHERE acq.acquisition_channel IN ('organic', 'Default', 'Quasarbet')),
           (SELECT SUM(dep.Deposits_Amount)
            FROM acquisitions_agg acq WITH(NOLOCK)
            INNER JOIN payments_agg_hourly dep ON dep.User_Id = acq.User_Id
            WHERE dep.Date_Agg >= @data_ini2 AND dep.Date_Agg < @data_fim_exclusive2
              AND dep.status = 'Completed'
              AND acq.acquisition_channel IN ('organic', 'Default', 'Quasarbet'))
)
SELECT
    'Organic',
    p2.FTD_QTD,
    CAST((p2.FTD_QTD - p1.FTD_QTD) * 100.0 / NULLIF(p1.FTD_QTD, 0) AS DECIMAL(10,2)) AS FTD_Percent,

    p2.dep_current_cohort,
    CAST((p2.dep_current_cohort - p1.dep_current_cohort) * 100.0 / NULLIF(p1.dep_current_cohort, 0) AS DECIMAL(10,2)) AS dep_current_Percent,

    p2.dep_all_cohort,
    CAST((p2.dep_all_cohort - p1.dep_all_cohort) * 100.0 / NULLIF(p1.dep_all_cohort, 0) AS DECIMAL(10,2)) AS dep_all_Percent,

    p2.GGR_current_cohort,
    CAST((p2.GGR_current_cohort - p1.GGR_current_cohort) * 100.0 / NULLIF(p1.GGR_current_cohort, 0) AS DECIMAL(10,2)) AS GGR_current_Percent,
    
    p2.GGR_all_cohort,
    CAST((p2.GGR_all_cohort - p1.GGR_all_cohort) * 100.0 / NULLIF(p1.GGR_all_cohort, 0) AS DECIMAL(10,2)) AS GGR_all_Percent
    
FROM dataset_period p1
JOIN dataset_period p2 ON p1.periodo = 'P1' AND p2.periodo = 'P2';