-- Report Master / Operational Overview: GGR % (crescimento vs mes anterior, fracao)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH MesAnterior AS (
    SELECT SUM(ggr) AS total
    FROM (
        SELECT ggr FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_time >= DATEADD(month, -1, @data_ini) AND date_time < @data_ini
        UNION ALL
        SELECT ggr FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_time >= DATEADD(month, -1, @data_ini) AND date_time < @data_ini
    ) t
),
MesAtual AS (
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
    CAST((a.total - p.total) * 1.0 / NULLIF(p.total, 0) AS DECIMAL(18,6)) AS [GGR %]
FROM MesAnterior p
CROSS JOIN MesAtual a;
