-- Report Master / Operational Overview: Hold (NGR/GGR) - Casino (fracao p/ formato 0,00%)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH Casino_Dados AS (
    SELECT
        SUM(NGR) AS ngr_casino,
        SUM(ggr) AS ggr_casino
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
)
SELECT
    CAST(ngr_casino * 1.0 / NULLIF(ggr_casino, 0) AS DECIMAL(18,6)) AS [Hold (NGR/GGR) - Casino]
FROM Casino_Dados;
