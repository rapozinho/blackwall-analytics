-- Report Master / Operational Overview: Margin (GGR/Turnover, fracao p/ formato 0,00%)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH Total_GGR AS (
    SELECT SUM(ggr) AS total
    FROM (
        SELECT ggr FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
        UNION ALL
        SELECT ggr FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
    ) t
),
Total_Turnover AS (
    SELECT SUM(Turnover) AS total
    FROM (
        SELECT Turnover FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
        UNION ALL
        SELECT Turnover FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
    ) t
)
SELECT
    CAST(g.total * 1.0 / NULLIF(t.total, 0) AS DECIMAL(18,6)) AS [Margin]
FROM Total_GGR g
CROSS JOIN Total_Turnover t;
