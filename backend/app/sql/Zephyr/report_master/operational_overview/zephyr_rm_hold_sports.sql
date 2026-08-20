-- Report Master / Operational Overview: Hold (NGR/GGR) - Sports (fracao p/ formato 0,00%)
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH Sports_Dados AS (
    SELECT
        SUM(NGR) AS ngr_sports,
        SUM(ggr) AS ggr_sports
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
)
SELECT
    CAST(ngr_sports * 1.0 / NULLIF(ggr_sports, 0) AS DECIMAL(18,6)) AS [Hold (NGR/GGR) - Sports]
FROM Sports_Dados;
