-- Overview / KPIs — uma linha por periodo: P1 = selecionado, P2 = comparacao.
-- Schema identico nas 4 bases (validado em INFORMATION_SCHEMA), por isso o
-- arquivo fica em _common e nao por base.
--
-- Filtro sempre por Date_Time: os indices sao SK01_<tabela>(Date_Time) — e em
-- payments (Date_Time, Status). Date_Agg existe mas nao e indexada; filtrar por
-- ela custou 14s onde o seek custa 1s.
DECLARE @ini1 DATE = '{start1}';
DECLARE @fim1 DATE = '{end1}';
DECLARE @ini2 DATE = '{start2}';
DECLARE @fim2 DATE = '{end2}';

-- Fim exclusivo: Date_Time e datetime, `<= @fim` perderia o dia inteiro.
DECLARE @fim1x DATETIME = DATEADD(day, 1, @fim1);
DECLARE @fim2x DATETIME = DATEADD(day, 1, @fim2);

WITH jogo AS (
    SELECT 'P1' AS periodo, SUM(GGR) AS ggr, SUM(NGR) AS ngr, SUM(Turnover) AS turnover,
           'casino' AS vertical
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE Date_Time >= @ini1 AND Date_Time < @fim1x
    UNION ALL
    SELECT 'P2', SUM(GGR), SUM(NGR), SUM(Turnover), 'casino'
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE Date_Time >= @ini2 AND Date_Time < @fim2x
    UNION ALL
    SELECT 'P1', SUM(GGR), SUM(NGR), SUM(Turnover), 'sports'
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE Date_Time >= @ini1 AND Date_Time < @fim1x
    UNION ALL
    SELECT 'P2', SUM(GGR), SUM(NGR), SUM(Turnover), 'sports'
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE Date_Time >= @ini2 AND Date_Time < @fim2x
),
jogo_periodo AS (
    SELECT periodo,
           SUM(CASE WHEN vertical = 'casino' THEN ggr END)      AS ggr_casino,
           SUM(CASE WHEN vertical = 'sports' THEN ggr END)      AS ggr_sports,
           SUM(ngr)                                             AS ngr,
           -- NGR por vertical: na Zephyr o sports grava 0,00 em todas as linhas. O
           -- backend compara os dois para avisar na tela em vez de mascarar.
           SUM(CASE WHEN vertical = 'casino' THEN ngr END)      AS ngr_casino,
           SUM(CASE WHEN vertical = 'sports' THEN ngr END)      AS ngr_sports,
           SUM(CASE WHEN vertical = 'casino' THEN turnover END) AS turnover_casino,
           SUM(CASE WHEN vertical = 'sports' THEN turnover END) AS turnover_sports
    FROM jogo
    GROUP BY periodo
),
-- Status: fora 'Completed' entra pendente/falho — e na Zephyr a maioria das linhas
-- vem com Status NULL. Sem o filtro o deposito estoura ~6x.
pagamentos AS (
    SELECT 'P1' AS periodo, SUM(Deposits_Amount) AS depositos,
           SUM(Withdrawals_Amount) AS saques, SUM(Deposits_Count) AS qtd_depositos
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE Date_Time >= @ini1 AND Date_Time < @fim1x AND Status = 'Completed'
    UNION ALL
    SELECT 'P2', SUM(Deposits_Amount), SUM(Withdrawals_Amount), SUM(Deposits_Count)
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE Date_Time >= @ini2 AND Date_Time < @fim2x AND Status = 'Completed'
),
ftds AS (
    SELECT 'P1' AS periodo, COUNT(DISTINCT User_Id) AS ftds, SUM(FTD_Amount) AS ftd_valor
    FROM ftd_agg WITH(NOLOCK)
    WHERE FTD_Date >= @ini1 AND FTD_Date <= @fim1
    UNION ALL
    SELECT 'P2', COUNT(DISTINCT User_Id), SUM(FTD_Amount)
    FROM ftd_agg WITH(NOLOCK)
    WHERE FTD_Date >= @ini2 AND FTD_Date <= @fim2
),
registros AS (
    SELECT 'P1' AS periodo, COUNT(DISTINCT User_Id) AS registros
    FROM acquisitions_agg WITH(NOLOCK)
    WHERE Registration_Date >= @ini1 AND Registration_Date <= @fim1
    UNION ALL
    SELECT 'P2', COUNT(DISTINCT User_Id)
    FROM acquisitions_agg WITH(NOLOCK)
    WHERE Registration_Date >= @ini2 AND Registration_Date <= @fim2
),
-- UAP = jogadores unicos ativos no periodo (casino + sports sem dupla contagem).
ativos AS (
    SELECT 'P1' AS periodo, COUNT(DISTINCT User_Id) AS uap FROM (
        SELECT User_Id FROM casino_agg_hourly WITH(NOLOCK)
        WHERE Date_Time >= @ini1 AND Date_Time < @fim1x
        UNION ALL
        SELECT User_Id FROM sports_agg_hourly WITH(NOLOCK)
        WHERE Date_Time >= @ini1 AND Date_Time < @fim1x
    ) t1
    UNION ALL
    SELECT 'P2', COUNT(DISTINCT User_Id) FROM (
        SELECT User_Id FROM casino_agg_hourly WITH(NOLOCK)
        WHERE Date_Time >= @ini2 AND Date_Time < @fim2x
        UNION ALL
        SELECT User_Id FROM sports_agg_hourly WITH(NOLOCK)
        WHERE Date_Time >= @ini2 AND Date_Time < @fim2x
    ) t2
),
periodos AS (
    SELECT 'P1' AS periodo, @ini1 AS ini, @fim1 AS fim
    UNION ALL
    SELECT 'P2', @ini2, @fim2
)
SELECT
    p.periodo                                                  AS Periodo,
    p.ini                                                      AS Inicio,
    p.fim                                                      AS Fim,
    ISNULL(j.ggr_casino, 0) + ISNULL(j.ggr_sports, 0)          AS GGR,
    ISNULL(j.ggr_casino, 0)                                    AS GGR_Casino,
    ISNULL(j.ggr_sports, 0)                                    AS GGR_Sports,
    ISNULL(j.ngr, 0)                                           AS NGR,
    ISNULL(j.ngr_casino, 0)                                    AS NGR_Casino,
    ISNULL(j.ngr_sports, 0)                                    AS NGR_Sports,
    ISNULL(j.turnover_casino, 0) + ISNULL(j.turnover_sports, 0) AS Turnover,
    ISNULL(j.turnover_casino, 0)                               AS Turnover_Casino,
    ISNULL(j.turnover_sports, 0)                               AS Turnover_Sports,
    ISNULL(y.depositos, 0)                                     AS Depositos,
    ISNULL(y.saques, 0)                                        AS Saques,
    ISNULL(y.depositos, 0) - ISNULL(y.saques, 0)               AS Netcash,
    ISNULL(y.qtd_depositos, 0)                                 AS Qtd_Depositos,
    ISNULL(f.ftds, 0)                                          AS FTDs,
    ISNULL(f.ftd_valor, 0)                                     AS FTD_Valor,
    ISNULL(r.registros, 0)                                     AS Registros,
    ISNULL(u.uap, 0)                                           AS UAP,
    -- Fracoes (0..1): o frontend multiplica por 100 e formata.
    CAST(ISNULL(j.ngr, 0) * 1.0
         / NULLIF(ISNULL(j.ggr_casino, 0) + ISNULL(j.ggr_sports, 0), 0) AS DECIMAL(18, 6)) AS Hold,
    CAST((ISNULL(j.ggr_casino, 0) + ISNULL(j.ggr_sports, 0)) * 1.0
         / NULLIF(ISNULL(j.turnover_casino, 0) + ISNULL(j.turnover_sports, 0), 0) AS DECIMAL(18, 6)) AS Margem,
    CAST(f.ftds * 1.0 / NULLIF(r.registros, 0) AS DECIMAL(18, 6))                              AS Conversao_FTD,
    -- ARPU sobre jogadores ativos; NARPU usa NGR.
    CAST((ISNULL(j.ggr_casino, 0) + ISNULL(j.ggr_sports, 0)) * 1.0
         / NULLIF(u.uap, 0) AS DECIMAL(18, 2))                 AS ARPU,
    CAST(ISNULL(j.ngr, 0) * 1.0 / NULLIF(u.uap, 0) AS DECIMAL(18, 2)) AS NARPU
FROM periodos p
LEFT JOIN jogo_periodo j ON j.periodo = p.periodo
LEFT JOIN pagamentos   y ON y.periodo = p.periodo
LEFT JOIN ftds         f ON f.periodo = p.periodo
LEFT JOIN registros    r ON r.periodo = p.periodo
LEFT JOIN ativos       u ON u.periodo = p.periodo
ORDER BY p.periodo;
