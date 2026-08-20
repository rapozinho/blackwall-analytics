-- Report Master / CRM: Reativations
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH MesAtual AS (
    SELECT user_id FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive
    UNION
    SELECT user_id FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive
),
MesAnterior AS (
    SELECT user_id FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= DATEADD(month, -1, @data_ini) AND date_agg < @data_ini
    UNION
    SELECT user_id FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= DATEADD(month, -1, @data_ini) AND date_agg < @data_ini
),
FtdMesAtual AS (
    SELECT user_id FROM ftd_agg WITH(NOLOCK)
    WHERE ftd_date >= @data_ini AND ftd_date < @data_fim_exclusive
)
SELECT
    COUNT(DISTINCT a.user_id) AS [Reactivations]
FROM MesAtual a
WHERE NOT EXISTS (SELECT 1 FROM MesAnterior ant WHERE ant.user_id = a.user_id)
  AND NOT EXISTS (SELECT 1 FROM FtdMesAtual ftd WHERE ftd.user_id = a.user_id);
