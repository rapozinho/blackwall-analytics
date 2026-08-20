-- Report Master / Sports: AVG Bet - Sports (Amount)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

SELECT
    (SUM(Turnover)) / (SUM(Bet_count)) as [AVG Bet - Sports (Amount)]
FROM sports_agg_hourly WITH(NOLOCK)
WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive;
