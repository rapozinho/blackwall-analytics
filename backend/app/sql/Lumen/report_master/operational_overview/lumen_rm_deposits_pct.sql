-- Report Master / Operational Overview: Deposits % (crescimento vs mes anterior, fracao)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH MesAnterior AS (
    SELECT SUM(Deposits_Amount) AS total
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= DATEADD(month, -1, @data_ini) AND date_agg < @data_ini
      AND Status = 'Completed'
),
MesAtual AS (
    SELECT SUM(Deposits_Amount) AS total
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive
      AND Status = 'Completed'
)
SELECT
    CAST((a.total - p.total) * 1.0 / NULLIF(p.total, 0) AS DECIMAL(18,6)) AS [Deposits %]
FROM MesAnterior p
CROSS JOIN MesAtual a;
