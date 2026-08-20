-- Report Master / Operational Overview: Registration % (crescimento vs mes anterior, fracao)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH MesAnterior AS (
    SELECT COUNT(DISTINCT User_Id) AS total
    FROM acquisitions_agg WITH(NOLOCK)
    WHERE registration_date >= DATEADD(month, -1, @data_ini) AND registration_date < @data_ini
),
MesAtual AS (
    SELECT COUNT(DISTINCT User_Id) AS total
    FROM acquisitions_agg WITH(NOLOCK)
    WHERE registration_date >= @data_ini AND registration_date < @data_fim_exclusive
)
SELECT
    CAST((a.total - p.total) * 1.0 / NULLIF(p.total, 0) AS DECIMAL(18,6)) AS [Registration %]
FROM MesAnterior p
CROSS JOIN MesAtual a;
