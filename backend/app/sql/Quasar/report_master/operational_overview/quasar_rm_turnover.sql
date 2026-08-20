-- Report Master / Operational Overview: Turnover / Turnover - Casino / Turnover - Sports
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH Casino AS (
    SELECT SUM(Turnover) AS casino_turnover
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
),
Sports AS (
    SELECT SUM(Turnover) AS sports_turnover
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
)
SELECT
    c.casino_turnover,
    s.sports_turnover,
    ISNULL(c.casino_turnover, 0) + ISNULL(s.sports_turnover, 0) AS total_turnover
FROM Casino c
CROSS JOIN Sports s;
