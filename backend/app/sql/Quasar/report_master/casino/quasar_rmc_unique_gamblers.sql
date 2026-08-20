-- Report Master / Casino: Unique Gamblers
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

SELECT
    COUNT(DISTINCT user_id) AS [Unique Gamblers]
FROM casino_agg_hourly WITH(NOLOCK)
WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive;
