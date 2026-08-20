DECLARE @data_ini1 DATE = '{start1}';
DECLARE @data_fim1 DATE = '{end1}';

DECLARE @data_ini2 DATE = '{start2}';
DECLARE @data_fim2 DATE = '{end2}';

DECLARE @data_fim_exclusive1 DATE = DATEADD(day, 1, @data_fim1);
DECLARE @data_fim_exclusive2 DATE = DATEADD(day, 1, @data_fim2);

WITH user_ggr AS (
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
    SELECT
        'P1' AS periodo,
        ftd_counts.FTD_QTD,
        ggr_current.GGR_current_cohort,
        dep_current.dep_current_cohort,
        ggr_all.GGR_all_cohort,
        dep_all.dep_all_cohort
    FROM
        (
            SELECT COUNT(DISTINCT ftd.user_id) AS FTD_QTD
            FROM ftd_agg ftd WITH(NOLOCK)
            INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
            LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
            WHERE ftd.ftd_date >= @data_ini1 AND ftd.ftd_date < @data_fim_exclusive1
              AND aff.affiliate_manager = 'InfluenciadoresQuasar (446)'
        ) ftd_counts

    LEFT JOIN (
        SELECT CAST(SUM(cs.GGR_Total) AS DECIMAL(10,2)) AS GGR_current_cohort
        FROM acquisitions_agg r WITH(NOLOCK)
        LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = r.Affiliate_Id
        INNER JOIN user_ggr cs ON cs.User_Id = r.User_Id
        INNER JOIN ftd_agg f ON f.User_Id = r.User_Id AND f.FTD_Date >= @data_ini1 AND f.FTD_Date < @data_fim_exclusive1
        WHERE aff.affiliate_manager = 'InfluenciadoresQuasar (446)'
    ) ggr_current ON 1=1

    LEFT JOIN (
        SELECT CAST(SUM(dep.Deposits_Amount) AS DECIMAL(10,2)) AS dep_current_cohort
        FROM acquisitions_agg r WITH(NOLOCK)
        LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = r.Affiliate_Id
        INNER JOIN payments_agg_hourly dep ON dep.User_Id = r.User_Id
        INNER JOIN ftd_agg f ON f.User_Id = r.User_Id AND f.FTD_Date >= @data_ini1 AND f.FTD_Date < @data_fim_exclusive1
        WHERE dep.Date_Agg >= @data_ini1 AND dep.Date_Agg < @data_fim_exclusive1
          AND dep.status = 'Completed'
          AND aff.affiliate_manager = 'InfluenciadoresQuasar (446)'
    ) dep_current ON 1=1

    LEFT JOIN (
        SELECT CAST(SUM(cs.GGR_Total) AS DECIMAL(10,2)) AS GGR_all_cohort
        FROM acquisitions_agg r WITH(NOLOCK)
        LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = r.Affiliate_Id
        INNER JOIN user_ggr cs ON cs.User_Id = r.User_Id
        WHERE aff.affiliate_manager = 'InfluenciadoresQuasar (446)'
          AND cs.GGR_Total IS NOT NULL
    ) ggr_all ON 1=1

    LEFT JOIN (
        SELECT CAST(SUM(dep.Deposits_Amount) AS DECIMAL(10,2)) AS dep_all_cohort
        FROM acquisitions_agg r WITH(NOLOCK)
        LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = r.Affiliate_Id
        INNER JOIN payments_agg_hourly dep ON dep.User_Id = r.User_Id
        WHERE dep.Date_Agg >= @data_ini1 AND dep.Date_Agg < @data_fim_exclusive1
          AND dep.status = 'Completed'
          AND aff.affiliate_manager = 'InfluenciadoresQuasar (446)'
    ) dep_all ON 1=1

    UNION ALL

    SELECT
        'P2' AS periodo,
        ftd_counts.FTD_QTD,
        ggr_current.GGR_current_cohort,
        dep_current.dep_current_cohort,
        ggr_all.GGR_all_cohort,
        dep_all.dep_all_cohort
    FROM
        (
            SELECT COUNT(DISTINCT ftd.user_id) AS FTD_QTD
            FROM ftd_agg ftd WITH(NOLOCK)
            INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
            LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
            WHERE ftd.ftd_date >= @data_ini2 AND ftd.ftd_date < @data_fim_exclusive2
              AND aff.affiliate_manager = 'InfluenciadoresQuasar (446)'
        ) ftd_counts

    LEFT JOIN (
        SELECT CAST(SUM(cs.GGR_Total) AS DECIMAL(10,2)) AS GGR_current_cohort
        FROM acquisitions_agg r WITH(NOLOCK)
        LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = r.Affiliate_Id
        INNER JOIN user_ggr_2 cs ON cs.User_Id = r.User_Id
        INNER JOIN ftd_agg f ON f.User_Id = r.User_Id AND f.FTD_Date >= @data_ini2 AND f.FTD_Date < @data_fim_exclusive2
        WHERE aff.affiliate_manager = 'InfluenciadoresQuasar (446)'
    ) ggr_current ON 1=1

    LEFT JOIN (
        SELECT CAST(SUM(dep.Deposits_Amount) AS DECIMAL(10,2)) AS dep_current_cohort
        FROM acquisitions_agg r WITH(NOLOCK)
        LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = r.Affiliate_Id
        INNER JOIN payments_agg_hourly dep ON dep.User_Id = r.User_Id
        INNER JOIN ftd_agg f ON f.User_Id = r.User_Id AND f.FTD_Date >= @data_ini2 AND f.FTD_Date < @data_fim_exclusive2
        WHERE dep.Date_Agg >= @data_ini2 AND dep.Date_Agg < @data_fim_exclusive2
          AND dep.status = 'Completed'
          AND aff.affiliate_manager = 'InfluenciadoresQuasar (446)'
    ) dep_current ON 1=1

    LEFT JOIN (
        SELECT CAST(SUM(cs.GGR_Total) AS DECIMAL(10,2)) AS GGR_all_cohort
        FROM acquisitions_agg r WITH(NOLOCK)
        LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = r.Affiliate_Id
        INNER JOIN user_ggr_2 cs ON cs.User_Id = r.User_Id
        WHERE aff.affiliate_manager = 'InfluenciadoresQuasar (446)'
          AND cs.GGR_Total IS NOT NULL
    ) ggr_all ON 1=1

    LEFT JOIN (
        SELECT CAST(SUM(dep.Deposits_Amount) AS DECIMAL(10,2)) AS dep_all_cohort
        FROM acquisitions_agg r WITH(NOLOCK)
        LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = r.Affiliate_Id
        INNER JOIN payments_agg_hourly dep ON dep.User_Id = r.User_Id
        WHERE dep.Date_Agg >= @data_ini2 AND dep.Date_Agg < @data_fim_exclusive2
          AND dep.status = 'Completed'
          AND aff.affiliate_manager = 'InfluenciadoresQuasar (446)'
    ) dep_all ON 1=1
)

SELECT
   'Influencers',

    -- FTD
    p2.FTD_QTD AS FTD_QTD,
    CAST(((p2.FTD_QTD - p1.FTD_QTD) * 100.0 / NULLIF(p1.FTD_QTD, 0)) AS DECIMAL(10,2)) AS FTD_Percent,

    -- Deposits Current Cohort
    p2.dep_current_cohort AS dep_current_cohort,
    CAST(((p2.dep_current_cohort - p1.dep_current_cohort) * 100.0 / NULLIF(p1.dep_current_cohort, 0)) AS DECIMAL(10,2)) AS dep_current_Percent,

    -- Deposits All Cohort
    p2.dep_all_cohort AS dep_all_cohort,
    CAST(((p2.dep_all_cohort - p1.dep_all_cohort) * 100.0 / NULLIF(p1.dep_all_cohort, 0)) AS DECIMAL(10,2)) AS dep_all_Percent,

    -- GGR Current Cohort
    p2.GGR_current_cohort AS GGR_current_cohort,
    CAST(((p2.GGR_current_cohort - p1.GGR_current_cohort) * 100.0 / NULLIF(p1.GGR_current_cohort, 0)) AS DECIMAL(10,2)) AS GGR_current_Percent,

    -- GGR All Cohort
    p2.GGR_all_cohort AS GGR_all_cohort,
    CAST(((p2.GGR_all_cohort - p1.GGR_all_cohort) * 100.0 / NULLIF(p1.GGR_all_cohort, 0)) AS DECIMAL(10,2)) AS GGR_all_Percent

   

FROM
    dataset_period p1
JOIN
    dataset_period p2 ON p1.periodo = 'P1' AND p2.periodo = 'P2';