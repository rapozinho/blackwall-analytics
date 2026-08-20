-- Report Master / CRM: Retention Rate % (diferença vs mês anterior, fração p/ formato 0,00%)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH UsuariosAtivos AS (
    SELECT
        user_id,
        MAX(CASE WHEN date_agg >= DATEADD(month, -2, @data_ini) AND date_agg < DATEADD(month, -1, @data_ini) THEN 1 ELSE 0 END) AS mes_menos_2,
        MAX(CASE WHEN date_agg >= DATEADD(month, -1, @data_ini) AND date_agg < @data_ini THEN 1 ELSE 0 END) AS mes_anterior,
        MAX(CASE WHEN date_agg >= @data_ini AND date_agg < @data_fim_exclusive THEN 1 ELSE 0 END) AS mes_atual
    FROM (
        SELECT user_id, date_agg FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_agg >= DATEADD(month, -2, @data_ini) AND date_agg < @data_fim_exclusive
        UNION ALL
        SELECT user_id, date_agg FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_agg >= DATEADD(month, -2, @data_ini) AND date_agg < @data_fim_exclusive
    ) base
    GROUP BY user_id
),
FTDs AS (
    SELECT
        user_id,
        MAX(CASE WHEN ftd_date >= DATEADD(month, -1, @data_ini) AND ftd_date < @data_ini THEN 1 ELSE 0 END) AS ftd_anterior,
        MAX(CASE WHEN ftd_date >= @data_ini AND ftd_date < @data_fim_exclusive THEN 1 ELSE 0 END) AS ftd_atual
    FROM ftd_agg WITH(NOLOCK)
    WHERE ftd_date >= DATEADD(month, -1, @data_ini) AND ftd_date < @data_fim_exclusive
    GROUP BY user_id
)
SELECT
    CAST(
        (SUM(CASE WHEN u.mes_anterior = 1 AND u.mes_atual = 1 AND ISNULL(f.ftd_atual, 0) = 0 THEN 1.0 ELSE 0 END) * 1.0 / NULLIF(SUM(CASE WHEN u.mes_anterior = 1 THEN 1.0 ELSE 0 END), 0))
        -
        (SUM(CASE WHEN u.mes_menos_2 = 1 AND u.mes_anterior = 1 AND ISNULL(f.ftd_anterior, 0) = 0 THEN 1.0 ELSE 0 END) * 1.0 / NULLIF(SUM(CASE WHEN u.mes_menos_2 = 1 THEN 1.0 ELSE 0 END), 0))
    AS DECIMAL(10,4)) AS [Retention Rate %]
FROM UsuariosAtivos u
LEFT JOIN FTDs f ON u.user_id = f.user_id;
