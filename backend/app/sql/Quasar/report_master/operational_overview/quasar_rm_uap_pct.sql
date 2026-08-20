-- Report Master / Operational Overview: Unique Gamblers MTD % (crescimento vs mes anterior, fracao)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH MesAnterior AS (
    SELECT COUNT(DISTINCT user_id) AS total
    FROM (
        SELECT user_id FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_agg >= DATEADD(month, -1, @data_ini) AND date_agg < @data_ini
        UNION ALL
        SELECT user_id FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_agg >= DATEADD(month, -1, @data_ini) AND date_agg < @data_ini
    ) t
),
MesAtual AS (
    SELECT COUNT(DISTINCT user_id) AS total
    FROM (
        SELECT user_id FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive
        UNION ALL
        SELECT user_id FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive
    ) t
)
SELECT
    CAST((a.total - p.total) * 1.0 / NULLIF(p.total, 0) AS DECIMAL(18,6)) AS [Unique Gamblers MTD %]
FROM MesAnterior p
CROSS JOIN MesAtual a;
