DECLARE @data_ini DATE = '{start1}';
DECLARE @data_fim DATE = '{end1}';

-- Variável interna para ajustar o intervalo (não precisa mexer aqui)
DECLARE @data_fim_exclusive DATE = DATEADD(day, 1, @data_fim);

select 
 aa.Acquisition_Channel,
 count(distinct fa.User_Id) as FTDs
from acquisitions_agg aa with(nolock)
left join ftd_agg fa with(nolock) 
    on fa.User_Id = aa.User_Id 
        and fa.FTD_Date >= @data_ini 
        and fa.FTD_Date < @data_fim_exclusive
group by aa.Acquisition_Channel
order by aa.Acquisition_Channel