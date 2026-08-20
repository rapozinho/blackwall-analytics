-- Report Master / Acquisition - All: Top 5 Btags / FTDs Top 5
-- Lumen: tabela acquisitions_agg nao possui coluna 'btag' (diferente da Quasar);
--   agrupamento feito apenas por affiliate_name. >>> VALIDAR se affiliate_name e o agrupamento desejado. <<<
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

SELECT TOP 5
    a.affiliate_name AS [Top 5 Btags],
    COUNT(DISTINCT f.User_Id) AS [FTDs Top 5]
FROM acquisitions_agg a WITH(NOLOCK)
INNER JOIN ftd_agg f WITH(NOLOCK) ON f.User_Id = a.user_id
WHERE f.FTD_Date >= @data_ini AND f.FTD_Date < @data_fim_exclusive
GROUP BY a.affiliate_name
ORDER BY [FTDs Top 5] DESC;
