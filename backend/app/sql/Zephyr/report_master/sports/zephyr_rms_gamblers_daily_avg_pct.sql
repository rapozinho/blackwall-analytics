-- Report Master / Sports: Gamblers (Daily AVG) %
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH Anterior AS (
    SELECT AVG(daily_uap) AS v
    FROM (
        SELECT CAST(date_agg AS DATE) AS d, COUNT(DISTINCT user_id) AS daily_uap
        FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_agg >= DATEADD(month, -1, @data_ini) AND date_agg < @data_ini
        GROUP BY CAST(date_agg AS DATE)
    ) t
),
Atual AS (
    SELECT AVG(daily_uap) AS v
    FROM (
        SELECT CAST(date_agg AS DATE) AS d, COUNT(DISTINCT user_id) AS daily_uap
        FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive
        GROUP BY CAST(date_agg AS DATE)
    ) t
)
SELECT
    CAST((a.v - p.v) * 1.0 / NULLIF(p.v, 0) AS DECIMAL(18,6)) AS [Gamblers (Daily AVG) %]
FROM Anterior p
CROSS JOIN Atual a;
