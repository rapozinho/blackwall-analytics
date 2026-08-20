-- Report Master / Acquisition - Quasar: Cohort horizontal de GGR (safra jan/25 -> periodo)
DECLARE @cohort_start DATE = '2025-01-01';        -- safra inicial fixa (jan/25)
DECLARE @activity_end DATE = '{end1}';            -- fim do periodo solicitado (inclusivo)
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @activity_end);

WITH CohortUsers AS (
    SELECT
        User_Id,
        DATEADD(month, DATEDIFF(month, 0, FTD_Date), 0) AS Cohort_Month
    FROM ftd_agg WITH(NOLOCK)
    WHERE FTD_Date >= @cohort_start AND FTD_Date < @data_fim_exclusive
    GROUP BY User_Id, DATEADD(month, DATEDIFF(month, 0, FTD_Date), 0)
),
Activity AS (
    SELECT
        cu.Cohort_Month,
        DATEADD(month, DATEDIFF(month, 0, a.Date_Agg), 0) AS Month_Ref,
        a.GGR
    FROM CohortUsers cu
    INNER JOIN casino_agg_hourly a WITH(NOLOCK) ON cu.User_Id = a.User_Id
    WHERE a.Date_Agg >= @cohort_start AND a.Date_Agg < @data_fim_exclusive

    UNION ALL

    SELECT
        cu.Cohort_Month,
        DATEADD(month, DATEDIFF(month, 0, s.Date_Agg), 0) AS Month_Ref,
        s.GGR
    FROM CohortUsers cu
    INNER JOIN sports_agg_hourly s WITH(NOLOCK) ON cu.User_Id = s.User_Id
    WHERE s.Date_Agg >= @cohort_start AND s.Date_Agg < @data_fim_exclusive
)
SELECT
    Cohort_Month,
    DATEDIFF(month, Cohort_Month, Month_Ref) AS Offset_Month,
    SUM(GGR) AS GGR
FROM Activity
WHERE Month_Ref >= Cohort_Month
GROUP BY Cohort_Month, DATEDIFF(month, Cohort_Month, Month_Ref)
ORDER BY Cohort_Month, Offset_Month;
