--NGR / NGR - Casino / NGR - Sports
WITH casino AS (
    SELECT
        SUM(NGR) AS NGR_casino
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2023-05-01' AND date_time < '2026-05-29'
), sports AS (
    SELECT
        SUM(NGR) AS NGR_sportsbook
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2023-05-01' AND date_time < '2026-05-29'
)
SELECT
    c.NGR_casino,
    s.NGR_sportsbook
FROM casino c
CROSS JOIN sports s;



--NGR %
WITH NGR_MesAnterior AS (
    SELECT SUM(NGR) AS total_ngr
    FROM (
        SELECT NGR FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
        UNION ALL
        SELECT NGR FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
    ) t
),
NGR_MesAtual AS (
    SELECT SUM(NGR) AS total_ngr
    FROM (
        SELECT NGR FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
        UNION ALL
        SELECT NGR FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
    ) t
)
SELECT 
    CONCAT(CAST(((a.total_ngr - p.total_ngr) * 100.0) / NULLIF(p.total_ngr, 0) AS DECIMAL(10,2)), '%') AS [NGR %]
FROM NGR_MesAnterior p
CROSS JOIN NGR_MesAtual a;



--NARPU/Unique
WITH combined_data AS (
    SELECT 
        user_id, 
        NGR 
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-05-29'
    
    UNION ALL
    
    SELECT 
        user_id, 
        NGR 
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-05-29'
)
SELECT 
    SUM(NGR) / NULLIF(COUNT(DISTINCT user_id), 0) AS [NARPU/Unique]
FROM combined_data;



--GGR / GGR - Casino / GGR - Sports
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
    ISNULL(c.casino_ggr, 0) + ISNULL(s.sports_ggr, 0) AS ggr_total,
    c.casino_ggr,
    s.sports_ggr
FROM Casino c
CROSS JOIN Sports s;


--GGR %
WITH GGR_MesAnterior AS (
    SELECT SUM(ggr) AS total_ggr
    FROM (
        SELECT ggr FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
        UNION ALL
        SELECT ggr FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
    ) t
),
GGR_MesAtual AS (
    SELECT SUM(ggr) AS total_ggr
    FROM (
        SELECT ggr FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
        UNION ALL
        SELECT ggr FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
    ) t
)
SELECT 
    CONCAT(CAST(((a.total_ggr - p.total_ggr) * 100.0) / NULLIF(p.total_ggr, 0) AS DECIMAL(10,2)), '%') AS [GGR %]
FROM GGR_MesAnterior p
CROSS JOIN GGR_MesAtual a;



--ARPU/Unique
WITH combined_data AS (
    SELECT 
        user_id, 
        GGR 
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-05-29'
    
    UNION ALL
    
    SELECT 
        user_id, 
        GGR 
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-05-29'
)
SELECT 
    SUM(GGR) / NULLIF(COUNT(DISTINCT user_id), 0) AS [ARPU/Unique]
FROM combined_data;



--Turnover / Turnover - Casino / Turnover - Sports
WITH Casino AS (
    SELECT SUM(Turnover) AS casino_turnover
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-05-29'
),
Sports AS (
    SELECT SUM(Turnover) AS sports_turnover

    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-05-29'
)
SELECT 
    c.casino_turnover,
    s.sports_turnover,
    ISNULL(c.casino_turnover, 0) + ISNULL(s.sports_turnover, 0) AS total_turnover
FROM Casino c
CROSS JOIN Sports s;



--Turnover %
WITH Turnover_MesAnterior AS (
    SELECT SUM(Turnover) AS total_turnover
    FROM (
        SELECT Turnover FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
        UNION ALL
        SELECT Turnover FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
    ) t
),
Turnover_MesAtual AS (
    SELECT SUM(Turnover) AS total_turnover
    FROM (
        SELECT Turnover FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
        UNION ALL
        SELECT Turnover FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
    ) t
)
SELECT 
    CONCAT(CAST(((a.total_turnover - p.total_turnover) * 100.0) / NULLIF(p.total_turnover, 0) AS DECIMAL(10,2)), '%') AS [Turnover %]
FROM Turnover_MesAnterior p
CROSS JOIN Turnover_MesAtual a;



--TOAU/Unique
WITH combined_data AS (
    SELECT 
        user_id, 
        Turnover 
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-05-29'
    
    UNION ALL
    
    SELECT 
        user_id, 
        Turnover 
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-05-29'
)
SELECT 
    SUM(Turnover) / NULLIF(COUNT(DISTINCT user_id), 0) AS TOAU_Unique
FROM combined_data;



--NGR/DEP
WITH Total_NGR AS (
    SELECT SUM(NGR) AS ngr_total
    FROM (
        SELECT NGR FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
        UNION ALL
        SELECT NGR FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
    ) t
),
Total_Deposits AS (
    SELECT SUM(Deposits_Amount) AS dep_total
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
      AND Status = 'Completed'
)
SELECT 
    CONCAT(CAST((n.ngr_total * 100.0) / NULLIF(d.dep_total, 0) AS DECIMAL(10,2)), '%') AS [NGR/DEP]
FROM Total_NGR n
CROSS JOIN Total_Deposits d;



--NGR/DEP %
WITH NGR_MesAnterior AS (
    SELECT SUM(NGR) AS ngr_total
    FROM (
        SELECT NGR FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
        UNION ALL
        SELECT NGR FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
    ) t
),
Dep_MesAnterior AS (
    SELECT SUM(Deposits_Amount) AS dep_total
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-05-01'
      AND Status = 'Completed'
),
NGR_MesAtual AS (
    SELECT SUM(NGR) AS ngr_total
    FROM (
        SELECT NGR FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
        UNION ALL
        SELECT NGR FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
    ) t
),
Dep_MesAtual AS (
    SELECT SUM(Deposits_Amount) AS dep_total
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
      AND Status = 'Completed'
),
Taxas AS (
    SELECT 
        CAST((CAST(na.ngr_total AS DECIMAL(18,4)) / NULLIF(CAST(da.dep_total AS DECIMAL(18,4)), 0)) * 100.0 AS DECIMAL(18,4)) AS ngr_dep_atual,
        CAST((CAST(np.ngr_total AS DECIMAL(18,4)) / NULLIF(CAST(dp.dep_total AS DECIMAL(18,4)), 0)) * 100.0 AS DECIMAL(18,4)) AS ngr_dep_anterior
    FROM NGR_MesAtual na
    CROSS JOIN Dep_MesAtual da
    CROSS JOIN NGR_MesAnterior np
    CROSS JOIN Dep_MesAnterior dp
)
SELECT 
    CONCAT(CAST(((ngr_dep_atual - ngr_dep_anterior) * 100.0) / NULLIF(ngr_dep_anterior, 0) AS DECIMAL(10,2)), '%') AS [NGR/DEP %]
FROM Taxas;


--Bonus / Bonus - Casino / Bonus - Sports

select
    sum(bonus) / 100 as Bonus
from ops_zephyr.dbo.bet_transactions with(nolock)
where created_at >= '2026-05-01' and created_at < '2026-05-28'




select
    sum(vl_bonus) as Bonus
from ops_zephyr.dbo.ft_casino_transaction with(nolock)
where ts_created >= '2026-05-01' and ts_created < '2026-05-28';


select
    sum(bonus) / 100 as Bonus
from ops_zephyr.dbo.casino_transactions with(nolock)
where created_at >= '2026-05-01' and created_at < '2026-05-28'



select 
    sum(bonus_cost) as bonus
from dw_zephyr.dbo.casino_agg_hourly with(nolock)
where date_time >= '2026-05-01' and date_time < '2026-05-28'



--Unique Gamblers MTD
SELECT COUNT(DISTINCT user_id) AS UAP
FROM (
    SELECT user_id
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-05-31'
    
    UNION ALL
    
    SELECT user_id
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-05-31'
) AS combined_users;



--Unique Gamblers MTD %
WITH UAP_MesAnterior AS (
    SELECT COUNT(DISTINCT user_id) AS total_uap
    FROM (
        SELECT user_id FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-05-01'
        UNION ALL
        SELECT user_id FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-05-01'
    ) t
),
UAP_MesAtual AS (
    SELECT COUNT(DISTINCT user_id) AS total_uap
    FROM (
        SELECT user_id FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
        UNION ALL
        SELECT user_id FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
    ) t
)
SELECT 
    CONCAT(CAST(((a.total_uap - p.total_uap) * 100.0) / NULLIF(p.total_uap, 0) AS DECIMAL(10,2)), '%') AS [Unique Gamblers MTD %]
FROM UAP_MesAnterior p
CROSS JOIN UAP_MesAtual a;



--Gamblers (Daily AVG)
SELECT AVG(daily_uap) AS media_diaria_uap
FROM (
    SELECT CAST(date_agg AS DATE) AS date_dia, COUNT(DISTINCT user_id) AS daily_uap
    FROM (
        SELECT date_agg, user_id
        FROM casino_agg_hourly WITH(NOLOCK)
        WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
        
        UNION ALL
        
        SELECT date_agg, user_id
        FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
    ) AS combined_users
    GROUP BY CAST(date_agg AS DATE)
) AS daily_counts;



-- Gamblers Casino (Daily AVG)
SELECT AVG(daily_uap) AS media_diaria_casino
FROM (
    SELECT CAST(date_agg AS DATE) AS date_dia, COUNT(DISTINCT user_id) AS daily_uap
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
    GROUP BY CAST(date_agg AS DATE)
) AS daily_counts;



-- Gamblers Sports (Daily AVG)
SELECT AVG(daily_uap) AS media_diaria_sports
FROM (
    SELECT CAST(date_agg AS DATE) AS date_dia, COUNT(DISTINCT user_id) AS daily_uap
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
    GROUP BY CAST(date_agg AS DATE)
) AS daily_counts;



--Margin
WITH Total_GGR AS (
    SELECT SUM(ggr) AS ggr_total
    FROM (
        SELECT ggr FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
        UNION ALL
        SELECT ggr FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
    ) t
),
Total_Turnover AS (
    SELECT SUM(Turnover) AS turnover_total
    FROM (
        SELECT Turnover FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
        UNION ALL
        SELECT Turnover FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
    ) t
)
SELECT 
    CONCAT(CAST((CAST(g.ggr_total AS DECIMAL(18,4)) / NULLIF(CAST(t.turnover_total AS DECIMAL(18,4)), 0)) * 100.0 AS DECIMAL(10,2)), '%') AS [Margin %]
FROM Total_GGR g
CROSS JOIN Total_Turnover t;



--Margin %
WITH GGR_MesAnterior AS (
    SELECT SUM(ggr) AS ggr_total
    FROM (
        SELECT ggr FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
        UNION ALL
        SELECT ggr FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
    ) t
),
Turnover_MesAnterior AS (
    SELECT SUM(Turnover) AS turnover_total
    FROM (
        SELECT Turnover FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
        UNION ALL
        SELECT Turnover FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
    ) t
),
GGR_MesAtual AS (
    SELECT SUM(ggr) AS ggr_total
    FROM (
        SELECT ggr FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
        UNION ALL
        SELECT ggr FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
    ) t
),
Turnover_MesAtual AS (
    SELECT SUM(Turnover) AS turnover_total
    FROM (
        SELECT Turnover FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
        UNION ALL
        SELECT Turnover FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
    ) t
),
Taxas AS (
    SELECT 
        CAST((CAST(ga.ggr_total AS DECIMAL(18,4)) / NULLIF(CAST(ta.turnover_total AS DECIMAL(18,4)), 0)) * 100.0 AS DECIMAL(18,4)) AS margin_atual,
        CAST((CAST(gp.ggr_total AS DECIMAL(18,4)) / NULLIF(CAST(tp.turnover_total AS DECIMAL(18,4)), 0)) * 100.0 AS DECIMAL(18,4)) AS margin_anterior
    FROM GGR_MesAtual ga
    CROSS JOIN Turnover_MesAtual ta
    CROSS JOIN GGR_MesAnterior gp
    CROSS JOIN Turnover_MesAnterior tp
)
SELECT 
    CONCAT(CAST(((margin_atual - margin_anterior) * 100.0) / NULLIF(margin_anterior, 0) AS DECIMAL(10,2)), '%') AS [Margin %]
FROM Taxas;



--Netcash
WITH Financeiro AS (
    SELECT 
        SUM(Deposits_Amount) AS total_deposits,
        SUM(Withdrawals_amount) AS total_withdrawals
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
      AND Status = 'Completed'
)
SELECT 
    ISNULL(total_deposits, 0) - ISNULL(total_withdrawals, 0) AS Netcash
FROM Financeiro;



--Netcash %
WITH Netcash_MesAnterior AS (
    SELECT 
        (ISNULL(SUM(Deposits_Amount), 0) - ISNULL(SUM(Withdrawals_amount), 0)) AS netcash_anterior
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-05-01'
      AND Status = 'Completed'
),
Netcash_MesAtual AS (
    SELECT 
        (ISNULL(SUM(Deposits_Amount), 0) - ISNULL(SUM(Withdrawals_amount), 0)) AS netcash_atual
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
      AND Status = 'Completed'
)
SELECT 
    CONCAT(CAST(((a.netcash_atual - p.netcash_anterior) * 100.0) / NULLIF(p.netcash_anterior, 0) AS DECIMAL(10,2)), '%') AS [Netcash %]
FROM Netcash_MesAnterior p
CROSS JOIN Netcash_MesAtual a;



--Deposits
SELECT 
    SUM(Deposits_Amount) AS Deposits
FROM payments_agg_hourly WITH(NOLOCK)
WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
and Status = 'Completed'



--Deposits %
WITH Deposits_MesAnterior AS (
    SELECT SUM(Deposits_Amount) AS total_deposits
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < '2026-05-01'
      AND Status = 'Completed'
),
Deposits_MesAtual AS (
    SELECT SUM(Deposits_Amount) AS total_deposits
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
      AND Status = 'Completed'
)
SELECT 
    CONCAT(CAST(((a.total_deposits - p.total_deposits) * 100.0) / NULLIF(p.total_deposits, 0) AS DECIMAL(10,2)), '%') AS [Deposits %]
FROM Deposits_MesAnterior p
CROSS JOIN Deposits_MesAtual a;



--Withdrawals
SELECT 
    SUM(Withdrawals_amount) AS Withdrawals
FROM payments_agg_hourly WITH(NOLOCK)
WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
and Status = 'Completed'



--Registration
SELECT 
    COUNT(DISTINCT User_Id) AS Qtd_Registros
FROM acquisitions_agg  WITH(NOLOCK)
WHERE registration_date >= '2026-05-01' AND registration_date < '2026-05-31'



--Registration %
WITH Registros_MesAnterior AS (
    SELECT COUNT(DISTINCT User_Id) AS Qtd_Registros
    FROM acquisitions_agg WITH(NOLOCK)
    WHERE registration_date >= DATEADD(month, -1, '2026-05-01') AND registration_date < DATEADD(month, -1, '2026-05-31')
),
Registros_MesAtual AS (
    SELECT COUNT(DISTINCT User_Id) AS Qtd_Registros
    FROM acquisitions_agg WITH(NOLOCK)
    WHERE registration_date >= '2026-05-01' AND registration_date < '2026-05-31'
)
SELECT 
    CONCAT(CAST(((a.Qtd_Registros - p.Qtd_Registros) * 100.0) / NULLIF(p.Qtd_Registros, 0) AS DECIMAL(10,2)), '%') AS [Registros %]
FROM Registros_MesAnterior p
CROSS JOIN Registros_MesAtual a;



--FTDs
SELECT 
    COUNT(DISTINCT User_Id) AS FTDs
FROM ftd_agg  WITH(NOLOCK)
WHERE FTD_Date >= '2026-05-01' AND FTD_Date < '2026-05-31'



--FTDs %
WITH FTDs_MesAnterior AS (
    SELECT COUNT(DISTINCT User_Id) AS FTDs
    FROM ftd_agg WITH(NOLOCK)
    WHERE FTD_Date >= DATEADD(month, -1, '2026-05-01') AND FTD_Date < DATEADD(month, -1, '2026-05-31')
),
FTDs_MesAtual AS (
    SELECT COUNT(DISTINCT User_Id) AS FTDs
    FROM ftd_agg WITH(NOLOCK)
    WHERE FTD_Date >= '2026-05-01' AND FTD_Date < '2026-05-31'
)
SELECT 
    CONCAT(CAST(((a.FTDs - p.FTDs) * 100.0) / NULLIF(p.FTDs, 0) AS DECIMAL(10,2)), '%') AS [FTD %]
FROM FTDs_MesAnterior p
CROSS JOIN FTDs_MesAtual a;



--Hold (NGR/GGR)
WITH Total_NGR AS (
    SELECT SUM(NGR) AS ngr_total
    FROM (
        SELECT NGR FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
        UNION ALL
        SELECT NGR FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
    ) t
),
Total_GGR AS (
    SELECT SUM(ggr) AS ggr_total
    FROM (
        SELECT ggr FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
        UNION ALL
        SELECT ggr FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
    ) t
)
SELECT 
    CONCAT(CAST((CAST(n.ngr_total AS DECIMAL(18,4)) / NULLIF(CAST(g.ggr_total AS DECIMAL(18,4)), 0)) * 100.0 AS DECIMAL(10,2)), '%') AS [Hold (NGR/GGR)]
FROM Total_NGR n
CROSS JOIN Total_GGR g;



--Hold (NGR/GGR)
WITH NGR_MesAnterior AS (
    SELECT SUM(NGR) AS ngr_total
    FROM (
        SELECT NGR FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
        UNION ALL
        SELECT NGR FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
    ) t
),
GGR_MesAnterior AS (
    SELECT SUM(ggr) AS ggr_total
    FROM (
        SELECT ggr FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
        UNION ALL
        SELECT ggr FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < '2026-05-01'
    ) t
),
NGR_MesAtual AS (
    SELECT SUM(NGR) AS ngr_total
    FROM (
        SELECT NGR FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
        UNION ALL
        SELECT NGR FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
    ) t
),
GGR_MesAtual AS (
    SELECT SUM(ggr) AS ggr_total
    FROM (
        SELECT ggr FROM casino_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
        UNION ALL
        SELECT ggr FROM sports_agg_hourly WITH(NOLOCK) 
        WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
    ) t
),
Taxas AS (
    SELECT 
        CAST((CAST(na.ngr_total AS DECIMAL(18,4)) / NULLIF(CAST(ga.ggr_total AS DECIMAL(18,4)), 0)) * 100.0 AS DECIMAL(18,4)) AS hold_atual,
        CAST((CAST(np.ngr_total AS DECIMAL(18,4)) / NULLIF(CAST(gp.ggr_total AS DECIMAL(18,4)), 0)) * 100.0 AS DECIMAL(18,4)) AS hold_anterior
    FROM NGR_MesAtual na
    CROSS JOIN GGR_MesAtual ga
    CROSS JOIN NGR_MesAnterior np
    CROSS JOIN GGR_MesAnterior gp
)
SELECT 
    CONCAT(CAST(((hold_atual - hold_anterior) * 100.0) / NULLIF(hold_anterior, 0) AS DECIMAL(10,2)), '%') AS [Hold (NGR/GGR) %]
FROM Taxas;



--Hold (NGR/GGR) - Casino
WITH Casino_Dados AS (
    SELECT 
        SUM(NGR) AS ngr_casino,
        SUM(ggr) AS ggr_casino
    FROM casino_agg_hourly WITH(NOLOCK) 
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
)
SELECT 
    CONCAT(CAST((CAST(ngr_casino AS DECIMAL(18,4)) / NULLIF(CAST(ggr_casino AS DECIMAL(18,4)), 0)) * 100.0 AS DECIMAL(10,2)), '%') AS [Hold (NGR/GGR) - Casino]
FROM Casino_Dados;


--Hold (NGR/GGR) - Sports
WITH Sports_Dados AS (
    SELECT 
        SUM(NGR) AS ngr_sports,
        SUM(ggr) AS ggr_sports
    FROM sports_agg_hourly WITH(NOLOCK) 
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
)
SELECT 
    CONCAT(CAST((CAST(ngr_sports AS DECIMAL(18,4)) / NULLIF(CAST(ggr_sports AS DECIMAL(18,4)), 0)) * 100.0 AS DECIMAL(10,2)), '%') AS [Hold (NGR/GGR) - Sports]
FROM Sports_Dados;