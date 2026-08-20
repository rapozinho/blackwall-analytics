-- Report Master / Operational Overview: Hold (NGR/GGR) (fracao p/ formato 0,00%)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH Total_NGR AS (
    SELECT SUM(NGR) AS total
    FROM (
        SELECT NGR FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
        UNION ALL
        SELECT NGR FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
    ) t
),
Total_GGR AS (
    SELECT SUM(ggr) AS total
    FROM (
        SELECT ggr FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
        UNION ALL
        SELECT ggr FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
    ) t
)
SELECT
    CAST(n.total * 1.0 / NULLIF(g.total, 0) AS DECIMAL(18,6)) AS [Hold (NGR/GGR)]
FROM Total_NGR n
CROSS JOIN Total_GGR g;
