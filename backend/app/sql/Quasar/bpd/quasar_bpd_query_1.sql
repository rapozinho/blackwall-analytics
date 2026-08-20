DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';

-- Variável interna para ajustar o intervalo (não precisa mexer aqui)
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

SELECT categoria, FTDs FROM (
    -- Internal Traffic
    SELECT 'Internal Traffic' AS Categoria,
           COUNT(DISTINCT ftd.user_id) AS FTDs
    FROM ftd_agg ftd
    INNER JOIN acquisitions_agg acq ON ftd.user_id = acq.user_id
    INNER JOIN affiliates_agg aff ON acq.affiliate_id = aff.affiliate_id
    WHERE ftd.ftd_date >= @data_ini AND ftd.ftd_date < @data_fim_exclusive
      AND aff.affiliate_manager IN ('GoogleAds (444)', 'GoogleAdsNOVO (501)', 'MetaAds (447)', 'MetaAdsNOVO (502)', 'ScoreWire (448)', 'TaboolaAds (481)', 'TikTokAds (449)')

    UNION ALL

    -- Affiliates
    SELECT 'Affiliates' AS Categoria,
           COUNT(DISTINCT ftd.user_id) AS FTDs
    FROM ftd_agg ftd
    INNER JOIN acquisitions_agg acq ON ftd.user_id = acq.user_id
    INNER JOIN affiliates_agg aff ON acq.affiliate_id = aff.affiliate_id
    WHERE ftd.ftd_date >= @data_ini AND ftd.ftd_date < @data_fim_exclusive
      AND aff.affiliate_manager IN (
       'AfiliadosAtivosRev (436)', 'AfiliadosAtivosCpa (434)',
       'AfiliadosAtivosHib (435)', 'DistratoRev (529)',
       'Afiliadosinativos (443)', 'VertexGroup (439)',
       'PeaklineMedia (437)'
      )

    UNION ALL

    -- Organic
    SELECT 'Organic' AS Categoria,
           COUNT(DISTINCT ftd.user_id) AS FTDs
    FROM ftd_agg ftd
    INNER JOIN acquisitions_agg acq ON ftd.user_id = acq.user_id
    WHERE ftd.ftd_date >= @data_ini AND ftd.ftd_date < @data_fim_exclusive
      AND acq.acquisition_channel = 'organic'

    UNION ALL

    -- External Traffic
    SELECT 'External Traffic' AS Categoria,
           COUNT(DISTINCT ftd.user_id) AS FTDs
    FROM ftd_agg ftd
    INNER JOIN acquisitions_agg acq ON ftd.user_id = acq.user_id
    INNER JOIN affiliates_agg aff ON acq.affiliate_id = aff.affiliate_id
    WHERE ftd.ftd_date >= @data_ini AND ftd.ftd_date < @data_fim_exclusive
      AND aff.affiliate_manager = 'parceiroadmin (445)'

    UNION ALL

    -- Influencers
    SELECT 'Influencers',
           COUNT(DISTINCT ftd.user_id) AS FTDs
    FROM ftd_agg ftd
    INNER JOIN acquisitions_agg acq ON ftd.user_id = acq.user_id
    INNER JOIN affiliates_agg aff ON acq.affiliate_id = aff.affiliate_id
    WHERE ftd.ftd_date >= @data_ini AND ftd.ftd_date < @data_fim_exclusive
      AND aff.affiliate_manager = 'InfluenciadoresQuasar (446)'
) AS resultado_final;
