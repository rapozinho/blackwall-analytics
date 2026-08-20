-- Report Master / Operational Overview: TOAU/Unique
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

WITH combined_data AS (
    SELECT user_id, Turnover
    FROM casino_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
    UNION ALL
    SELECT user_id, Turnover
    FROM sports_agg_hourly WITH(NOLOCK)
    WHERE date_time >= @data_ini AND date_time < @data_fim_exclusive
)
SELECT
    SUM(Turnover) / NULLIF(COUNT(DISTINCT user_id), 0) AS TOAU_Unique
FROM combined_data;
