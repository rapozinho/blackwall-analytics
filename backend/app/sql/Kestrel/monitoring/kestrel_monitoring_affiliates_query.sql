DECLARE @data_ini_mes1 DATE = '{start1}';
DECLARE @data_fim_mes1 DATE = '{end1}';

DECLARE @data_ini_mes2 DATE = '{start2}';
DECLARE @data_fim_mes2 DATE = '{end2}';

DECLARE @data_fim_exclusive1 DATE = DATEADD(day, 1, @data_fim_mes1);
DECLARE @data_fim_exclusive2 DATE = DATEADD(day, 1, @data_fim_mes2);

-- 1. Tabela Lumen preparada
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

UserAffiliateManager AS (
    SELECT
        user_id,
        affiliate_id,      -- ADICIONADO AQUI PARA TRAFEGAR
        affiliate_name,    
        affiliate_manager, 
        periodo
    FROM (
        SELECT DISTINCT
            ftd.user_id,
            acq.affiliate_id, -- ADICIONADO AQUI (ORIGEM)
            -- DEFINIÇÃO DO NOME DO AFILIADO
            CASE
                WHEN acq.acquisition_channel = 'Organic' THEN 'Organic'
                ELSE acq.affiliate_name 
            END AS affiliate_name,

            -- DEFINIÇÃO DO GERENTE
            CASE
                WHEN acq.acquisition_channel = 'Organic' THEN 'Organic'
                WHEN acq.affiliate_name = 'GoogleAds' THEN 'GoogleAds'
                WHEN acq.affiliate_name = 'TaboolaAds' THEN 'TaboolaAds'
                WHEN acq.affiliate_name = 'MetaAds' THEN 'MetaAds'
                WHEN acq.affiliate_name = 'ScoreWireAds' THEN 'ScoreWireAds'
                WHEN acq.affiliate_name LIKE '%CriteoAds%' THEN 'CriteoAds'
                ELSE mb.affiliate_manager
            END AS affiliate_manager,

            CASE
                WHEN ftd.ftd_date >= @data_ini_mes1 AND ftd.ftd_date < @data_fim_exclusive1 THEN 'mes1'
                WHEN ftd.ftd_date >= @data_ini_mes2 AND ftd.ftd_date < @data_fim_exclusive2 THEN 'mes2'
            END AS periodo
        FROM ftd_agg ftd WITH(NOLOCK)
        INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
        
        LEFT JOIN manager_lumen_by_username mb ON acq.affiliate_name = mb.username

        WHERE
            (ftd.ftd_date >= @data_ini_mes1 AND ftd.ftd_date < @data_fim_exclusive1) OR
            (ftd.ftd_date >= @data_ini_mes2 AND ftd.ftd_date < @data_fim_exclusive2)
    ) AS SubQuery
    WHERE affiliate_manager IS NOT NULL 
),
UserGGR AS (
    SELECT
        c.User_Id,
        CASE
            WHEN c.Date_Agg >= @data_ini_mes1 AND c.Date_Agg < @data_fim_exclusive1 THEN 'mes1'
            WHEN c.Date_Agg >= @data_ini_mes2 AND c.Date_Agg < @data_fim_exclusive2 THEN 'mes2'
        END AS periodo,
        SUM(c.GGR) AS GGR_Total
    FROM casino_agg_hourly c WITH(NOLOCK)
    WHERE (c.Date_Agg >= @data_ini_mes1 AND c.Date_Agg < @data_fim_exclusive1)
       OR (c.Date_Agg >= @data_ini_mes2 AND c.Date_Agg < @data_fim_exclusive2)
    GROUP BY c.User_Id,
             CASE
                 WHEN c.Date_Agg >= @data_ini_mes1 AND c.Date_Agg < @data_fim_exclusive1 THEN 'mes1'
                 WHEN c.Date_Agg >= @data_ini_mes2 AND c.Date_Agg < @data_fim_exclusive2 THEN 'mes2'
             END
    UNION ALL
    SELECT
        s.User_Id,
        CASE
            WHEN s.Date_Agg >= @data_ini_mes1 AND s.Date_Agg < @data_fim_exclusive1 THEN 'mes1'
            WHEN s.Date_Agg >= @data_ini_mes2 AND s.Date_Agg < @data_fim_exclusive2 THEN 'mes2'
        END AS periodo,
        SUM(GGR) AS GGR_Total
    FROM sports_agg_hourly s WITH(NOLOCK)
    WHERE (s.Date_Agg >= @data_ini_mes1 AND s.Date_Agg < @data_fim_exclusive1)
       OR (s.Date_Agg >= @data_ini_mes2 AND s.Date_Agg < @data_fim_exclusive2)
    GROUP BY s.User_Id,
             CASE
                 WHEN s.Date_Agg >= @data_ini_mes1 AND s.Date_Agg < @data_fim_exclusive1 THEN 'mes1'
                 WHEN s.Date_Agg >= @data_ini_mes2 AND s.Date_Agg < @data_fim_exclusive2 THEN 'mes2'
             END
),
UserDeposits AS (
    SELECT
        dep.User_Id,
        CASE
            WHEN dep.Date_Agg >= @data_ini_mes1 AND dep.Date_Agg < @data_fim_exclusive1 THEN 'mes1'
            WHEN dep.Date_Agg >= @data_ini_mes2 AND dep.Date_Agg < @data_fim_exclusive2 THEN 'mes2'
        END AS periodo,
        SUM(dep.Deposits_Amount) AS Deposits_Total
    FROM payments_agg_hourly dep WITH(NOLOCK)
    WHERE (dep.Date_Agg >= @data_ini_mes1 AND dep.Date_Agg < @data_fim_exclusive1)
       OR (dep.Date_Agg >= @data_ini_mes2 AND dep.Date_Agg < @data_fim_exclusive2)
    AND dep.status = 'Completed'
    GROUP BY dep.User_Id,
             CASE
                 WHEN dep.Date_Agg >= @data_ini_mes1 AND dep.Date_Agg < @data_fim_exclusive1 THEN 'mes1'
                 WHEN dep.Date_Agg >= @data_ini_mes2 AND dep.Date_Agg < @data_fim_exclusive2 THEN 'mes2'
             END
),
-- AGORA OS AGRUPAMENTOS SÃO POR NOME E GERENTE
ftd_counts_by_period AS (
    SELECT
        uam.affiliate_name,
        uam.affiliate_manager,
        uam.periodo,
        COUNT(DISTINCT uam.user_id) AS FTD_QTD
    FROM UserAffiliateManager uam
    GROUP BY uam.affiliate_name, uam.affiliate_manager, uam.periodo
),
ggr_avg_by_period AS (
    SELECT
        uam.affiliate_name,
        uam.affiliate_manager,
        uam.periodo,
        CAST(SUM(ug.GGR_Total) / NULLIF(COUNT(DISTINCT uam.User_Id), 0) AS DECIMAL(10, 2)) AS Avg_GGR
    FROM UserAffiliateManager uam
    INNER JOIN UserGGR ug ON uam.User_Id = ug.User_Id AND uam.periodo = ug.periodo
    GROUP BY uam.affiliate_name, uam.affiliate_manager, uam.periodo
),
ggr_total_by_period AS (
    SELECT
        uam.affiliate_name,
        uam.affiliate_manager,
        uam.periodo,
        SUM(ug.GGR_Total) AS Total_GGR
    FROM UserAffiliateManager uam
    INNER JOIN UserGGR ug ON uam.User_Id = ug.User_Id AND uam.periodo = ug.periodo
    GROUP BY uam.affiliate_name, uam.affiliate_manager, uam.periodo
),
dep_avg_by_period AS (
    SELECT
        uam.affiliate_name,
        uam.affiliate_manager,
        uam.periodo,
        CAST(SUM(ud.Deposits_Total) / NULLIF(COUNT(DISTINCT uam.User_Id), 0) AS DECIMAL(10, 2)) AS Avg_Dep
    FROM UserAffiliateManager uam
    INNER JOIN UserDeposits ud ON uam.User_Id = ud.User_Id AND uam.periodo = ud.periodo
    GROUP BY uam.affiliate_name, uam.affiliate_manager, uam.periodo
),
dep_total_by_period AS (
    SELECT
        uam.affiliate_name,
        uam.affiliate_manager,
        uam.periodo,
        SUM(ud.Deposits_Total) AS Total_Dep
    FROM UserAffiliateManager uam
    INNER JOIN UserDeposits ud ON uam.User_Id = ud.User_Id AND uam.periodo = ud.periodo
    GROUP BY uam.affiliate_name, uam.affiliate_manager, uam.periodo
)
SELECT
    g_base.affiliate_id, -- ADICIONADO CONFORME PEDIDO
    
    -- Identificação Principal
    COALESCE(g_base.affiliate_name, f1.affiliate_name, f2.affiliate_name) AS Affiliate_Name,
    -- Gerente Responsável (Informativo)
    COALESCE(g_base.affiliate_manager, f1.affiliate_manager, f2.affiliate_manager) AS Affiliate_Manager,

    --Mes1
    COALESCE(f1.FTD_QTD, 0) AS FTD_QTD_Mes1,
    COALESCE(g1.Avg_GGR, 0.00) AS Avg_GGR_Mes1,
    COALESCE(gt1.Total_GGR, 0.00) AS Total_GGR_Mes1,
    COALESCE(d1.Avg_Dep, 0.00) AS Avg_Dep_Mes1,
    COALESCE(dt1.Total_Dep, 0.00) AS Total_Dep_Mes1,

    --Mes2
    COALESCE(f2.FTD_QTD, 0) AS FTD_QTD_Mes2,
    COALESCE(g2.Avg_GGR, 0.00) AS Avg_GGR_Mes2,
    COALESCE(gt2.Total_GGR, 0.00) AS Total_GGR_Mes2,
    COALESCE(d2.Avg_Dep, 0.00) AS Avg_Dep_Mes2,
    COALESCE(dt2.Total_Dep, 0.00) AS Total_Dep_Mes2,

    --Variação %
    CAST(CASE WHEN COALESCE(f1.FTD_QTD, 0) = 0 THEN 0 ELSE (CAST(COALESCE(f2.FTD_QTD, 0) AS FLOAT) - COALESCE(f1.FTD_QTD, 0)) * 100.0 / COALESCE(f1.FTD_QTD, 1) END AS DECIMAL(10,2)) AS [Var % FTDs],
    CAST((CASE WHEN COALESCE(g1.Avg_GGR, 0.00) = 0 THEN 0.00 ELSE ((COALESCE(g2.Avg_GGR, 0.00) - COALESCE(g1.Avg_GGR, 0.00)) / NULLIF(COALESCE(g1.Avg_GGR, 0.00), 0)) * 100 END) AS DECIMAL(10,2)) AS [Var % GGR],
    CAST((CASE WHEN COALESCE(d1.Avg_Dep, 0.00) = 0 THEN 0.00 ELSE ((COALESCE(d2.Avg_Dep, 0.00) - COALESCE(d1.Avg_Dep, 0.00)) / NULLIF(COALESCE(d1.Avg_Dep, 0.00), 0)) * 100 END) AS DECIMAL(10,2)) AS [Var % Dep]

FROM (SELECT DISTINCT affiliate_id, affiliate_name, affiliate_manager FROM UserAffiliateManager) AS g_base -- affiliate_id ADICIONADO AQUI

LEFT JOIN ggr_avg_by_period g1 ON g_base.affiliate_name = g1.affiliate_name AND g1.periodo = 'mes1'
LEFT JOIN ggr_total_by_period gt1 ON g_base.affiliate_name = gt1.affiliate_name AND gt1.periodo = 'mes1'
LEFT JOIN ggr_avg_by_period g2 ON g_base.affiliate_name = g2.affiliate_name AND g2.periodo = 'mes2'
LEFT JOIN ggr_total_by_period gt2 ON g_base.affiliate_name = gt2.affiliate_name AND gt2.periodo = 'mes2'
LEFT JOIN dep_avg_by_period d1 ON g_base.affiliate_name = d1.affiliate_name AND d1.periodo = 'mes1'
LEFT JOIN dep_total_by_period dt1 ON g_base.affiliate_name = dt1.affiliate_name AND dt1.periodo = 'mes1'
LEFT JOIN dep_avg_by_period d2 ON g_base.affiliate_name = d2.affiliate_name AND d2.periodo = 'mes2'
LEFT JOIN dep_total_by_period dt2 ON g_base.affiliate_name = dt2.affiliate_name AND dt2.periodo = 'mes2'
LEFT JOIN ftd_counts_by_period f1 ON g_base.affiliate_name = f1.affiliate_name AND f1.periodo = 'mes1'
LEFT JOIN ftd_counts_by_period f2 ON g_base.affiliate_name = f2.affiliate_name AND f2.periodo = 'mes2'
ORDER BY Affiliate_Name;