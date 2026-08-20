-- Report Master / Acquisition - All: GGR All Cohort
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH casino AS (
    SELECT SUM(c.ggr) AS ggr_casino
    FROM casino_agg_hourly c WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = c.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = a.Affiliate_Id
    WHERE c.date_time >= @data_ini AND c.date_time < @data_fim_exclusive
    AND aff.Affiliate_Manager IN ('GoogleAds (444)', 'GoogleAdsNOVO (501)', 'MetaAds (447)', 'MetaAdsNOVO (502)', 'TikTokAds (449)',
                                  'AfiliadosAtivosCpa (434)', 'AfiliadosAtivosRev (436)', 'AfiliadosAtivosHib (435)', 'PeaklineMedia (437)', 'VertexGroup (439)')
), sports AS (
    SELECT SUM(s.ggr) AS ggr_sportsbook
    FROM sports_agg_hourly s WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = s.user_id
    LEFT JOIN affiliates_agg aff WITH(NOLOCK) ON aff.Affiliate_Id = a.Affiliate_Id
    WHERE s.date_time >= @data_ini AND s.date_time < @data_fim_exclusive
    AND aff.Affiliate_Manager IN ('GoogleAds (444)', 'GoogleAdsNOVO (501)', 'MetaAds (447)', 'MetaAdsNOVO (502)', 'TikTokAds (449)',
                                  'AfiliadosAtivosCpa (434)', 'AfiliadosAtivosRev (436)', 'AfiliadosAtivosHib (435)', 'PeaklineMedia (437)', 'VertexGroup (439)')
)
SELECT
    ISNULL(c.ggr_casino, 0) + ISNULL(s.ggr_sportsbook, 0) AS [GGR All Cohort]
FROM casino c
CROSS JOIN sports s;
