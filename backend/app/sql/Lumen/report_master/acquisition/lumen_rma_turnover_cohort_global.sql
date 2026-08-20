-- Report Master / Acquisition - All: Turnover Cohort (Global)
-- Global = sem filtro de manager (todos os usuarios adquiridos que fizeram FTD no periodo).
-- Lumen nao possui affiliates_agg; o LEFT JOIN decorativo da Quasar foi removido (nao filtrava nada).
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH Casino AS (
    SELECT SUM(c.turnover) AS casino_turnover
    FROM casino_agg_hourly c WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = c.user_id
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = c.user_id
    WHERE c.date_time >= @data_ini AND c.date_time < @data_fim_exclusive
    AND f.FTD_Date >= @data_ini AND f.FTD_Date < @data_fim_exclusive
),
Sports AS (
    SELECT SUM(s.turnover) AS sports_turnover
    FROM sports_agg_hourly s WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = s.user_id
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = s.user_id
    WHERE s.date_time >= @data_ini AND s.date_time < @data_fim_exclusive
    AND f.FTD_Date >= @data_ini AND f.FTD_Date < @data_fim_exclusive
)
SELECT
    ISNULL(c.casino_turnover, 0) + ISNULL(s.sports_turnover, 0) AS [Turnover Cohort (Global)]
FROM Casino c
CROSS JOIN Sports s;
