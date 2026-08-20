-- Report Master / Acquisition - All: GGR Cohort
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH Casino AS (
    SELECT SUM(c.ggr) AS casino_ggr
    FROM casino_agg_hourly c WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = c.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = a.Affiliate_Id
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = c.user_id
    WHERE c.date_time >= @data_ini AND c.date_time < @data_fim_exclusive
    AND f.FTD_Date >= @data_ini AND f.FTD_Date < @data_fim_exclusive
    AND aff.Affiliate_Manager IN ('GoogleAds (444)', 'GoogleAdsNOVO (501)', 'MetaAds (447)', 'MetaAdsNOVO (502)', 'TikTokAds (449)',
                                  'AfiliadosAtivosCpa (434)', 'AfiliadosAtivosRev (436)', 'AfiliadosAtivosHib (435)', 'PeaklineMedia (437)', 'VertexGroup (439)')
),
Sports AS (
    SELECT SUM(s.ggr) AS sports_ggr
    FROM sports_agg_hourly s WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = s.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = a.Affiliate_Id
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = s.user_id
    WHERE s.date_time >= @data_ini AND s.date_time < @data_fim_exclusive
    AND f.FTD_Date >= @data_ini AND f.FTD_Date < @data_fim_exclusive
    AND aff.Affiliate_Manager IN ('GoogleAds (444)', 'GoogleAdsNOVO (501)', 'MetaAds (447)', 'MetaAdsNOVO (502)', 'TikTokAds (449)',
                                  'AfiliadosAtivosCpa (434)', 'AfiliadosAtivosRev (436)', 'AfiliadosAtivosHib (435)', 'PeaklineMedia (437)', 'VertexGroup (439)')
)
SELECT
    ISNULL(c.casino_ggr, 0) + ISNULL(s.sports_ggr, 0) AS [GGR Cohort]
FROM Casino c
CROSS JOIN Sports s;
