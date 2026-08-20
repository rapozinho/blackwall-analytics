-- Overview / mix por canal de aquisicao — alimenta a pizza de aquisicao.
-- Mesma logica do Big Picture Distribution (FTDs por canal), acrescida de GGR e
-- registros para o donut ter valor e volume na mesma fatia.
DECLARE @ini DATE = '{start1}';
DECLARE @fim DATE = '{end1}';
DECLARE @fimx DATETIME = DATEADD(day, 1, @fim);

WITH ggr_usuario AS (
    SELECT User_Id, SUM(ggr) AS ggr, SUM(turnover) AS turnover
    FROM (
        SELECT User_Id, SUM(GGR) AS ggr, SUM(Turnover) AS turnover
        FROM casino_agg_hourly WITH(NOLOCK)
        WHERE Date_Time >= @ini AND Date_Time < @fimx
        GROUP BY User_Id
        UNION ALL
        SELECT User_Id, SUM(GGR), SUM(Turnover)
        FROM sports_agg_hourly WITH(NOLOCK)
        WHERE Date_Time >= @ini AND Date_Time < @fimx
        GROUP BY User_Id
    ) t
    GROUP BY User_Id
),
-- Canal vem do cadastro (all-time); o recorte de periodo esta nas metricas.
por_canal AS (
    SELECT
        ISNULL(NULLIF(LTRIM(RTRIM(a.Acquisition_Channel)), ''), 'Não informado') AS canal,
        COUNT(DISTINCT CASE WHEN a.Registration_Date >= @ini AND a.Registration_Date <= @fim
                            THEN a.User_Id END)                                  AS registros,
        COUNT(DISTINCT CASE WHEN f.User_Id IS NOT NULL THEN a.User_Id END)       AS ftds,
        SUM(g.ggr)                                                               AS ggr,
        SUM(g.turnover)                                                          AS turnover,
        COUNT(DISTINCT CASE WHEN g.User_Id IS NOT NULL THEN a.User_Id END)       AS jogadores_ativos
    FROM acquisitions_agg a WITH(NOLOCK)
    LEFT JOIN ftd_agg f WITH(NOLOCK)
      ON f.User_Id = a.User_Id AND f.FTD_Date >= @ini AND f.FTD_Date <= @fim
    LEFT JOIN ggr_usuario g ON g.User_Id = a.User_Id
    GROUP BY ISNULL(NULLIF(LTRIM(RTRIM(a.Acquisition_Channel)), ''), 'Não informado')
)
SELECT
    canal            AS Canal,
    ISNULL(ggr, 0)   AS GGR,
    ISNULL(turnover, 0) AS Turnover,
    ftds             AS FTDs,
    registros        AS Registros,
    jogadores_ativos AS Jogadores_Ativos
FROM por_canal
-- Canal sem nenhum sinal no periodo nao vira fatia.
WHERE ISNULL(ggr, 0) <> 0 OR ftds > 0 OR registros > 0
ORDER BY ISNULL(ggr, 0) DESC;
