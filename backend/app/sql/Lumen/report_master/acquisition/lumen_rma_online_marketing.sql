-- Report Master / Acquisition - All: Online Marketing / FTDs - Online
-- Lumen: categorias derivadas do schema proprio (affiliate_manager_lumen + acquisition_channel),
--   espelhando a taxonomia canonica usada em lumen_bpd_query_1 (channel_type + Organic).
--   Google Ads e priorizado antes de 'Trafego externo' para evitar dupla contagem.
--   >>> VALIDAR: conjunto/ordem de categorias e mapeamento de channel_type. <<<
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
Categories AS (
    SELECT [Online Marketing], sort_order
    FROM (VALUES
        ('Google Ads', 1),
        ('External Traffic', 2),
        ('Affiliates', 3),
        ('Influencers', 4),
        ('Internal Traffic', 5),
        ('Organic', 6)
    ) AS t([Online Marketing], sort_order)
),
BaseData AS (
    SELECT
        CASE
            WHEN acq.acquisition_channel = 'Others' THEN 'Organic'
            WHEN am.affiliate_manager = 'GoogleAds' THEN 'Google Ads'
            WHEN am.channel_type = 'Tráfego externo' THEN 'External Traffic'
            WHEN am.channel_type = 'Afiliados' THEN 'Affiliates'
            WHEN am.channel_type = 'Influenciadores' THEN 'Influencers'
            WHEN am.channel_type = 'Marketing interno' THEN 'Internal Traffic'
        END AS [Online Marketing],
        f.User_Id
    FROM ftd_agg f WITH(NOLOCK)
    INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON f.User_Id = acq.user_id
    LEFT JOIN manager_lumen_by_username am ON acq.affiliate_name = am.username
    WHERE f.FTD_Date >= @data_ini AND f.FTD_Date < @data_fim_exclusive
)
SELECT
    c.[Online Marketing],
    COUNT(DISTINCT b.User_Id) AS [FTDs - Online]
FROM Categories c
LEFT JOIN BaseData b ON c.[Online Marketing] = b.[Online Marketing]
GROUP BY c.[Online Marketing], c.sort_order
ORDER BY c.sort_order;
