-- Report Master: Withdrawals
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

SELECT
    SUM(Withdrawals_amount) AS Withdrawals
FROM payments_agg_hourly WITH(NOLOCK)
WHERE date_agg >= @data_ini AND date_agg < @data_fim_exclusive
AND Status = 'Completed';
