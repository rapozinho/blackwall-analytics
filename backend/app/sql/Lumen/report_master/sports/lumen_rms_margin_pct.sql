-- Report Master / Sports: Margin - Sports %
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH Anterior AS (
    SELECT SUM(ggr) / NULLIF(SUM(Turnover), 0) AS v
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= DATEADD(month, -1, @data_ini) AND date_time < @data_ini
),
Atual AS (
    SELECT SUM(ggr) / NULLIF(SUM(Turnover), 0) AS v
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
)
SELECT
    CAST((a.v - p.v) * 1.0 / NULLIF(p.v, 0) AS DECIMAL(18,6)) AS [Margin - Sports %]
FROM Anterior p
CROSS JOIN Atual a;
