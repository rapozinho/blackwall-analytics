-- Report Master / Acquisition - All: FTDs
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

SELECT
    COUNT(DISTINCT User_Id) AS [FTDs]
FROM ftd_agg WITH(NOLOCK)
WHERE FTD_Date >= @data_ini AND FTD_Date < @data_fim_exclusive;
