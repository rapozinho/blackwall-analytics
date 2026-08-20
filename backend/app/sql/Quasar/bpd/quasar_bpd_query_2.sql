DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';

-- Variável interna para ajustar o intervalo (não precisa mexer aqui)
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH user_ggr AS (
    -- Garante que cada usuário tenha apenas uma linha com o GGR total (Casino + Sports)
    SELECT User_Id, SUM(GGR_Total) AS GGR_Total
    FROM (
        SELECT c.User_Id, SUM(c.GGR) AS GGR_Total
        FROM casino_agg_hourly c WITH(NOLOCK)
        WHERE c.Date_Agg >= @data_ini AND c.Date_Agg < @data_fim_exclusive
        GROUP BY c.User_Id
        UNION ALL
        SELECT s.User_Id, SUM(s.GGR) AS GGR_Total
        FROM sports_agg_hourly s WITH(NOLOCK)
        WHERE s.Date_Agg >= @data_ini AND s.Date_Agg < @data_fim_exclusive
        GROUP BY s.User_Id
    ) AS pre_aggregated
    GROUP BY User_Id
)

SELECT categoria, SUM(GGR_Total) AS GGR_all_cohort
FROM (
    -- Internal Traffic
    SELECT 'Internal Traffic' AS categoria, ug.GGR_Total
    FROM acquisitions_agg acq
    INNER JOIN affiliates_agg aff ON acq.affiliate_id = aff.affiliate_id
    INNER JOIN user_ggr ug ON ug.User_Id = acq.User_Id
    WHERE aff.affiliate_manager IN (
        'GoogleAds (444)', 'GoogleAdsNOVO (501)', 'MetaAds (447)', 'MetaAdsNOVO (502)', 'ScoreWire (448)', 'TaboolaAds (481)', 'TikTokAds (449)'
    )

    UNION ALL

    -- Affiliates
    SELECT 'Affiliates' AS categoria, ug.GGR_Total
    FROM acquisitions_agg acq
    INNER JOIN affiliates_agg aff ON acq.affiliate_id = aff.affiliate_id
    INNER JOIN user_ggr ug ON ug.User_Id = acq.User_Id
    WHERE aff.affiliate_manager IN (
        'AfiliadosAtivosRev (436)', 'AfiliadosAtivosCpa (434)',
        'AfiliadosAtivosHib (435)', 'DistratoRev (529)',
        'Afiliadosinativos (443)', 'VertexGroup (439)',
        'PeaklineMedia (437)'
    )

    UNION ALL

    -- Organic
    SELECT 'Organic' AS categoria, ug.GGR_Total
    FROM acquisitions_agg acq
    INNER JOIN user_ggr ug ON ug.User_Id = acq.User_Id
    WHERE acq.acquisition_channel = 'organic'

    UNION ALL

    -- External Traffic
    SELECT 'External Traffic' AS categoria, ug.GGR_Total
    FROM acquisitions_agg acq
    INNER JOIN affiliates_agg aff ON acq.affiliate_id = aff.affiliate_id
    INNER JOIN user_ggr ug ON ug.User_Id = acq.User_Id
    WHERE aff.affiliate_manager = 'parceiroadmin (445)'

    UNION ALL

    -- Influencers
    SELECT 'Influencers' AS categoria, ug.GGR_Total
    FROM acquisitions_agg acq
    INNER JOIN affiliates_agg aff ON acq.affiliate_id = aff.affiliate_id
    INNER JOIN user_ggr ug ON ug.User_Id = acq.User_Id
    WHERE aff.affiliate_manager = 'InfluenciadoresQuasar (446)'
) AS resultados
GROUP BY categoria;