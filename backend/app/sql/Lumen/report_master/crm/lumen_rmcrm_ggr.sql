-- Report Master / CRM: GGR (total casino + sports)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH Casino AS (
    SELECT SUM(ggr) AS casino_ggr
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
),
Sports AS (
    SELECT SUM(ggr) AS sports_ggr
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
)
SELECT
    ISNULL(c.casino_ggr, 0) + ISNULL(s.sports_ggr, 0) AS [GGR]
FROM Casino c
CROSS JOIN Sports s;
