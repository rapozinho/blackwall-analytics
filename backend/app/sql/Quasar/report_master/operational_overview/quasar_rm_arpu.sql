-- Report Master / Operational Overview: ARPU/Unique
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH combined_data AS (
    SELECT user_id, GGR
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
    UNION ALL
    SELECT user_id, GGR
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
)
SELECT
    SUM(GGR) / NULLIF(COUNT(DISTINCT user_id), 0) AS [ARPU/Unique]
FROM combined_data;
