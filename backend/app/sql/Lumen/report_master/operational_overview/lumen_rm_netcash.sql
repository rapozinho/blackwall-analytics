-- Report Master / Operational Overview: Netcash (Deposits - Withdrawals)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH Financeiro AS (
    SELECT
        SUM(Deposits_Amount) AS total_deposits,
        SUM(Withdrawals_amount) AS total_withdrawals
    FROM payments_agg_hourly WITH(NOLOCK)
    WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive
      AND Status = 'Completed'
)
SELECT
    ISNULL(total_deposits, 0) - ISNULL(total_withdrawals, 0) AS Netcash
FROM Financeiro;
