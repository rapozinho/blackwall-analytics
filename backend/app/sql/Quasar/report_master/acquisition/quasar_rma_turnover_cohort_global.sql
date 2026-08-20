-- Report Master / Acquisition - All: Turnover Cohort (Global)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH casino AS (
    SELECT SUM(c.turnover) AS turnover_casino
    FROM casino_agg_hourly c WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = c.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = a.Affiliate_Id
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = c.user_id
    WHERE c.date_time >= @data_ini AND c.date_time < @data_fim_exclusive
    AND f.FTD_Date >= @data_ini AND f.FTD_Date < @data_fim_exclusive
), sports AS (
    SELECT SUM(s.turnover) AS turnover_sportsbook
    FROM sports_agg_hourly s WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = s.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = a.Affiliate_Id
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = s.user_id
    WHERE s.date_time >= @data_ini AND s.date_time < @data_fim_exclusive
    AND f.FTD_Date >= @data_ini AND f.FTD_Date < @data_fim_exclusive
)
SELECT
    ISNULL(c.turnover_casino, 0) + ISNULL(s.turnover_sportsbook, 0) AS [Turnover Cohort (Global)]
FROM casino c
CROSS JOIN sports s;
