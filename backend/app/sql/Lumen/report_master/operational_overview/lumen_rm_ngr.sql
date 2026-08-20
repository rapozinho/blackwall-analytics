-- Report Master / Operational Overview: NGR - Casino / NGR - Sports
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH casino AS (
    SELECT SUM(NGR) AS NGR_casino
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
), sports AS (
    SELECT SUM(NGR) AS NGR_sportsbook
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
)
SELECT
    c.NGR_casino,
    s.NGR_sportsbook
FROM casino c
CROSS JOIN sports s;
