-- Report Master / Operational Overview: Hold (NGR/GGR) % (variacao do hold vs mes anterior, fracao)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH NGR_MesAnterior AS (
    SELECT SUM(NGR) AS total
    FROM (
        SELECT NGR FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_time >= DATEADD(month, -1, @data_ini) AND date_time < @data_ini
        UNION ALL
        SELECT NGR FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_time >= DATEADD(month, -1, @data_ini) AND date_time < @data_ini
    ) t
),
GGR_MesAnterior AS (
    SELECT SUM(ggr) AS total
    FROM (
        SELECT ggr FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_time >= DATEADD(month, -1, @data_ini) AND date_time < @data_ini
        UNION ALL
        SELECT ggr FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_time >= DATEADD(month, -1, @data_ini) AND date_time < @data_ini
    ) t
),
NGR_MesAtual AS (
    SELECT SUM(NGR) AS total
    FROM (
        SELECT NGR FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
        UNION ALL
        SELECT NGR FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
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
Taxas AS (
    SELECT
        CAST(na.total * 1.0 / NULLIF(ga.total, 0) AS DECIMAL(18,6)) AS hold_atual,
        CAST(np.total * 1.0 / NULLIF(gp.total, 0) AS DECIMAL(18,6)) AS hold_anterior
    FROM NGR_MesAtual na
    CROSS JOIN GGR_MesAtual ga
    CROSS JOIN NGR_MesAnterior np
    CROSS JOIN GGR_MesAnterior gp
)
SELECT
    CAST((hold_atual - hold_anterior) * 1.0 / NULLIF(hold_anterior, 0) AS DECIMAL(18,6)) AS [Hold (NGR/GGR) %]
FROM Taxas;
