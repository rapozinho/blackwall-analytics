-- Report Master / Casino: Turnover - Casino
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

SELECT
    SUM(Turnover) AS [Turnover - Casino]
FROM casino_agg_hourly WITH(NOLOCK)
WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive;
