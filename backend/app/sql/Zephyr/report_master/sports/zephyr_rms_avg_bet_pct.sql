-- Report Master / Sports: AVG Bet - Sports (Amount) %
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH Anterior AS (
    SELECT AVG(Turnover) AS v
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= DATEADD(month, -1, @data_ini) AND date_time < @data_ini
),
Atual AS (
    SELECT AVG(Turnover) AS v
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
)
SELECT
    CAST((a.v - p.v) * 1.0 / NULLIF(p.v, 0) AS DECIMAL(18,6)) AS [AVG Bet - Sports (Amount) %]
FROM Anterior p
CROSS JOIN Atual a;
