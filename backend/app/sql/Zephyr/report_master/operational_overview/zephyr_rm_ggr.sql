-- Report Master / Operational Overview: GGR / GGR - Casino / GGR - Sports
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH Casino AS (
    SELECT SUM(ggr) AS casino_ggr
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
),
Sports AS (
    SELECT SUM(ggr) AS sports_ggr
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
)
SELECT
    ISNULL(c.casino_ggr, 0) + ISNULL(s.sports_ggr, 0) AS ggr_total,
    c.casino_ggr,
    s.sports_ggr
FROM Casino c
CROSS JOIN Sports s;
