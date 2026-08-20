-- Report Master: Gamblers (Daily AVG)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

SELECT AVG(daily_uap) AS media_diaria_uap
FROM (
    SELECT CAST(date_agg AS DATE) AS date_dia, COUNT(DISTINCT user_id) AS daily_uap
    FROM (
        SELECT date_agg, user_id
        FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive

        UNION ALL

        SELECT date_agg, user_id
        FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive
    ) AS combined_users
    GROUP BY CAST(date_agg AS DATE)
) AS daily_counts;
