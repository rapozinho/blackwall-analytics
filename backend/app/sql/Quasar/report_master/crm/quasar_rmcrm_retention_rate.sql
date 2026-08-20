-- Report Master / CRM: Retention Rate (fração p/ formato 0,00%)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH MesAnterior AS (
    SELECT user_id FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= DATEADD(month, -1, @data_ini) AND date_agg < @data_ini
    UNION
    SELECT user_id FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= DATEADD(month, -1, @data_ini) AND date_agg < @data_ini
),
MesAtual AS (
    SELECT user_id FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive
    UNION
    SELECT user_id FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive
),
FtdMesAtual AS (
    SELECT user_id FROM ftd_agg WITH(NOLOCK)
    WHERE ftd_date >= @data_ini AND ftd_date < @data_fim_exclusive
)
SELECT
    CAST(COUNT(DISTINCT a.user_id) * 1.0 / NULLIF(COUNT(DISTINCT p.user_id), 0) AS DECIMAL(10,4)) AS [Retention Rate]
FROM MesAnterior p
LEFT JOIN MesAtual a ON p.user_id = a.user_id
    AND a.user_id NOT IN (SELECT user_id FROM FtdMesAtual);
