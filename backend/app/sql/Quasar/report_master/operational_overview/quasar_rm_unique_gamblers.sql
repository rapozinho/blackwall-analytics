-- Report Master: Unique Gamblers MTD
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

SELECT COUNT(DISTINCT user_id) AS UAP
FROM (
    SELECT user_id
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive

    UNION ALL

    SELECT user_id
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive
) AS combined_users;
