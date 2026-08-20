-- Report Master / Operational Overview: Margin % (variacao da margem vs mes anterior, fracao)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH GGR_MesAnterior AS (
    SELECT SUM(ggr) AS total
    FROM (
        SELECT ggr FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_time >= DATEADD(month, -1, @data_ini) AND date_time < @data_ini
        UNION ALL
        SELECT ggr FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_time >= DATEADD(month, -1, @data_ini) AND date_time < @data_ini
    ) t
),
Turnover_MesAnterior AS (
    SELECT SUM(Turnover) AS total
    FROM (
        SELECT Turnover FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_time >= DATEADD(month, -1, @data_ini) AND date_time < @data_ini
        UNION ALL
        SELECT Turnover FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_time >= DATEADD(month, -1, @data_ini) AND date_time < @data_ini
    ) t
),
GGR_MesAtual AS (
    SELECT SUM(ggr) AS total
    FROM (
        SELECT ggr FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
        UNION ALL
        SELECT ggr FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
    ) t
),
Turnover_MesAtual AS (
    SELECT SUM(Turnover) AS total
    FROM (
        SELECT Turnover FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
        UNION ALL
        SELECT Turnover FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
    ) t
),
Taxas AS (
    SELECT
        CAST(ga.total * 1.0 / NULLIF(ta.total, 0) AS DECIMAL(18,6)) AS margin_atual,
        CAST(gp.total * 1.0 / NULLIF(tp.total, 0) AS DECIMAL(18,6)) AS margin_anterior
    FROM GGR_MesAtual ga
    CROSS JOIN Turnover_MesAtual ta
    CROSS JOIN GGR_MesAnterior gp
    CROSS JOIN Turnover_MesAnterior tp
)
SELECT
    CAST((margin_atual - margin_anterior) * 1.0 / NULLIF(margin_anterior, 0) AS DECIMAL(18,6)) AS [Margin %]
FROM Taxas;
