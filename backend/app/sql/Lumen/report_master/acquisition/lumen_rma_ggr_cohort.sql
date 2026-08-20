-- Report Master / Acquisition - All: GGR Cohort
-- Lumen: aquisicao paga resolvida via dw_lumen.dbo.affiliate_manager_lumen (join por username),
--   diferente da Quasar (affiliates_agg + Affiliate_Manager IN (...)).
--   channel_type IN ('Trafego externo','Afiliados','Influenciadores') = canais externos pagos
--   (exclui Organico e Marketing interno). >>> VALIDAR se esse conjunto reflete o cohort pago desejado. <<<
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH manager_lumen_by_username AS (
    SELECT *
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY username ORDER BY id DESC) AS rn
        FROM dw_lumen.dbo.affiliate_manager_lumen WITH(NOLOCK)
        WHERE username IS NOT NULL
    ) x
    WHERE rn = 1
),
Casino AS (
    SELECT SUM(c.ggr) AS casino_ggr
    FROM casino_agg_hourly c WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = c.user_id
    INNER JOIN manager_lumen_by_username am ON a.affiliate_name = am.username
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = c.user_id
    WHERE c.date_time >= @data_ini AND c.date_time < @data_fim_exclusive
    AND f.FTD_Date >= @data_ini AND f.FTD_Date < @data_fim_exclusive
    AND am.channel_type IN ('Tráfego externo', 'Afiliados', 'Influenciadores')
),
Sports AS (
    SELECT SUM(s.ggr) AS sports_ggr
    FROM sports_agg_hourly s WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = s.user_id
    INNER JOIN manager_lumen_by_username am ON a.affiliate_name = am.username
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.user_id = s.user_id
    WHERE s.date_time >= @data_ini AND s.date_time < @data_fim_exclusive
    AND f.FTD_Date >= @data_ini AND f.FTD_Date < @data_fim_exclusive
    AND am.channel_type IN ('Tráfego externo', 'Afiliados', 'Influenciadores')
)
SELECT
    ISNULL(c.casino_ggr, 0) + ISNULL(s.sports_ggr, 0) AS [GGR Cohort]
FROM Casino c
CROSS JOIN Sports s;
