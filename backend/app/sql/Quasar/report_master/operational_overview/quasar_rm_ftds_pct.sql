-- Report Master / Operational Overview: FTDs % (crescimento vs mes anterior, fracao)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH MesAnterior AS (
    SELECT COUNT(DISTINCT User_Id) AS total
    FROM ftd_agg WITH(NOLOCK)
    WHERE FTD_Date >= DATEADD(month, -1, @data_ini) AND FTD_Date < @data_ini
),
MesAtual AS (
    SELECT COUNT(DISTINCT User_Id) AS total
    FROM ftd_agg WITH(NOLOCK)
    WHERE FTD_Date >= @data_ini AND FTD_Date < @data_fim_exclusive
)
SELECT
    CAST((a.total - p.total) * 1.0 / NULLIF(p.total, 0) AS DECIMAL(18,6)) AS [FTDs %]
FROM MesAnterior p
CROSS JOIN MesAtual a;
