-- Monitoring - Zephyr (Batendo com o Bi!)

DECLARE @data_ini_mes1 DATE = '{start1}';
DECLARE @data_fim_mes1 DATE = '{end1}';

DECLARE @data_ini_mes2 DATE = '{start2}';
DECLARE @data_fim_mes2 DATE = '{end2}';

-- Variáveis internas
DECLARE @data_fim_exclusive1 DATE = DATEADD(day, 1, @data_fim_mes1);
DECLARE @data_fim_exclusive2 DATE = DATEADD(day, 1, @data_fim_mes2);

-- CTE para pegar o manager mais recente por affiliate_id na nova tabela
WITH affiliate_manager_dedup AS (
    SELECT affiliate_id, affiliate_manager
    FROM (
        SELECT affiliate_id,
               affiliate_manager,
               ROW_NUMBER() OVER (PARTITION BY affiliate_id ORDER BY update_time DESC) AS rn
        FROM affiliates_Agg WITH(NOLOCK)
    ) x
    WHERE rn = 1
),

-- CTE para mapear Affiliate_Name para o affiliate_manager
AffiliateManagerMapping AS (
    SELECT DISTINCT
        aff.Affiliate_Name,
        am.affiliate_manager AS affiliate_manager
    FROM affiliates_agg aff WITH(NOLOCK)
    JOIN affiliate_manager_dedup am ON aff.Affiliate_Id = am.affiliate_id
    WHERE aff.Affiliate_Name IS NOT NULL
),

-- CTE para associar usuários ao nome do afiliado (SEM ID AQUI PARA NÃO QUEBRAR O GGR)
UserAffiliateName AS (
    SELECT DISTINCT
        ftd.user_id,
        aff.Affiliate_Id, -- Mantemos aqui apenas para extração posterior
        aff.Affiliate_Name, 
        CASE
            WHEN ftd.ftd_date >= @data_ini_mes1 AND ftd.ftd_date < @data_fim_exclusive1 THEN 'mes1'
            WHEN ftd.ftd_date >= @data_ini_mes2 AND ftd.ftd_date < @data_fim_exclusive2 THEN 'mes2'
        END AS periodo
    FROM ftd_agg ftd WITH(NOLOCK)
    INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
    INNER JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
    WHERE (ftd.ftd_date >= @data_ini_mes1 AND ftd.ftd_date < @data_fim_exclusive1)
       OR (ftd.ftd_date >= @data_ini_mes2 AND ftd.ftd_date < @data_fim_exclusive2)
    AND aff.Affiliate_Name IS NOT NULL
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

ftd_counts_by_period AS (
    SELECT
        uan.Affiliate_Name, 
        uan.periodo,
        COUNT(DISTINCT uan.user_id) AS FTD_QTD
    FROM UserAffiliateName uan
    GROUP BY uan.Affiliate_Name, uan.periodo
),

ggr_avg_by_period AS (
    SELECT
        uan.Affiliate_Name,
        uan.periodo,
        CAST(SUM(ug.GGR_Total) / NULLIF(COUNT(DISTINCT uan.User_Id), 0) AS DECIMAL(10, 2)) AS Avg_GGR
    FROM UserAffiliateName uan
    INNER JOIN UserGGR ug ON uan.User_Id = ug.User_Id AND uan.periodo = ug.periodo
    GROUP BY uan.Affiliate_Name, uan.periodo
),

ggr_total_by_period AS (
    SELECT
        uan.Affiliate_Name,
        uan.periodo,
        SUM(ug.GGR_Total) AS Total_GGR
    FROM UserAffiliateName uan
    INNER JOIN UserGGR ug ON uan.User_Id = ug.User_Id AND uan.periodo = ug.periodo
    GROUP BY uan.Affiliate_Name, uan.periodo
),

dep_avg_by_period AS (
    SELECT
        uan.Affiliate_Name,
        uan.periodo,
        CAST(SUM(ud.Deposits_Total) / NULLIF(COUNT(DISTINCT uan.User_Id), 0) AS DECIMAL(10, 2)) AS Avg_Dep
    FROM UserAffiliateName uan
    INNER JOIN UserDeposits ud ON uan.User_Id = ud.User_Id AND uan.periodo = ud.periodo
    GROUP BY uan.Affiliate_Name, uan.periodo
),

dep_total_by_period AS (
    SELECT
        uan.Affiliate_Name,
        uan.periodo,
        SUM(ud.Deposits_Total) AS Total_Dep
    FROM UserAffiliateName uan
    INNER JOIN UserDeposits ud ON uan.User_Id = ud.User_Id AND uan.periodo = ud.periodo
    GROUP BY uan.Affiliate_Name, uan.periodo
)

SELECT
    -- STRING_AGG junta todos os IDs daquele Nome (ex: "16247, 17764") evitando linhas repetidas
    g_base.Affiliate_Ids, 
    g_base.Affiliate_Name,
    amm.affiliate_manager AS Affiliate_Manager,

    --Mes1
    COALESCE(f1.FTD_QTD, 0) AS FTD_QTD_Mes1,
    COALESCE(gt1.Total_GGR, 0.00) AS Total_GGR_Mes1,
    COALESCE(g1.Avg_GGR, 0.00) AS Avg_GGR_Mes1,
    COALESCE(dt1.Total_Dep, 0.00) AS Total_Dep_Mes1,
    COALESCE(d1.Avg_Dep, 0.00) AS Avg_Dep_Mes1,
    
   --Mes2
    COALESCE(f2.FTD_QTD, 0) AS FTD_QTD_Mes2,
    CAST((CASE WHEN COALESCE(f1.FTD_QTD, 0) = 0 THEN 0.00 ELSE (CAST(COALESCE(f2.FTD_QTD, 0) - COALESCE(f1.FTD_QTD, 0) AS FLOAT) / f1.FTD_QTD) * 100 END) AS DECIMAL(10,2)) AS [Var % FTDs],
    COALESCE(gt2.Total_GGR, 0.00) AS Total_GGR_Mes2,
    COALESCE(g2.Avg_GGR, 0.00) AS Avg_GGR_Mes2,
    CAST((CASE WHEN COALESCE(g1.Avg_GGR, 0.00) = 0 THEN 0.00 ELSE ((COALESCE(g2.Avg_GGR, 0.00) - COALESCE(g1.Avg_GGR, 0.00)) / g1.Avg_GGR) * 100 END) AS DECIMAL(10,2)) AS [Var % GGR],
    COALESCE(dt2.Total_Dep, 0.00) AS Total_Dep_Mes2,
    COALESCE(d2.Avg_Dep, 0.00) AS Avg_Dep_Mes2,
    CAST((CASE WHEN COALESCE(d1.Avg_Dep, 0.00) = 0 THEN 0.00 ELSE ((COALESCE(d2.Avg_Dep, 0.00) - COALESCE(d1.Avg_Dep, 0.00)) / d1.Avg_Dep) * 100 END) AS DECIMAL(10,2)) AS [Var % Dep]
    
FROM 
    (
        -- Subquery para agrupar IDs e Nomes únicos
        SELECT 
            Affiliate_Name, 
            STRING_AGG(CAST(Affiliate_Id AS VARCHAR(MAX)), ', ') WITHIN GROUP (ORDER BY Affiliate_Id) AS Affiliate_Ids
        FROM (SELECT DISTINCT Affiliate_Id, Affiliate_Name FROM UserAffiliateName) sub
        GROUP BY Affiliate_Name
    ) AS g_base

LEFT JOIN AffiliateManagerMapping amm ON g_base.Affiliate_Name = amm.Affiliate_Name
LEFT JOIN ggr_avg_by_period g1 ON g_base.Affiliate_Name = g1.Affiliate_Name AND g1.periodo = 'mes1'
LEFT JOIN ggr_total_by_period gt1 ON g_base.Affiliate_Name = gt1.Affiliate_Name AND gt1.periodo = 'mes1'
LEFT JOIN ggr_avg_by_period g2 ON g_base.Affiliate_Name = g2.Affiliate_Name AND g2.periodo = 'mes2'
LEFT JOIN ggr_total_by_period gt2 ON g_base.Affiliate_Name = gt2.Affiliate_Name AND gt2.periodo = 'mes2'
LEFT JOIN dep_avg_by_period d1 ON g_base.Affiliate_Name = d1.Affiliate_Name AND d1.periodo = 'mes1'
LEFT JOIN dep_total_by_period dt1 ON g_base.Affiliate_Name = dt1.Affiliate_Name AND dt1.periodo = 'mes1'
LEFT JOIN dep_avg_by_period d2 ON g_base.Affiliate_Name = d2.Affiliate_Name AND d2.periodo = 'mes2'
LEFT JOIN dep_total_by_period dt2 ON g_base.Affiliate_Name = dt2.Affiliate_Name AND dt2.periodo = 'mes2'
LEFT JOIN ftd_counts_by_period f1 ON g_base.Affiliate_Name = f1.Affiliate_Name AND f1.periodo = 'mes1'
LEFT JOIN ftd_counts_by_period f2 ON g_base.Affiliate_Name = f2.Affiliate_Name AND f2.periodo = 'mes2'

ORDER BY 
    amm.affiliate_manager;