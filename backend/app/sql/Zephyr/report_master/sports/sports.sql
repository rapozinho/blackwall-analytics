--======== Sports =============

--NGR - Sports
    SELECT
        SUM(NGR) AS [NGR - Sports]
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2023-05-01' AND date_time < '2026-06-01'



--NGR - Sports %
WITH NGR_PeriodoAnterior AS (
    SELECT SUM(NGR) AS NGR
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= DATEADD(month, -1, '2023-05-01') AND date_time < DATEADD(month, -1, '2026-06-01')
),
NGR_PeriodoAtual AS (
    SELECT SUM(NGR) AS NGR
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2023-05-01' AND date_time < '2026-06-01'
)
SELECT 
    CONCAT(CAST(((a.NGR - p.NGR) * 100.0) / NULLIF(p.NGR, 0) AS DECIMAL(10,2)), '%') AS [NGR - Casino %]
FROM NGR_PeriodoAnterior p
CROSS JOIN NGR_PeriodoAtual a;



--GGR - Sports 
    SELECT 
        SUM(ggr) AS [GGR - Sports]
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'



--GGR - Sports %
WITH GGR_PeriodoAnterior AS (
    SELECT SUM(ggr) AS GGR
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-04-01'
      AND date_time < '2026-05-01'
),
GGR_PeriodoAtual AS (
    SELECT SUM(ggr) AS GGR
    FROM sports_agg_hourly WITH(NOLOCK)
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



--Turnover - Sports
    SELECT 
        SUM(Turnover) AS [Turnover - Sports]
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'


--Gamblers (Daily AVG)
    SELECT AVG(daily_uap) AS [Gamblers (Daily AVG]
    FROM (
        SELECT CAST(date_agg AS DATE) AS date_dia, COUNT(DISTINCT user_id) AS daily_uap
        FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
        GROUP BY CAST(date_agg AS DATE)
    ) AS daily_counts;



--Gamblers (Daily AVG) %
WITH Gamblers_PeriodoAnterior AS (
    SELECT AVG(daily_uap) AS GamblersAVG
    FROM (
        SELECT CAST(date_agg AS DATE) AS date_dia, COUNT(DISTINCT user_id) AS daily_uap
        FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_agg >= DATEADD(month, -1, '2026-05-01') AND date_agg < DATEADD(month, -1, '2026-06-01')
        GROUP BY CAST(date_agg AS DATE)
    ) AS daily_counts
),
Gamblers_PeriodoAtual AS (
    SELECT AVG(daily_uap) AS GamblersAVG
    FROM (
        SELECT CAST(date_agg AS DATE) AS date_dia, COUNT(DISTINCT user_id) AS daily_uap
        FROM sports_agg_hourly WITH(NOLOCK)
        WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'
        GROUP BY CAST(date_agg AS DATE)
    ) AS daily_counts
)
SELECT 
    CONCAT(CAST(((a.GamblersAVG - p.GamblersAVG) * 100.0) / NULLIF(p.GamblersAVG, 0) AS DECIMAL(10,2)), '%') AS [Gamblers (Daily AVG) %]
FROM Gamblers_PeriodoAnterior p
CROSS JOIN Gamblers_PeriodoAtual a;



--Unique MTD - Sports
    select
        count(distinct user_id) as [Unique MTD - Sports]
    from sports_agg_hourly with(nolock)
    WHERE date_agg >= '2026-05-01' AND date_agg < '2026-06-01'


--AVG Bet - Sports (Amount)
    SELECT 
        AVG(Turnover) AS [AVG Bet - Sports (Amount)]
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'



--AVG Bet - Sports (Amount) %
WITH AVGBetSports_PeriodoAnterior AS (
    SELECT AVG(Turnover) AS AVGBet
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < DATEADD(month, -1, '2026-06-01')
),
AVGBetSports_PeriodoAtual AS (
    SELECT AVG(Turnover) AS AVGBet
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
)
SELECT 
    CONCAT(CAST(((a.AVGBet - p.AVGBet) * 100.0) / NULLIF(p.AVGBet, 0) AS DECIMAL(10,2)), '%') AS [AVG Bet - Sports (Amount) %]
FROM AVGBetSports_PeriodoAnterior p
CROSS JOIN AVGBetSports_PeriodoAtual a;



--Margin - Sports
SELECT 
    SUM(ggr) / NULLIF(SUM(Turnover), 0) AS [Margin - Casino]
FROM sports_agg_hourly WITH(NOLOCK)
WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'



--Margin - Sports %
WITH Margin_PeriodoAnterior AS (
    SELECT SUM(ggr) / NULLIF(SUM(Turnover), 0) AS Margin
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= DATEADD(month, -1, '2026-05-01') AND date_time < DATEADD(month, -1, '2026-06-01')
),
Margin_PeriodoAtual AS (
    SELECT SUM(ggr) / NULLIF(SUM(Turnover), 0) AS Margin
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
)
SELECT 
    CONCAT(CAST(((a.Margin - p.Margin) * 100.0) / NULLIF(p.Margin, 0) AS DECIMAL(10,2)), '%') AS [Margin - Casino %]
FROM Margin_PeriodoAnterior p
CROSS JOIN Margin_PeriodoAtual a;



--Generosity - Sports



--Generosity - Sports %



--Bonus - Sports


