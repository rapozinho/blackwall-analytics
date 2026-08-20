-- Report Master / Casino: AVG Bet
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

SELECT
    (SUM(Turnover)) / (SUM(Bet_count)) as [Avg bet]
FROM casino_agg_hourly WITH(NOLOCK)
WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive;
