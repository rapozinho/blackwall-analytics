-- Report Master / Sports: Gamblers (Daily AVG)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

SELECT AVG(daily_uap) AS [Gamblers (Daily AVG)]
FROM (
    SELECT CAST(date_agg AS DATE) AS date_dia, COUNT(DISTINCT user_id) AS daily_uap
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive
    GROUP BY CAST(date_agg AS DATE)
) AS daily_counts;
