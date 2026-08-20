-- Report Master / Acquisition - All: Turnover All Cohort
-- Lumen: aquisicao paga via dw_lumen.dbo.affiliate_manager_lumen (join por username). >>> VALIDAR channel_type. <<<
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
casino AS (
    SELECT SUM(c.turnover) AS turnover_casino
    FROM casino_agg_hourly c WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = c.user_id
    INNER JOIN manager_lumen_by_username am ON a.affiliate_name = am.username
    WHERE c.date_time >= @data_ini AND c.date_time < @data_fim_exclusive
    AND am.channel_type IN ('Tráfego externo', 'Afiliados', 'Influenciadores')
), sports AS (
    SELECT SUM(s.turnover) AS turnover_sportsbook
    FROM sports_agg_hourly s WITH(NOLOCK)
    INNER JOIN acquisitions_agg a WITH(NOLOCK) ON a.user_id = s.user_id
    INNER JOIN manager_lumen_by_username am ON a.affiliate_name = am.username
    WHERE s.date_time >= @data_ini AND s.date_time < @data_fim_exclusive
    AND am.channel_type IN ('Tráfego externo', 'Afiliados', 'Influenciadores')
)
SELECT
    ISNULL(c.turnover_casino, 0) + ISNULL(s.turnover_sportsbook, 0) AS [Turnover All Cohort]
FROM casino c
CROSS JOIN sports s;
