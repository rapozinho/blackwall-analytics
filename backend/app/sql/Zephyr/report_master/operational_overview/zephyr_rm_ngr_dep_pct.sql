-- Report Master / Operational Overview: NGR/DEP % (variacao da taxa vs mes anterior, fracao)
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
Dep_MesAnterior AS (
    SELECT SUM(Deposits_Amount) AS dep_total
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= DATEADD(month, -1, @data_ini) AND date_agg < @data_ini
      AND Status = 'Completed'
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
Dep_MesAtual AS (
    SELECT SUM(Deposits_Amount) AS dep_total
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive
      AND Status = 'Completed'
),
Taxas AS (
    SELECT
        CAST(na.total * 1.0 / NULLIF(da.dep_total, 0) AS DECIMAL(18,6)) AS ngr_dep_atual,
        CAST(np.total * 1.0 / NULLIF(dp.dep_total, 0) AS DECIMAL(18,6)) AS ngr_dep_anterior
    FROM NGR_MesAtual na
    CROSS JOIN Dep_MesAtual da
    CROSS JOIN NGR_MesAnterior np
    CROSS JOIN Dep_MesAnterior dp
)
SELECT
    CAST((ngr_dep_atual - ngr_dep_anterior) * 1.0 / NULLIF(ngr_dep_anterior, 0) AS DECIMAL(18,6)) AS [NGR/DEP %]
FROM Taxas;
