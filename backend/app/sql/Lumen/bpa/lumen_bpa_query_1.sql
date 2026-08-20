DECLARE @data_ini1 DATE = '{start1}';
DECLARE @data_fim1 DATE = '{end1}';

DECLARE @data_ini2 DATE = '{start2}';
DECLARE @data_fim2 DATE = '{end2}';

DECLARE @data_fim_exclusive1 DATE = DATEADD(day, 1, @data_fim1);
DECLARE @data_fim_exclusive2 DATE = DATEADD(day, 1, @data_fim2);

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
ValidAcquisitions AS (
    SELECT DISTINCT acq.user_id
    FROM acquisitions_agg acq WITH(NOLOCK)
    LEFT JOIN manager_lumen_by_username mb ON acq.affiliate_name = mb.username
    WHERE CASE
        WHEN acq.acquisition_channel = 'Others' THEN 'Organic'
        WHEN acq.affiliate_name = 'GoogleAds' THEN 'GoogleAds'
        WHEN acq.affiliate_name = 'TaboolaAds' THEN 'TaboolaAds'
        WHEN acq.affiliate_name = 'MetaAds' THEN 'MetaAds'
        WHEN acq.affiliate_name = 'ScoreWireAds' THEN 'ScoreWireAds'
        WHEN acq.affiliate_name LIKE '%CriteoAds%' THEN 'CriteoAds'
        ELSE mb.affiliate_manager
    END IS NOT NULL
),
user_ggr_1 AS (
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
         INNER JOIN ValidAcquisitions v ON ftd.user_id = v.user_id
         WHERE ftd.ftd_date >= @data_ini1 AND ftd.ftd_date < @data_fim_exclusive1) AS FTD_QTD,
         
        (SELECT SUM(g.GGR_Total)
         FROM user_ggr_1 g
         INNER JOIN ValidAcquisitions v ON g.User_Id = v.user_id
         INNER JOIN ftd_agg f ON f.User_Id = v.user_id
         WHERE f.FTD_Date >= @data_ini1 AND f.FTD_Date < @data_fim_exclusive1) AS GGR_current_cohort,
         
        (SELECT SUM(dep.Deposits_Amount)
         FROM payments_agg_hourly dep WITH(NOLOCK)
         INNER JOIN ValidAcquisitions v ON dep.User_Id = v.user_id
         INNER JOIN ftd_agg f ON f.User_Id = v.user_id
         WHERE dep.Date_Agg >= @data_ini1 AND dep.Date_Agg < @data_fim_exclusive1
           AND f.FTD_Date >= @data_ini1 AND f.FTD_Date < @data_fim_exclusive1
           AND dep.Status = 'Completed') AS dep_current_cohort,
           
        (SELECT SUM(GGR_Total)
         FROM user_ggr_1 g
         INNER JOIN ValidAcquisitions v ON g.User_Id = v.user_id) AS GGR_all_cohort,
         
        (SELECT SUM(dep.Deposits_Amount)
         FROM payments_agg_hourly dep WITH(NOLOCK)
         INNER JOIN ValidAcquisitions v ON dep.User_Id = v.user_id
         WHERE dep.Date_Agg >= @data_ini1 AND dep.Date_Agg < @data_fim_exclusive1
           AND dep.status = 'Completed') AS dep_all_cohort
           
    UNION ALL
    
    SELECT 'P2',
        (SELECT COUNT(DISTINCT ftd.user_id)
         FROM ftd_agg ftd WITH(NOLOCK)
         INNER JOIN ValidAcquisitions v ON ftd.user_id = v.user_id
         WHERE ftd.ftd_date >= @data_ini2 AND ftd.ftd_date < @data_fim_exclusive2),
         
        (SELECT SUM(g.GGR_Total)
         FROM user_ggr_2 g
         INNER JOIN ValidAcquisitions v ON g.User_Id = v.user_id
         INNER JOIN ftd_agg f ON f.User_Id = v.user_id
         WHERE f.FTD_Date >= @data_ini2 AND f.FTD_Date < @data_fim_exclusive2),
         
        (SELECT SUM(dep.Deposits_Amount)
         FROM payments_agg_hourly dep WITH(NOLOCK)
         INNER JOIN ValidAcquisitions v ON dep.User_Id = v.user_id
         INNER JOIN ftd_agg f ON f.User_Id = v.user_id
         WHERE dep.Date_Agg >= @data_ini2 AND dep.Date_Agg < @data_fim_exclusive2
           AND f.FTD_Date >= @data_ini2 AND f.FTD_Date < @data_fim_exclusive2
           AND dep.status = 'Completed'),
           
        (SELECT SUM(GGR_Total)
         FROM user_ggr_2 g
         INNER JOIN ValidAcquisitions v ON g.User_Id = v.user_id),
         
        (SELECT SUM(dep.Deposits_Amount)
         FROM payments_agg_hourly dep WITH(NOLOCK)
         INNER JOIN ValidAcquisitions v ON dep.User_Id = v.user_id
         WHERE dep.Date_Agg >= @data_ini2 AND dep.Date_Agg < @data_fim_exclusive2
           AND dep.status = 'Completed')
)
SELECT
    'Grand Total' AS Source,
    COALESCE(p2.FTD_QTD, 0) AS FTD_QTD,
    CAST((COALESCE(p2.FTD_QTD, 0) - COALESCE(p1.FTD_QTD, 0)) * 100.0 / NULLIF(COALESCE(p1.FTD_QTD, 0), 0) AS DECIMAL(18,2)) AS FTD_Percent, 
    
    COALESCE(p2.dep_current_cohort, 0) AS dep_current_cohort,    
    CAST((COALESCE(p2.dep_current_cohort, 0) - COALESCE(p1.dep_current_cohort, 0)) * 100.0 / NULLIF(COALESCE(p1.dep_current_cohort, 0), 0) AS DECIMAL(18,2)) AS dep_current_Percent,
    
    COALESCE(p2.dep_all_cohort, 0) AS dep_all_cohort,
    CAST((COALESCE(p2.dep_all_cohort, 0) - COALESCE(p1.dep_all_cohort, 0)) * 100.0 / NULLIF(COALESCE(p1.dep_all_cohort, 0), 0) AS DECIMAL(18,2)) AS dep_all_Percent,
    
    COALESCE(p2.GGR_current_cohort, 0) AS GGR_current_cohort,
    CAST((COALESCE(p2.GGR_current_cohort, 0) - COALESCE(p1.GGR_current_cohort, 0)) * 100.0 / NULLIF(COALESCE(p1.GGR_current_cohort, 0), 0) AS DECIMAL(18,2)) AS GGR_current_Percent,
    
    COALESCE(p2.GGR_all_cohort, 0) AS GGR_all_cohort,
    CAST((COALESCE(p2.GGR_all_cohort, 0) - COALESCE(p1.GGR_all_cohort, 0)) * 100.0 / NULLIF(COALESCE(p1.GGR_all_cohort, 0), 0) AS DECIMAL(18,2)) AS GGR_all_Percent
    
FROM dataset_period p1
JOIN dataset_period p2 ON p1.periodo = 'P1' AND p2.periodo = 'P2';