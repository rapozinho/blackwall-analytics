-- Overview / mix de produto — GGR por vertical e por provedor.
-- Uma so consulta alimenta duas pizzas: `Escopo` separa as linhas.
-- Filtro por Date_Time (indice SK01), como no resto do overview.
DECLARE @ini DATE = '{start1}';
DECLARE @fim DATE = '{end1}';
DECLARE @fimx DATETIME = DATEADD(day, 1, @fim);

WITH provedores AS (
    SELECT ISNULL(NULLIF(LTRIM(RTRIM(Provider_Name)), ''), 'Não informado') AS nome,
           SUM(GGR) AS ggr, SUM(Turnover) AS turnover, SUM(Bet_Count) AS apostas
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE Date_Time >= @ini AND Date_Time < @fimx
    GROUP BY ISNULL(NULLIF(LTRIM(RTRIM(Provider_Name)), ''), 'Não informado')
),
-- Top 12 por GGR; a cauda vira uma fatia "Outros" para a pizza nao virar confete.
ranqueado AS (
    SELECT nome, ggr, turnover, apostas,
           ROW_NUMBER() OVER (ORDER BY ggr DESC) AS pos
    FROM provedores
),
-- Casino sai da soma de `provedores`: varrer a tabela de novo so pro total
-- custava o dobro do tempo da consulta inteira.
verticais AS (
    SELECT 'Casino' AS nome, SUM(ggr) AS ggr, SUM(turnover) AS turnover, SUM(apostas) AS apostas
    FROM provedores
    UNION ALL
    SELECT 'Sportsbook', SUM(GGR), SUM(Turnover), SUM(Bet_Count)
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE Date_Time >= @ini AND Date_Time < @fimx
),
mix AS (
    SELECT 'Vertical' AS escopo, nome, ggr, turnover, apostas
    FROM verticais
    WHERE ggr IS NOT NULL
    UNION ALL
    SELECT 'Provedor', nome, ggr, turnover, apostas
    FROM ranqueado
    WHERE pos <= 12
    UNION ALL
    SELECT 'Provedor', 'Outros', SUM(ggr), SUM(turnover), SUM(apostas)
    FROM ranqueado
    WHERE pos > 12
    HAVING SUM(ggr) IS NOT NULL
)
SELECT escopo AS Escopo, nome AS Nome,
       ISNULL(ggr, 0) AS GGR, ISNULL(turnover, 0) AS Turnover, ISNULL(apostas, 0) AS Apostas
FROM mix
ORDER BY Escopo, GGR DESC;
