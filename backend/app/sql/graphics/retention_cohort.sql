-- Retention Cohort: GGR/Turnover/Deposits/Netcash por cohort de FTD.
--
-- Placeholders na convencao do catalogo do kpi-bot:
--   {start1} = inicio do periodo de aquisicao (normalizado ao 1o dia do mes)
--   {end1}   = fim do periodo de atividade (INCLUSIVO)
-- O blackwall NAO interpola: sqlcat.to_parameterized() troca cada placeholder por
-- um marcador posicional antes de executar. Nao escreva marcador literal aqui.
--
-- Retorna: cohort | mes_index | turnover | ggr | deposit | netcash
--          | players_jogo | players_pagto
-- Tabelas: ftd_agg, casino_agg_hourly, sports_agg_hourly, payments_agg_hourly
--
-- Os dois contadores de jogadores alimentam a variante "media por jogador
-- ativo". Sao separados de proposito: quem apostou nao e o mesmo conjunto de
-- quem depositou, e dividir o GGR por um denominador que inclui quem so
-- depositou (e nao jogou) achata a curva sem motivo.

DECLARE @cohort_start DATE = DATEADD(month, DATEDIFF(month, 0, CAST('{start1}' AS DATE)), 0);
DECLARE @activity_end DATE = CAST('{end1}' AS DATE);
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @activity_end);

WITH CohortUsers AS (
    SELECT DISTINCT ftd.User_Id,
           DATEADD(month, DATEDIFF(month, 0, ftd.FTD_Date), 0) AS Cohort_Month
    FROM ftd_agg ftd WITH(NOLOCK)
    WHERE ftd.FTD_Date >= @cohort_start AND ftd.FTD_Date < @data_fim_exclusive
),
Jogo AS (
    SELECT c.Cohort_Month, DATEADD(month, DATEDIFF(month, 0, a.Date_Agg), 0) AS Month_Ref,
           a.User_Id, a.Turnover AS turnover, a.GGR AS ggr
    FROM CohortUsers c
    INNER JOIN casino_agg_hourly a WITH(NOLOCK) ON c.User_Id = a.User_Id
    WHERE a.Date_Agg >= c.Cohort_Month AND a.Date_Agg < @data_fim_exclusive
    UNION ALL
    SELECT c.Cohort_Month, DATEADD(month, DATEDIFF(month, 0, s.Date_Agg), 0),
           s.User_Id, s.Turnover, s.GGR
    FROM CohortUsers c
    INNER JOIN sports_agg_hourly s WITH(NOLOCK) ON c.User_Id = s.User_Id
    WHERE s.Date_Agg >= c.Cohort_Month AND s.Date_Agg < @data_fim_exclusive
),
Pagamento AS (
    SELECT c.Cohort_Month, DATEADD(month, DATEDIFF(month, 0, p.Date_Agg), 0) AS Month_Ref,
           p.User_Id, p.Deposits_Amount AS deposit, p.Netcash AS netcash
    FROM CohortUsers c
    INNER JOIN payments_agg_hourly p WITH(NOLOCK) ON c.User_Id = p.User_Id
    WHERE p.Status = 'Completed'
      AND p.Date_Agg >= c.Cohort_Month AND p.Date_Agg < @data_fim_exclusive
),
JogoMes AS (
    SELECT Cohort_Month, Month_Ref,
           SUM(turnover) AS turnover, SUM(ggr) AS ggr,
           COUNT(DISTINCT User_Id) AS players_jogo
    FROM Jogo
    WHERE Month_Ref >= Cohort_Month
    GROUP BY Cohort_Month, Month_Ref
),
PagamentoMes AS (
    SELECT Cohort_Month, Month_Ref,
           SUM(deposit) AS deposit, SUM(netcash) AS netcash,
           COUNT(DISTINCT User_Id) AS players_pagto
    FROM Pagamento
    WHERE Month_Ref >= Cohort_Month
    GROUP BY Cohort_Month, Month_Ref
),
-- Mes com pagamento mas sem aposta (ou o contrario) continua sendo um ponto da
-- curva: a uniao evita buraco na serie.
Meses AS (
    SELECT Cohort_Month, Month_Ref FROM JogoMes
    UNION
    SELECT Cohort_Month, Month_Ref FROM PagamentoMes
)
SELECT FORMAT(m.Cohort_Month, 'yyyy-MM')                 AS cohort,
       DATEDIFF(month, m.Cohort_Month, m.Month_Ref)      AS mes_index,
       ISNULL(j.turnover, 0)                             AS turnover,
       ISNULL(j.ggr, 0)                                  AS ggr,
       ISNULL(p.deposit, 0)                              AS deposit,
       ISNULL(p.netcash, 0)                              AS netcash,
       ISNULL(j.players_jogo, 0)                         AS players_jogo,
       ISNULL(p.players_pagto, 0)                        AS players_pagto
FROM Meses m
LEFT JOIN JogoMes       j ON j.Cohort_Month = m.Cohort_Month AND j.Month_Ref = m.Month_Ref
LEFT JOIN PagamentoMes  p ON p.Cohort_Month = m.Cohort_Month AND p.Month_Ref = m.Month_Ref
ORDER BY cohort, mes_index;
