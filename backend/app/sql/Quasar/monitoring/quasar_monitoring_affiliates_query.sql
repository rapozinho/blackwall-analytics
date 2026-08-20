-- Query Monitoring Quasar bet (completa)   CORRIGIDO
DECLARE @data_ini_mes1 DATE = '{start1}';
DECLARE @data_fim_mes1 DATE = '{end1}';

DECLARE @data_ini_mes2 DATE = '{start2}';
DECLARE @data_fim_mes2 DATE = '{end2}';

-- Variáveis internas para ajustar o intervalo (não precisa mexer aqui)
DECLARE @data_fim_exclusive1 DATE = DATEADD(day, 1, @data_fim_mes1);
DECLARE @data_fim_exclusive2 DATE = DATEADD(day, 1, @data_fim_mes2);

WITH user_ggr AS (
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
ftd_counts AS (
    SELECT
        aff.Affiliate_Id, -- ADICIONADO
        aff.affiliate_name,
        aff.affiliate_manager,
        CASE
            WHEN ftd.ftd_date >= @data_ini_mes1 AND ftd.ftd_date < @data_fim_exclusive1 THEN 'mes1'
            WHEN ftd.ftd_date >= @data_ini_mes2 AND ftd.ftd_date < @data_fim_exclusive2 THEN 'mes2'
        END AS periodo,
        COUNT(DISTINCT ftd.user_id) AS FTD_QTD
    FROM ftd_agg ftd WITH(NOLOCK)
    INNER JOIN acquisitions_agg acq WITH(NOLOCK) ON ftd.user_id = acq.user_id
    INNER JOIN affiliates_agg aff WITH(NOLOCK) ON acq.Affiliate_Id = aff.Affiliate_Id
    WHERE (ftd.ftd_date >= @data_ini_mes1 AND ftd.ftd_date < @data_fim_exclusive1)
       OR (ftd.ftd_date >= @data_ini_mes2 AND ftd.ftd_date < @data_fim_exclusive2)
    AND aff.affiliate_name IS NOT NULL
    GROUP BY aff.Affiliate_Id, -- ADICIONADO
             aff.affiliate_name,
             aff.affiliate_manager,
             CASE
                 WHEN ftd.ftd_date >= @data_ini_mes1 AND ftd.ftd_date < @data_fim_exclusive1 THEN 'mes1'
                 WHEN ftd.ftd_date >= @data_ini_mes2 AND ftd.ftd_date < @data_fim_exclusive2 THEN 'mes2'
             END
),
-- GGR data now includes both average and total GGR for relevant FTD users
ggr_data AS ( 
    SELECT
        a.Affiliate_Id, -- ADICIONADO
        a.affiliate_name,
        a.affiliate_manager,
        CAST(SUM(CASE WHEN ug.periodo = 'mes1' THEN ug.GGR_Total ELSE 0 END) / NULLIF(COUNT(DISTINCT CASE WHEN ug.periodo = 'mes1' AND f.FTD_Date >= @data_ini_mes1 AND f.FTD_Date < @data_fim_exclusive1 THEN r.User_Id END), 0) AS DECIMAL(10, 2)) AS Avg_GGR_Mes1,
        SUM(CASE WHEN ug.periodo = 'mes1' THEN ug.GGR_Total ELSE 0 END) AS GGR_Total_Mes1, 
        CAST(SUM(CASE WHEN ug.periodo = 'mes2' THEN ug.GGR_Total ELSE 0 END) / NULLIF(COUNT(DISTINCT CASE WHEN ug.periodo = 'mes2' AND f.FTD_Date >= @data_ini_mes2 AND f.FTD_Date < @data_fim_exclusive2 THEN r.User_Id END), 0) AS DECIMAL(10, 2)) AS Avg_GGR_Mes2,
        SUM(CASE WHEN ug.periodo = 'mes2' THEN ug.GGR_Total ELSE 0 END) AS GGR_Total_Mes2 
    FROM acquisitions_agg r WITH(NOLOCK)
    INNER JOIN affiliates_agg a WITH(NOLOCK) ON a.Affiliate_Id = r.Affiliate_Id
    INNER JOIN user_ggr ug ON ug.User_Id = r.User_Id
    INNER JOIN ftd_agg f WITH(NOLOCK) ON f.User_Id = r.User_Id AND ((f.FTD_Date >= @data_ini_mes1 AND f.FTD_Date < @data_fim_exclusive1) OR (f.FTD_Date >= @data_ini_mes2 AND f.FTD_Date < @data_fim_exclusive2))
    WHERE (ug.periodo = 'mes1' AND f.FTD_Date >= @data_ini_mes1 AND f.FTD_Date < @data_fim_exclusive1)
       OR (ug.periodo = 'mes2' AND f.FTD_Date >= @data_ini_mes2 AND f.FTD_Date < @data_fim_exclusive2)
    GROUP BY a.Affiliate_Id, -- ADICIONADO
             a.affiliate_name, 
             a.affiliate_manager
),
-- Deposit data now includes both average and total Deposits for relevant FTD users
dep_data AS (
    SELECT
        a.Affiliate_Id, -- ADICIONADO
        a.affiliate_name,
        a.affiliate_manager,
        CAST(SUM(CASE WHEN dep.Date_Agg >= @data_ini_mes1 AND dep.Date_Agg < @data_fim_exclusive1 THEN dep.Deposits_Amount ELSE 0 END) /
             NULLIF(COUNT(DISTINCT CASE WHEN f_mes1.User_Id IS NOT NULL AND dep.Date_Agg >= @data_ini_mes1 AND dep.Date_Agg < @data_fim_exclusive1 THEN r.User_Id END), 0)
        AS DECIMAL(10, 2)) AS Avg_Dep_Mes1,
        SUM(CASE WHEN dep.Date_Agg >= @data_ini_mes1 AND dep.Date_Agg < @data_fim_exclusive1 THEN dep.Deposits_Amount ELSE 0 END) AS Dep_Total_Mes1, 
        CAST(SUM(CASE WHEN dep.Date_Agg >= @data_ini_mes2 AND dep.Date_Agg < @data_fim_exclusive2 THEN dep.Deposits_Amount ELSE 0 END) /
             NULLIF(COUNT(DISTINCT CASE WHEN f_mes2.User_Id IS NOT NULL AND dep.Date_Agg >= @data_ini_mes2 AND dep.Date_Agg < @data_fim_exclusive2 THEN r.User_Id END), 0)
        AS DECIMAL(10, 2)) AS Avg_Dep_Mes2,
        SUM(CASE WHEN dep.Date_Agg >= @data_ini_mes2 AND dep.Date_Agg < @data_fim_exclusive2 THEN dep.Deposits_Amount ELSE 0 END) AS Dep_Total_Mes2 
    FROM acquisitions_agg r WITH(NOLOCK)
    INNER JOIN affiliates_agg a WITH(NOLOCK) ON a.Affiliate_Id = r.Affiliate_Id
    INNER JOIN payments_agg_hourly dep ON dep.User_Id = r.User_Id
    LEFT JOIN ftd_agg f_mes1 WITH(NOLOCK) ON f_mes1.User_Id = r.User_Id AND f_mes1.FTD_Date >= @data_ini_mes1 AND f_mes1.FTD_Date < @data_fim_exclusive1
    LEFT JOIN ftd_agg f_mes2 WITH(NOLOCK) ON f_mes2.User_Id = r.User_Id AND f_mes2.FTD_Date >= @data_ini_mes2 AND f_mes2.FTD_Date < @data_fim_exclusive2
    WHERE (dep.Date_Agg >= @data_ini_mes1 AND dep.Date_Agg < @data_fim_exclusive1 AND f_mes1.User_Id IS NOT NULL)
       OR (dep.Date_Agg >= @data_ini_mes2 AND dep.Date_Agg < @data_fim_exclusive2 AND f_mes2.User_Id IS NOT NULL)
    AND dep.status = 'Completed'
    GROUP BY a.Affiliate_Id, -- ADICIONADO
             a.affiliate_name, 
             a.affiliate_manager
)
SELECT
    COALESCE(g.Affiliate_Id, d.Affiliate_Id, f_mes1.Affiliate_Id, f_mes2.Affiliate_Id) AS Affiliate_Id, -- PRIMEIRA COLUNA
    COALESCE(g.affiliate_name, d.affiliate_name, f_mes1.affiliate_name, f_mes2.affiliate_name) AS affiliate_name,
    COALESCE(g.affiliate_manager, d.affiliate_manager, f_mes1.affiliate_manager, f_mes2.affiliate_manager) AS affiliate_manager,

    --Mes1
    COALESCE(f_mes1.FTD_QTD, 0) AS FTD_QTD_Mes1,
    COALESCE(g.GGR_Total_Mes1, 0.00) AS Total_GGR_Mes1, 
    COALESCE(g.Avg_GGR_Mes1, 0.00) AS Avg_GGR_Mes1,
    COALESCE(d.Dep_Total_Mes1, 0.00) AS Total_Dep_Mes1,
    COALESCE(d.Avg_Dep_Mes1, 0.00) AS Avg_Dep_Mes1,
    
    --Mes2
    COALESCE(f_mes2.FTD_QTD, 0) AS FTD_QTD_Mes2,
    CAST((CASE 
            WHEN COALESCE(f_mes1.FTD_QTD, 0) = 0 THEN 0.00 
            ELSE ((COALESCE(f_mes2.FTD_QTD, 0) - COALESCE(f_mes1.FTD_QTD, 0)) * 100.0 / COALESCE(f_mes1.FTD_QTD, 1)) 
        END) AS DECIMAL(10,2)) AS [Var % FTDs],


    COALESCE(g.GGR_Total_Mes2, 0.00) AS Total_GGR_Mes2, 
    COALESCE(g.Avg_GGR_Mes2, 0.00) AS Avg_GGR_Mes2,
    CAST((CASE 
        WHEN COALESCE(g.Avg_GGR_Mes1, 0.00) = 0 THEN 0.00 
        ELSE ((COALESCE(g.Avg_GGR_Mes2, 0.00) - COALESCE(g.Avg_GGR_Mes1, 0.00)) / COALESCE(g.Avg_GGR_Mes1, 0.00)) * 100 
    END) AS DECIMAL(10,2)) AS [Var % GGR],

    COALESCE(d.Dep_Total_Mes2, 0.00) AS Total_Dep_Mes2, 
    COALESCE(d.Avg_Dep_Mes2, 0.00) AS Avg_Dep_Mes2,
    CAST((CASE 
            WHEN COALESCE(d.Avg_Dep_Mes1, 0.00) = 0 THEN 0.00 
            ELSE ((COALESCE(d.Avg_Dep_Mes2, 0.00) - COALESCE(d.Avg_Dep_Mes1, 0.00)) / COALESCE(d.Avg_Dep_Mes1, 0.00)) * 100 
        END) AS DECIMAL(10,2)) AS [Var % Dep]
    
   
FROM ggr_data g
FULL OUTER JOIN dep_data d ON g.affiliate_name = d.affiliate_name AND g.affiliate_manager = d.affiliate_manager
FULL OUTER JOIN (SELECT Affiliate_Id, affiliate_name, affiliate_manager, FTD_QTD FROM ftd_counts WHERE periodo = 'mes1') f_mes1 ON COALESCE(g.affiliate_name, d.affiliate_name) = f_mes1.affiliate_name AND COALESCE(g.affiliate_manager, d.affiliate_manager) = f_mes1.affiliate_manager
FULL OUTER JOIN (SELECT Affiliate_Id, affiliate_name, affiliate_manager, FTD_QTD FROM ftd_counts WHERE periodo = 'mes2') f_mes2 ON COALESCE(g.affiliate_name, d.affiliate_name, f_mes1.affiliate_name) = f_mes2.affiliate_name AND COALESCE(g.affiliate_manager, d.affiliate_manager, f_mes1.affiliate_manager) = f_mes2.affiliate_manager
ORDER BY COALESCE(g.affiliate_manager, d.affiliate_manager, f_mes1.affiliate_manager, f_mes2.affiliate_manager),
         COALESCE(g.affiliate_name, d.affiliate_name, f_mes1.affiliate_name, f_mes2.affiliate_name);