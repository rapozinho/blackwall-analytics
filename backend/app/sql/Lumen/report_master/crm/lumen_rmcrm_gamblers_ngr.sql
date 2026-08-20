-- Report Master / CRM: Gamblers & NGR por segmento (Negative / Core / VIP)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH PlayerStats AS (
    SELECT
        user_id,
        SUM(CASE WHEN date_agg >= @data_ini AND date_agg < @data_fim_exclusive THEN ISNULL(ggr, 0) ELSE 0 END) AS ggr_periodo,
        SUM(CASE WHEN date_agg >= @data_ini AND date_agg < @data_fim_exclusive THEN ISNULL(ngr, 0) ELSE 0 END) AS ngr_periodo,
        SUM(ISNULL(turnover, 0)) AS turnover_lifetime
    FROM (
        SELECT user_id, date_agg, ggr, turnover, ngr FROM casino_agg_hourly WITH(NOLOCK)
        UNION ALL
        SELECT user_id, date_agg, ggr, turnover, ngr FROM sports_agg_hourly WITH(NOLOCK)
    ) base
    GROUP BY user_id
    HAVING MAX(CASE WHEN date_agg >= @data_ini AND date_agg < @data_fim_exclusive THEN 1 ELSE 0 END) = 1
)
SELECT
    SUM(CASE WHEN ggr_periodo < 0 THEN 1 ELSE 0 END) AS [Negative],
    SUM(CASE WHEN ggr_periodo >= 0 AND turnover_lifetime > 97671.00 THEN 1 ELSE 0 END) AS [Vip],
    SUM(CASE WHEN ggr_periodo >= 0 AND turnover_lifetime <= 97671.00 THEN 1 ELSE 0 END) AS [Core],
    SUM(CASE WHEN ggr_periodo < 0 THEN ngr_periodo ELSE 0 END) AS [NGR Negative],
    SUM(CASE WHEN ggr_periodo >= 0 AND turnover_lifetime > 97671.00 THEN ngr_periodo ELSE 0 END) AS [NGR Vip],
    SUM(CASE WHEN ggr_periodo >= 0 AND turnover_lifetime <= 97671.00 THEN ngr_periodo ELSE 0 END) AS [NGR Core]
FROM PlayerStats;
