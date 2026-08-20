--======== Casino =============

--NGR - Casino
    SELECT
        SUM(NGR) AS [NGR - Casino]
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2023-04-01' AND date_time < '2026-05-01'



--NGR - Casino %
WITH NGR_PeriodoAnterior AS (
    SELECT SUM(NGR) AS NGR
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= DATEADD(month, -1, '2023-05-01') AND date_time < DATEADD(month, -1, '2026-06-01')
),
NGR_PeriodoAtual AS (
    SELECT SUM(NGR) AS NGR
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2023-05-01' AND date_time < '2026-06-01'
)
SELECT 
    CONCAT(CAST(((a.NGR - p.NGR) * 100.0) / NULLIF(p.NGR, 0) AS DECIMAL(10,2)), '%') AS [NGR - Casino %]
FROM NGR_PeriodoAnterior p
CROSS JOIN NGR_PeriodoAtual a;



--GGR - Casino 
    SELECT 
        SUM(ggr) AS [GGR - Casino]
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'



--GGR - Casino %
WITH GGR_PeriodoAnterior AS (
    SELECT SUM(ggr) AS GGR
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-04-01'
      AND date_time < '2026-05-01'
),
GGR_PeriodoAtual AS (
    SELECT SUM(ggr) AS GGR
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01'
      AND date_time < '2026-06-01'
)
SELECT
    CONCAT(
        CAST(
            ((a.GGR - p.GGR) * 100.0) / NULLIF(p.GGR, 0)
            AS DECIMAL(10,2)
        ),
        '%'
    ) AS [GGR - Casino % Delta]
FROM GGR_PeriodoAnterior p
CROSS JOIN GGR_PeriodoAtual a;



--Turnover - Casino
    SELECT 
        SUM(Turnover) AS [Turnover - Casino]
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'



--Margin - Casino
SELECT 
    SUM(ggr) / NULLIF(SUM(Turnover), 0) AS [Margin - Casino]
FROM casino_agg_hourly WITH(NOLOCK)
WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'



--Margin - Casino %
WITH Margin_PeriodoAnterior AS (
    SELECT SUM(ggr) / NULLIF(SUM(Turnover), 0) AS Margin
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < DATEADD(month, -1, '2026-06-01')
),
Margin_PeriodoAtual AS (
    SELECT SUM(ggr) / NULLIF(SUM(Turnover), 0) AS Margin
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
)
SELECT 
    CONCAT(CAST(((a.Margin - p.Margin) * 100.0) / NULLIF(p.Margin, 0) AS DECIMAL(10,2)), '%') AS [Margin - Casino %]
FROM Margin_PeriodoAnterior p
CROSS JOIN Margin_PeriodoAtual a;



--AVG Bet
    SELECT 
        AVG(Turnover) AS [AVG Bet]
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'



--AVG Bet %
WITH AVGBet_PeriodoAnterior AS (
    SELECT AVG(Turnover) AS AVGBet
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < DATEADD(month, -1, '2026-06-01')
),
AVGBet_PeriodoAtual AS (
    SELECT AVG(Turnover) AS AVGBet
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
)
SELECT 
    CONCAT(CAST(((a.AVGBet - p.AVGBet) * 100.0) / NULLIF(p.AVGBet, 0) AS DECIMAL(10,2)), '%') AS [AVG Bet %]
FROM AVGBet_PeriodoAnterior p
CROSS JOIN AVGBet_PeriodoAtual a;



--Unique Gamblers
    select
        count(distinct user_id) as [Unique Gamblers]
    FROM casino_agg_hourly with(nolock)
    where date_agg >= '2026-05-01' and date_agg < '2026-06-01'



--Unique Gamblers %
WITH UG_PeriodoAnterior AS (
    SELECT COUNT(DISTINCT user_id) AS UG
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < DATEADD(month, -1, '2026-06-01')
),
UG_PeriodoAtual AS (
    SELECT COUNT(DISTINCT user_id) AS UG
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
)
SELECT 
    CONCAT(CAST(((a.UG - p.UG) * 100.0) / NULLIF(p.UG, 0) AS DECIMAL(10,2)), '%') AS [Unique Gamblers %]
FROM UG_PeriodoAnterior p
CROSS JOIN UG_PeriodoAtual a;



--Generosity



--Generosity %



--Bonus - Casino
    select
        sum(turnover_bonus) as [Bonus - Casino]
    from casino_agg_hourly with(nolock)
    where date_agg >= '2026-05-01' and date_agg < '2026-06-01'



