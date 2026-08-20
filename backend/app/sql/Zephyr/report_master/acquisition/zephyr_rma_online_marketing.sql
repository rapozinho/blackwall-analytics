-- Report Master / Acquisition - All: Online Marketing / FTDs - Online
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

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
    WHERE f.FTD_Date >= @data_ini AND f.FTD_Date < @data_fim_exclusive
)
SELECT
    c.[Online Marketing],
    COUNT(DISTINCT b.User_Id) AS [FTDs - Online]
FROM Categories c
LEFT JOIN BaseData b ON c.[Online Marketing] = b.[Online Marketing]
GROUP BY c.[Online Marketing], c.sort_order
ORDER BY c.sort_order;
