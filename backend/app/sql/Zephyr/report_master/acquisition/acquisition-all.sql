--========= Acquisition - All ================== 

--Registrations
select 
    count(distinct user_id)
from acquisitions_agg with(nolock)
where registration_date >= '2026-05-01' and registration_date < '2026-06-01'



--FTDs
SELECT 
    COUNT(DISTINCT User_Id) AS FTDs
FROM ftd_agg  WITH(NOLOCK)
WHERE FTD_DATE >= '2026-05-01' AND FTD_Date < '2026-05-31'



--Investiment



--CPA



--Global GGR
WITH Casino AS (
    SELECT SUM(ggr) AS casino_ggr
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
),
Sports AS (
    SELECT SUM(ggr) AS sports_ggr
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
)
SELECT 
    ISNULL(c.casino_ggr, 0) + ISNULL(s.sports_ggr, 0) AS ggr_total
FROM Casino c
CROSS JOIN Sports s;



--GGR All Cohort
WITH casino AS (
    SELECT
        SUM(c.ggr) AS ggr_casino
    FROM casino_agg_hourly c WITH(NOLOCK)
    inner join acquisitions_agg a with(nolock) on a.user_id = c.user_id
    left join affiliates_agg aff with(nolock) on aff.Affiliate_Id = a.Affiliate_Id
    WHERE c.date_time >= '2026-05-01' AND c.date_time < '2026-06-01'
    and aff.Affiliate_Manager in ('GoogleAds', 'GoogleAdsNOVO', 'MetaAds', 'MetaAdsNOVO', 
                                    'AfiliadosAtivosCpa', 'AfiliadosAtivosRev', 'AfiliadosAtivosHib', 'PeaklineMedia', 'VertexGroup')
), sports AS (
    SELECT
        SUM(s.ggr) AS ggr_sportsbook
    FROM sports_agg_hourly s WITH(NOLOCK)
    inner join acquisitions_agg a with(nolock) on a.user_id = s.user_id
    left join affiliates_agg aff with(nolock) on aff.Affiliate_Id = a.Affiliate_Id
    WHERE s.date_time >= '2026-05-01' AND s.date_time < '2026-06-01'
    and aff.Affiliate_Manager in ('GoogleAds', 'GoogleAdsNOVO', 'MetaAds', 'MetaAdsNOVO', 
                                    'AfiliadosAtivosCpa', 'AfiliadosAtivosRev', 'AfiliadosAtivosHib', 'PeaklineMedia', 'VertexGroup')
)
SELECT
    ISNULL(c.ggr_casino, 0) + ISNULL(s.ggr_sportsbook, 0) AS [GGR All Cohort]
FROM casino c
CROSS JOIN sports s;



--GGR/FTD



--GGR Cohort
WITH Casino AS (
    SELECT SUM(c.ggr) AS casino_ggr
    FROM casino_agg_hourly c WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = c.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = a.Affiliate_Id
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = c.user_id
    WHERE c.date_time >= '2026-05-01' AND c.date_time < '2026-06-01'
    AND f.FTD_Date >= '2026-05-01' AND f.FTD_Date < '2026-06-01'
    AND aff.Affiliate_Manager IN ('GoogleAds', 'GoogleAdsNOVO', 'MetaAds', 'MetaAdsNOVO', 
                                  'AfiliadosAtivosCpa', 'AfiliadosAtivosRev', 'AfiliadosAtivosHib', 'PeaklineMedia', 'VertexGroup')
),
Sports AS (
    SELECT SUM(s.ggr) AS sports_ggr
    FROM sports_agg_hourly s WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = s.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = a.Affiliate_Id
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = s.user_id
    WHERE s.date_time >= '2026-05-01' AND s.date_time < '2026-06-01'
    AND f.FTD_Date >= '2026-05-01' AND f.FTD_Date < '2026-06-01'
    AND aff.Affiliate_Manager IN ('GoogleAds', 'GoogleAdsNOVO', 'MetaAds', 'MetaAdsNOVO', 
                                  'AfiliadosAtivosCpa', 'AfiliadosAtivosRev', 'AfiliadosAtivosHib', 'PeaklineMedia', 'VertexGroup')
)
SELECT 
    ISNULL(c.casino_ggr, 0) + ISNULL(s.sports_ggr, 0) AS [GGR Cohort]
FROM Casino c
CROSS JOIN Sports s;



--% GGR
WITH Casino AS (
    SELECT 
        SUM(CASE WHEN c.date_time >= '2026-05-01' AND f.FTD_Date >= '2026-05-01' THEN c.ggr ELSE 0 END) AS g_atual,
        SUM(CASE WHEN c.date_time < '2026-05-01' AND f.FTD_Date < '2026-05-01' THEN c.ggr ELSE 0 END) AS g_anterior
    FROM casino_agg_hourly c WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = c.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = a.Affiliate_Id
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = c.user_id
    WHERE c.date_time >= '2026-04-01' AND c.date_time < '2026-06-01'
    AND f.FTD_Date >= '2026-04-01' AND f.FTD_Date < '2026-06-01'
    AND aff.Affiliate_Manager IN ('GoogleAds', 'GoogleAdsNOVO', 'MetaAds', 'MetaAdsNOVO', 
                                  'AfiliadosAtivosCpa', 'AfiliadosAtivosRev', 'AfiliadosAtivosHib', 'PeaklineMedia', 'VertexGroup')
),
Sports AS (
    SELECT 
        SUM(CASE WHEN s.date_time >= '2026-05-01' AND f.FTD_Date >= '2026-05-01' THEN s.ggr ELSE 0 END) AS g_atual,
        SUM(CASE WHEN s.date_time < '2026-05-01' AND f.FTD_Date < '2026-05-01' THEN s.ggr ELSE 0 END) AS g_anterior
    FROM sports_agg_hourly s WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = s.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = a.Affiliate_Id
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = s.user_id
    WHERE s.date_time >= '2026-04-01' AND s.date_time < '2026-06-01'
    AND f.FTD_Date >= '2026-04-01' AND f.FTD_Date < '2026-06-01'
    AND aff.Affiliate_Manager IN ('GoogleAds', 'GoogleAdsNOVO', 'MetaAds', 'MetaAdsNOVO', 
                                  'AfiliadosAtivosCpa', 'AfiliadosAtivosRev', 'AfiliadosAtivosHib', 'PeaklineMedia', 'VertexGroup')
)
SELECT 
    (((ISNULL(c.g_atual, 0) + ISNULL(s.g_atual, 0)) - (ISNULL(c.g_anterior, 0) + ISNULL(s.g_anterior, 0))) 
    / NULLIF(ISNULL(c.g_anterior, 0) + ISNULL(s.g_anterior, 0), 0)) * 100.0 AS [Variacao Percentual]
FROM Casino c
CROSS JOIN Sports s;



--Global Turnover
WITH Casino AS (
    SELECT SUM(Turnover) AS casino_turnover
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
),
Sports AS (
    SELECT SUM(Turnover) AS sports_turnover

    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= '2026-05-01' AND date_time < '2026-06-01'
)
SELECT 
    ISNULL(c.casino_turnover, 0) + ISNULL(s.sports_turnover, 0) AS [Global Turnover]
FROM Casino c
CROSS JOIN Sports s;



--Turnover All Cohort
WITH casino AS (
    SELECT
        SUM(c.turnover) AS turnover_casino
    FROM casino_agg_hourly c WITH(NOLOCK)
    inner join acquisitions_agg a with(nolock) on a.user_id = c.user_id
    left join affiliates_agg aff with(nolock) on aff.Affiliate_Id = a.Affiliate_Id
    WHERE c.date_time >= '2026-05-01' AND c.date_time < '2026-06-01'
    and aff.Affiliate_Manager in ('GoogleAds', 'GoogleAdsNOVO', 'MetaAds', 'MetaAdsNOVO', 
                                    'AfiliadosAtivosCpa', 'AfiliadosAtivosRev', 'AfiliadosAtivosHib', 'PeaklineMedia', 'VertexGroup')
), sports AS (
    SELECT
        SUM(s.turnover) AS turnover_sportsbook
    FROM sports_agg_hourly s WITH(NOLOCK)
    inner join acquisitions_agg a with(nolock) on a.user_id = s.user_id
    left join affiliates_agg aff with(nolock) on aff.Affiliate_Id = a.Affiliate_Id
    WHERE s.date_time >= '2026-05-01' AND s.date_time < '2026-06-01'
    and aff.Affiliate_Manager in ('GoogleAds', 'GoogleAdsNOVO', 'MetaAds', 'MetaAdsNOVO', 
                                    'AfiliadosAtivosCpa', 'AfiliadosAtivosRev', 'AfiliadosAtivosHib', 'PeaklineMedia', 'VertexGroup')
)
SELECT
    ISNULL(c.turnover_casino, 0) + ISNULL(s.turnover_sportsbook, 0) AS [Turnover All Cohort]
FROM casino c
CROSS JOIN sports s;



--Turnover Cohort
WITH casino AS (
    SELECT
        SUM(c.turnover) AS turnover_casino
    FROM casino_agg_hourly c WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = c.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = a.Affiliate_Id
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = c.user_id
    WHERE c.date_time >= '2026-05-01' AND c.date_time < '2026-06-01'
    AND f.FTD_Date >= '2026-05-01' AND f.FTD_Date < '2026-06-01'
    AND aff.Affiliate_Manager IN ('GoogleAds', 'GoogleAdsNOVO', 'MetaAds', 'MetaAdsNOVO', 
                                  'AfiliadosAtivosCpa', 'AfiliadosAtivosRev', 'AfiliadosAtivosHib', 'PeaklineMedia', 'VertexGroup')
), sports AS (
    SELECT
        SUM(s.turnover) AS turnover_sportsbook
    FROM sports_agg_hourly s WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = s.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = a.Affiliate_Id
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = s.user_id
    WHERE s.date_time >= '2026-05-01' AND s.date_time < '2026-06-01'
    AND f.FTD_Date >= '2026-05-01' AND f.FTD_Date < '2026-06-01'
    AND aff.Affiliate_Manager IN ('GoogleAds', 'GoogleAdsNOVO', 'MetaAds', 'MetaAdsNOVO', 
                                  'AfiliadosAtivosCpa', 'AfiliadosAtivosRev', 'AfiliadosAtivosHib', 'PeaklineMedia', 'VertexGroup')
)
SELECT
    ISNULL(c.turnover_casino, 0) + ISNULL(s.turnover_sportsbook, 0) AS [Turnover Cohort]
FROM casino c
CROSS JOIN sports s;



--% Turnover
WITH casino AS (
    SELECT
        SUM(CASE WHEN c.date_time >= '2026-05-01' AND f.FTD_Date >= '2026-05-01' THEN c.turnover ELSE 0 END) AS t_atual,
        SUM(CASE WHEN c.date_time < '2026-05-01' AND f.FTD_Date < '2026-05-01' THEN c.turnover ELSE 0 END) AS t_anterior
    FROM casino_agg_hourly c WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = c.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = a.Affiliate_Id
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = c.user_id
    WHERE c.date_time >= '2026-04-01' AND c.date_time < '2026-06-01'
    AND f.FTD_Date >= '2026-04-01' AND f.FTD_Date < '2026-06-01'
    AND aff.Affiliate_Manager IN ('GoogleAds', 'GoogleAdsNOVO', 'MetaAds', 'MetaAdsNOVO', 
                                  'AfiliadosAtivosCpa', 'AfiliadosAtivosRev', 'AfiliadosAtivosHib', 'PeaklineMedia', 'VertexGroup')
), sports AS (
    SELECT
        SUM(CASE WHEN s.date_time >= '2026-05-01' AND f.FTD_Date >= '2026-05-01' THEN s.turnover ELSE 0 END) AS t_atual,
        SUM(CASE WHEN s.date_time < '2026-05-01' AND f.FTD_Date < '2026-05-01' THEN s.turnover ELSE 0 END) AS t_anterior
    FROM sports_agg_hourly s WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = s.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = a.Affiliate_Id
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = s.user_id
    WHERE s.date_time >= '2026-04-01' AND s.date_time < '2026-06-01'
    AND f.FTD_Date >= '2026-04-01' AND f.FTD_Date < '2026-06-01'
    AND aff.Affiliate_Manager IN ('GoogleAds', 'GoogleAdsNOVO', 'MetaAds', 'MetaAdsNOVO', 
                                  'AfiliadosAtivosCpa', 'AfiliadosAtivosRev', 'AfiliadosAtivosHib', 'PeaklineMedia', 'VertexGroup')
)
SELECT
    (((ISNULL(c.t_atual, 0) + ISNULL(s.t_atual, 0)) - (ISNULL(c.t_anterior, 0) + ISNULL(s.t_anterior, 0))) 
    / NULLIF(ISNULL(c.t_anterior, 0) + ISNULL(s.t_anterior, 0), 0)) * 100.0 AS [Variacao Percentual]
FROM casino c
CROSS JOIN sports s;



--Top 5 Btags
--FTDs Top 5
SELECT TOP 5 
    a.Affiliate_Name,
    COUNT(DISTINCT f.User_Id) AS ftd_volume
FROM acquisitions_agg a WITH(NOLOCK)
INNER JOIN ftd_agg f WITH(NOLOCK) ON f.User_Id = a.User_Id
WHERE f.FTD_Date >= '2026-05-01' AND f.FTD_Date < '2026-06-01'
GROUP BY a.btag, a.Affiliate_Name
ORDER BY ftd_volume DESC;



--% FTDs


--Online Marketing
--FTDs Online
WITH Categories AS (
    SELECT [Online Marketing], sort_order
    FROM (VALUES 
        ('Google', 1),
        ('Meta', 2),
        ('Default', 3),
        ('CPA Affiliates', 4),
        ('RevShare Affiliates', 5),
        ('Hybrid Affiliates', 6)
    ) AS t([Online Marketing], sort_order)
),
BaseData AS (
    SELECT 
        CASE 
            WHEN aff.affiliate_manager IN ('GoogleAds', 'GoogleAdsNOVO') THEN 'Google'
            WHEN aff.affiliate_manager IN ('MetaAds', 'MetaAdsNOVO') THEN 'Meta'
            WHEN a.Affiliate_Id IS NULL THEN 'Default'
            WHEN aff.affiliate_manager = 'AfiliadosAtivosCpa' THEN 'CPA Affiliates'
            WHEN aff.affiliate_manager IN ('AfiliadosAtivosRev', 'PeaklineMedia', 'VertexGroup') THEN 'RevShare Affiliates'
            WHEN aff.affiliate_manager = 'AfiliadosAtivosHib' THEN 'Hybrid Affiliates'
        END AS [Online Marketing],
        f.User_Id
    FROM acquisitions_agg a WITH(NOLOCK)
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.User_Id = a.User_Id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = a.Affiliate_Id
    WHERE f.FTD_Date >= '2026-05-01' AND f.FTD_Date < '2026-06-01'
)
SELECT 
    c.[Online Marketing],
    COUNT(DISTINCT b.User_Id) AS FTD
FROM Categories c
LEFT JOIN BaseData b ON c.[Online Marketing] = b.[Online Marketing]
GROUP BY c.[Online Marketing], c.sort_order
ORDER BY c.sort_order;


