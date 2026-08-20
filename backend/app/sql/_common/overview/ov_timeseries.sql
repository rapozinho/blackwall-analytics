-- Overview / serie diaria — uma linha por dia do periodo selecionado.
-- Semanal e mensal sao agregados no frontend a partir daqui: uma consulta so, e
-- trocar de granularidade nao volta ao banco.
--
-- Filtro por Date_Time (indice SK01), agrupamento por CAST(Date_Time AS DATE)
-- para o dia sair do mesmo campo que filtrou.
DECLARE @ini DATE = '{start1}';
DECLARE @fim DATE = '{end1}';
DECLARE @fimx DATETIME = DATEADD(day, 1, @fim);

WITH casino AS (
    SELECT CAST(Date_Time AS DATE) AS dia,
           SUM(GGR) AS ggr, SUM(NGR) AS ngr, SUM(Turnover) AS turnover
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE Date_Time >= @ini AND Date_Time < @fimx
    GROUP BY CAST(Date_Time AS DATE)
),
sports AS (
    SELECT CAST(Date_Time AS DATE) AS dia,
           SUM(GGR) AS ggr, SUM(NGR) AS ngr, SUM(Turnover) AS turnover
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE Date_Time >= @ini AND Date_Time < @fimx
    GROUP BY CAST(Date_Time AS DATE)
),
pagamentos AS (
    SELECT CAST(Date_Time AS DATE) AS dia,
           SUM(Deposits_Amount) AS depositos, SUM(Withdrawals_Amount) AS saques
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE Date_Time >= @ini AND Date_Time < @fimx AND Status = 'Completed'
    GROUP BY CAST(Date_Time AS DATE)
),
ftds AS (
    SELECT FTD_Date AS dia, COUNT(DISTINCT User_Id) AS ftds
    FROM ftd_agg WITH(NOLOCK)
    WHERE FTD_Date >= @ini AND FTD_Date <= @fim
    GROUP BY FTD_Date
),
-- Dias sem jogo mas com deposito/FTD tambem entram: a linha do tempo nao pode
-- pular datas, senao a media movel do frontend mente.
dias AS (
    SELECT dia FROM casino
    UNION SELECT dia FROM sports
    UNION SELECT dia FROM pagamentos
    UNION SELECT dia FROM ftds
)
SELECT
    d.dia                                         AS Dia,
    ISNULL(c.ggr, 0) + ISNULL(s.ggr, 0)           AS GGR,
    ISNULL(c.ggr, 0)                              AS GGR_Casino,
    ISNULL(s.ggr, 0)                              AS GGR_Sports,
    ISNULL(c.ngr, 0) + ISNULL(s.ngr, 0)           AS NGR,
    ISNULL(c.turnover, 0) + ISNULL(s.turnover, 0) AS Turnover,
    ISNULL(y.depositos, 0)                        AS Depositos,
    ISNULL(y.saques, 0)                           AS Saques,
    ISNULL(y.depositos, 0) - ISNULL(y.saques, 0)  AS Netcash,
    ISNULL(f.ftds, 0)                             AS FTDs
FROM dias d
LEFT JOIN casino     c ON c.dia = d.dia
LEFT JOIN sports     s ON s.dia = d.dia
LEFT JOIN pagamentos y ON y.dia = d.dia
LEFT JOIN ftds       f ON f.dia = d.dia
ORDER BY d.dia;
