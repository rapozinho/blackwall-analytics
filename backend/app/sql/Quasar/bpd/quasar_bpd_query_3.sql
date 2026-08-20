DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';

-- Variável interna para ajustar o intervalo (não precisa mexer aqui)
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

-- Filtra os depósitos no período uma única vez para melhor performance
WITH deposits_in_period AS (
    SELECT User_Id, Deposits_Amount
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE Date_Agg >= @data_ini AND Date_Agg < @data_fim_exclusive
    AND status = 'Completed'
)
SELECT 
    categoria, 
    SUM(Deposits_Amount) AS dep_all_cohort
FROM (
    -- Internal Traffic
    SELECT 'Internal Traffic' AS categoria, dep.Deposits_Amount
    FROM acquisitions_agg acq
    INNER JOIN affiliates_agg aff ON acq.affiliate_id = aff.affiliate_id
    INNER JOIN deposits_in_period dep ON dep.User_Id = acq.User_Id
    WHERE aff.affiliate_manager IN (
        'GoogleAds (444)', 'GoogleAdsNOVO (501)', 'MetaAds (447)', 'MetaAdsNOVO (502)', 'ScoreWire (448)', 'TaboolaAds (481)', 'TikTokAds (449)'
    )

    UNION ALL

    -- Affiliates
    SELECT 'Affiliates' AS categoria, dep.Deposits_Amount
    FROM acquisitions_agg acq
    INNER JOIN affiliates_agg aff ON acq.affiliate_id = aff.affiliate_id
    INNER JOIN deposits_in_period dep ON dep.User_Id = acq.User_Id
    WHERE aff.affiliate_manager IN (
        'AfiliadosAtivosRev (436)', 'AfiliadosAtivosCpa (434)',
        'AfiliadosAtivosHib (435)', 'DistratoRev (529)',
        'Afiliadosinativos (443)', 'VertexGroup (439)',
        'PeaklineMedia (437)'
    )

    UNION ALL

    -- Organic
    SELECT 'Organic' AS categoria, dep.Deposits_Amount
    FROM acquisitions_agg acq
    INNER JOIN deposits_in_period dep ON dep.User_Id = acq.User_Id
    WHERE acq.acquisition_channel = 'organic'

    UNION ALL

    -- External Traffic
    SELECT 'External Traffic' AS categoria, dep.Deposits_Amount
    FROM acquisitions_agg acq
    INNER JOIN affiliates_agg aff ON acq.affiliate_id = aff.affiliate_id
    INNER JOIN deposits_in_period dep ON dep.User_Id = acq.User_Id
    WHERE aff.affiliate_manager = 'parceiroadmin (445)'

    UNION ALL

    -- Influencers
    SELECT 'Influencers' AS categoria, dep.Deposits_Amount
    FROM acquisitions_agg acq
    INNER JOIN affiliates_agg aff ON acq.affiliate_id = aff.affiliate_id
    INNER JOIN deposits_in_period dep ON dep.User_Id = acq.User_Id
    WHERE aff.affiliate_manager = 'InfluenciadoresQuasar (446)'
) AS final_data
GROUP BY categoria;