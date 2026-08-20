-- Report Master: Registration
DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

SELECT
    COUNT(DISTINCT User_Id) AS Qtd_Registros
FROM acquisitions_agg WITH(NOLOCK)
WHERE registration_date >= @data_ini AND registration_date < @data_fim_exclusive;
