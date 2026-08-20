
--======== CRM ==============

--Active Players
SELECT count(DISTINCT user_id) AS [Active Players]
FROM (
    SELECT user_id
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
    
    UNION ALL
    
    SELECT user_id
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
) AS todos_jogadores;



--Active Players %
WITH MesAnterior AS (
    SELECT COUNT(DISTINCT user_id) AS total
    FROM (
        SELECT user_id FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-05-01'
        UNION ALL
        SELECT user_id FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-05-01'
    ) AS ant
),
MesAtual AS (
    SELECT COUNT(DISTINCT user_id) AS total
    FROM (
        SELECT user_id FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
        UNION ALL
        SELECT user_id FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
    ) AS atu
)
SELECT 
    CONCAT(CAST(((a.total - p.total) * 100.0) / NULLIF(p.total, 0) AS DECIMAL(10,2)), '%') AS [Active Players Growth %]
FROM MesAnterior p
CROSS JOIN MesAtual a;



--Retention Rate
WITH MesAnterior AS (
    SELECT user_id FROM casino_agg_hourly WITH(NOLOCK) 
    WHERE date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-05-01'
    UNION
    SELECT user_id FROM sports_agg_hourly WITH(NOLOCK) 
    WHERE date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-05-01'
),
MesAtual AS (
    SELECT user_id FROM casino_agg_hourly WITH(NOLOCK) 
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
    UNION
    SELECT user_id FROM sports_agg_hourly WITH(NOLOCK) 
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
),
FtdMesAtual AS (
    SELECT user_id FROM ftd_agg WITH(NOLOCK)
    WHERE ftd_date >= '2026-05-01' AND ftd_date < '2026-06-01'
)
SELECT 
    CONCAT(CAST((COUNT(DISTINCT a.user_id) * 100.0) / NULLIF(COUNT(DISTINCT p.user_id), 0) AS DECIMAL(10,2)), '%') AS [Retention Rate]
FROM MesAnterior p
LEFT JOIN MesAtual a ON p.user_id = a.user_id 
    AND a.user_id NOT IN (SELECT user_id FROM FtdMesAtual);



--Retention Rate %
WITH UsuariosAtivos AS (
    SELECT 
        user_id, 
        MAX(CASE WHEN date_agg >= DATEADD(month, -2, '2026-05-01') AND date_agg < DATEADD(month, -1, '2026-05-01') THEN 1 ELSE 0 END) AS mes_menos_2,
        MAX(CASE WHEN date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-05-01' THEN 1 ELSE 0 END) AS mes_anterior,
        MAX(CASE WHEN date_agg >= '2026-05-01' AND date_agg < '2026-06-01' THEN 1 ELSE 0 END) AS mes_atual
    FROM (
        SELECT user_id, date_agg FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_agg >= DATEADD(month, -2, '2026-05-01') AND date_agg < '2026-06-01'
        UNION ALL
        SELECT user_id, date_agg FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_agg >= DATEADD(month, -2, '2026-05-01') AND date_agg < '2026-06-01'
    ) base
    GROUP BY user_id
),
FTDs AS (
    SELECT 
        user_id,
        MAX(CASE WHEN ftd_date >= DATEADD(month, -1, '2026-05-01') AND ftd_date < '2026-05-01' THEN 1 ELSE 0 END) AS ftd_anterior,
        MAX(CASE WHEN ftd_date >= '2026-05-01' AND ftd_date < '2026-06-01' THEN 1 ELSE 0 END) AS ftd_atual
    FROM ftd_agg WITH(NOLOCK)
    WHERE ftd_date >= DATEADD(month, -1, '2026-05-01') AND ftd_date < '2026-06-01'
    GROUP BY user_id
)
SELECT 
    CONCAT(CAST(
        (SUM(CASE WHEN u.mes_anterior = 1 AND u.mes_atual = 1 AND ISNULL(f.ftd_atual, 0) = 0 THEN 1.0 ELSE 0 END) * 100.0 / NULLIF(SUM(CASE WHEN u.mes_anterior = 1 THEN 1.0 ELSE 0 END), 0))
        -
        (SUM(CASE WHEN u.mes_menos_2 = 1 AND u.mes_anterior = 1 AND ISNULL(f.ftd_anterior, 0) = 0 THEN 1.0 ELSE 0 END) * 100.0 / NULLIF(SUM(CASE WHEN u.mes_menos_2 = 1 THEN 1.0 ELSE 0 END), 0))
    AS DECIMAL(10,2)), '%') AS [Diferenca %]
FROM UsuariosAtivos u
LEFT JOIN FTDs f ON u.user_id = f.user_id;



--Reativations
WITH MesAtual AS (
    SELECT user_id FROM casino_agg_hourly WITH(NOLOCK) 
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
    UNION
    SELECT user_id FROM sports_agg_hourly WITH(NOLOCK) 
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
),
MesAnterior AS (
    SELECT user_id FROM casino_agg_hourly WITH(NOLOCK) 
    WHERE date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-05-01'
    UNION
    SELECT user_id FROM sports_agg_hourly WITH(NOLOCK) 
    WHERE date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-05-01'
),
FtdMesAtual AS (
    SELECT user_id FROM ftd_agg WITH(NOLOCK)
    WHERE ftd_date >= '2026-05-01' AND ftd_date < '2026-06-01'
)
SELECT 
    COUNT(DISTINCT a.user_id) AS Reativations
FROM MesAtual a
WHERE NOT EXISTS (SELECT 1 FROM MesAnterior ant WHERE ant.user_id = a.user_id)
  AND NOT EXISTS (SELECT 1 FROM FtdMesAtual ftd WHERE ftd.user_id = a.user_id);



--Reativations %
WITH UsuariosAtivos AS (
    SELECT 
        user_id, 
        MAX(CASE WHEN date_agg >= DATEADD(month, -2, '2026-05-01') AND date_agg < DATEADD(month, -1, '2026-05-01') THEN 1 ELSE 0 END) AS mes_menos_2,
        MAX(CASE WHEN date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-05-01' THEN 1 ELSE 0 END) AS mes_anterior,
        MAX(CASE WHEN date_agg >= '2026-05-01' AND date_agg < '2026-06-01' THEN 1 ELSE 0 END) AS mes_atual
    FROM (
        SELECT user_id, date_agg FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_agg >= DATEADD(month, -2, '2026-05-01') AND date_agg < '2026-06-01'
        UNION ALL
        SELECT user_id, date_agg FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_agg >= DATEADD(month, -2, '2026-05-01') AND date_agg < '2026-06-01'
    ) base
    GROUP BY user_id
),
FTDs AS (
    SELECT 
        user_id,
        MAX(CASE WHEN ftd_date >= DATEADD(month, -1, '2026-05-01') AND ftd_date < '2026-05-01' THEN 1 ELSE 0 END) AS ftd_anterior,
        MAX(CASE WHEN ftd_date >= '2026-05-01' AND ftd_date < '2026-06-01' THEN 1 ELSE 0 END) AS ftd_atual
    FROM ftd_agg WITH(NOLOCK)
    WHERE ftd_date >= DATEADD(month, -1, '2026-05-01') AND ftd_date < '2026-06-01'
    GROUP BY user_id
)
SELECT 
    CONCAT(CAST(
        (
            SUM(CASE WHEN u.mes_atual = 1 AND u.mes_anterior = 0 AND ISNULL(f.ftd_atual, 0) = 0 THEN 1.0 ELSE 0 END) - 
            SUM(CASE WHEN u.mes_anterior = 1 AND u.mes_menos_2 = 0 AND ISNULL(f.ftd_anterior, 0) = 0 THEN 1.0 ELSE 0 END)
        ) * 100.0 / 
        NULLIF(SUM(CASE WHEN u.mes_anterior = 1 AND u.mes_menos_2 = 0 AND ISNULL(f.ftd_anterior, 0) = 0 THEN 1.0 ELSE 0 END), 0) 
    AS DECIMAL(10,2)), '%') AS [Diferenca %]
FROM UsuariosAtivos u
LEFT JOIN FTDs f ON u.user_id = f.user_id;



--Churn
WITH UsuariosAtivos AS (
    SELECT 
        user_id, 
        MAX(CASE WHEN date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-05-01' THEN 1 ELSE 0 END) AS mes_anterior,
        MAX(CASE WHEN date_agg >= '2026-05-01' AND date_agg < '2026-06-01' THEN 1 ELSE 0 END) AS mes_atual
    FROM (
        SELECT user_id, date_agg FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-06-01'
        UNION ALL
        SELECT user_id, date_agg FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-06-01'
    ) base
    GROUP BY user_id
),
FTDs AS (
    SELECT 
        user_id,
        MAX(CASE WHEN ftd_date >= '2026-05-01' AND ftd_date < '2026-06-01' THEN 1 ELSE 0 END) AS ftd_atual
    FROM ftd_agg WITH(NOLOCK)
    WHERE ftd_date >= '2026-05-01' AND ftd_date < '2026-06-01'
    GROUP BY user_id
)
SELECT 
    SUM(CASE WHEN u.mes_anterior = 1 AND (u.mes_atual = 0 OR ISNULL(f.ftd_atual, 0) = 1) THEN 1 ELSE 0 END) AS [Churn]
FROM UsuariosAtivos u
LEFT JOIN FTDs f ON u.user_id = f.user_id;



--Generosity



--Generosity %



--Bonus



--GGR
WITH Casino AS (
    SELECT SUM(ggr) AS casino_ggr
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-05-29'
),
Sports AS (
    SELECT SUM(ggr) AS sports_ggr
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-05-29'
)
SELECT 
    ISNULL(c.casino_ggr, 0) + ISNULL(s.sports_ggr, 0) AS GGR
FROM Casino c
CROSS JOIN Sports s;




--Gamblers & NGR
WITH PlayerStats AS (
    SELECT 
        user_id,
        SUM(CASE WHEN date_agg >= '2026-05-01' AND date_agg < '2026-06-01' THEN ISNULL(ggr, 0) ELSE 0 END) AS ggr_periodo,
        SUM(CASE WHEN date_agg >= '2026-05-01' AND date_agg < '2026-06-01' THEN ISNULL(ngr, 0) ELSE 0 END) AS ngr_periodo,
        SUM(ISNULL(turnover, 0)) AS turnover_lifetime
    FROM (
        SELECT user_id, date_agg, ggr, turnover, ngr FROM casino_agg_hourly WITH(NOLOCK)
        UNION ALL
        SELECT user_id, date_agg, ggr, turnover, ngr FROM sports_agg_hourly WITH(NOLOCK)
    ) base
    GROUP BY user_id
    HAVING MAX(CASE WHEN date_agg >= '2026-05-01' AND date_agg < '2026-06-01' THEN 1 ELSE 0 END) = 1
)
SELECT 
    SUM(CASE WHEN ggr_periodo < 0 THEN 1 ELSE 0 END) AS [Negative],
    SUM(CASE WHEN ggr_periodo >= 0 AND turnover_lifetime > 97671.00 THEN 1 ELSE 0 END) AS [Vip],
    SUM(CASE WHEN ggr_periodo >= 0 AND turnover_lifetime <= 97671.00 THEN 1 ELSE 0 END) AS [Core],
    SUM(CASE WHEN ggr_periodo < 0 THEN ngr_periodo ELSE 0 END) AS [NGR Negative],
    SUM(CASE WHEN ggr_periodo >= 0 AND turnover_lifetime > 97671.00 THEN ngr_periodo ELSE 0 END) AS [NGR Vip],
    SUM(CASE WHEN ggr_periodo >= 0 AND turnover_lifetime <= 97671.00 THEN ngr_periodo ELSE 0 END) AS [NGR Core]
FROM PlayerStats;





