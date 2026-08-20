# -*- coding: utf-8 -*-
"""Texto da aplicacao que nao depende da vertical de negocio.

    MENSAGENS[lang][chave] -> texto

A divisao com `terms.py` e por origem, nao por tela: o que muda quando a
operacao deixa de ser aposta e passa a ser loja ("GGR" -> "Receita") mora la; o
que e' texto de produto — rotulo de filtro, passo do progresso, erro de
validacao, frase de insight — mora aqui.

Chaves com `{}` sao `str.format`. Os placeholders sao os mesmos nos tres
idiomas: `i18n.py` confere no import, porque um `{m}` perdido na traducao vira
KeyError no meio de uma consulta de 3 minutos.

Erro de validacao vai para a tela do usuario, entao e frase, nao codigo.
As dicas de SQLSTATE (`hint_*`) ficam sem acento de proposito: elas terminam em
log de servidor tanto quanto na tela.
"""

MENSAGENS = {
    # ------------------------------------------------------------------ pt --- #
    "pt": {
        # filtro
        "param_inicio": "Início",
        "param_fim": "Fim",
        "param_inicio_comp": "Início (comparação)",
        "param_fim_comp": "Fim (comparação)",
        "param_visao": "Visão",
        "param_metricas": "Métricas",

        # catalogo
        "chart_overview": "Overview operacional",

        # variantes do cohort
        "variant_total": "Total",
        "variant_total_hint": "Soma da métrica por safra em cada mês.",
        "variant_agregado": "Agregado",
        "variant_agregado_hint": "Média por {u} acumulada mês a mês (mês 1 = mês 0 + mês 1).",

        # KPIs do cohort
        "kpi_cohorts": "Cohorts analisados",
        "kpi_recente": "Cohort mais recente",
        "kpi_total_periodo": "{m} total (período)",
        "kpi_m0": "{m} médio no mês 0",
        "kpi_m0_por": "{m} médio no mês 0 (por {u})",
        "kpi_queda": "Queda média M0→M1",
        "kpi_melhor_acum": "Melhor cohort ({m} acum.)",
        "kpi_melhor_medias": "Melhor cohort (soma das médias)",
        "kpi_melhor_final": "Melhor cohort (acumulado final)",
        "kpi_pior_final": "Pior cohort (acumulado final)",

        # insights do cohort
        "ins_cohorts": "{n} cohort(s) no período; mais recente ({c}) com {meses} mês(es).",
        "ins_maior_menor": ("Maior {m}{por} {rotulo}: <b>{melhor}</b> ({vmelhor}); "
                            "menor: <b>{pior}</b> ({vpior})."),
        "ins_queda": "Queda {t} do mês 0 para o 1: em média <b>{pct}</b>.",
        "ins_queda_forte": "forte",
        "ins_queda_moderada": "moderada",
        "ins_queda_suave": "suave",
        "ins_avg": ("A curva mede quem <b>continuou ativo</b>: o denominador encolhe junto "
                    "com a safra, então subir aqui não significa mais receita — significa "
                    "receita mais concentrada em quem ficou."),
        "ins_agregado": ("Curva sempre crescente por construção: cada mês soma a média do "
                         "anterior. O que importa é a <b>inclinação</b> — onde ela achata, a "
                         "safra parou de render."),
        "ins_negativos": "⚠️ {n} ponto(s) com {m} negativo.",
        "ins_vazio": "Sem dados suficientes para insights.",
        "rot_acumulado": "acumulado",
        "rot_acumulado_final": "acumulado final",
        "por_ativo": " por {u} ativo",

        # progresso
        "passo_kpis": "Indicadores do período",
        "passo_serie": "Série diária",
        "passo_canais": "Canais de aquisição",
        "passo_provedores": "Provedores e verticais",
        "passo_consultando": "Consultando {o}",
        "passo_retencao": "Consultando retenção",
        "passo_query": "Query {n}",
        "tabela_geral": "Geral",
        "tabela_afiliados": "Afiliados",

        # erros de validacao / execucao
        "erro_data_campo": "Data inválida em '{campo}' (use AAAA-MM-DD).",
        "erro_datas": "Datas inválidas (use AAAA-MM-DD).",
        "erro_periodo": "Período inválido: fim antes do início.",
        "erro_periodo_comp": "Período de comparação inválido: fim antes do início.",
        "erro_metrica": "Selecione ao menos uma métrica.",
        "erro_visao": "Visão inválida: {v}.",
        "erro_base": "Base inválida.",
        "erro_base_valor": "Base inválida: {b}",
        "erro_grafico_404": "Gráfico não encontrado.",
        "erro_grafico_base": "Gráfico indisponível para esta base.",
        "erro_job_404": "Job não encontrado ou expirado.",
        "erro_consulta": "Erro ao consultar dados: {e}",
        "erro_sem_sql": "Nenhum SQL no catálogo para {r}/{b}.",
        "erro_nao_autenticado": "Não autenticado",
        "erro_sso": "SSO ainda não integrado",
        "sem_retencao": "Sem dados de retenção para o período.",

        # health
        "saude_falta_env": "Faltando no .env: {vars}",
        "saude_tabelas": ("Conectou, mas estas tabelas nao aparecem para este usuario "
                          "(nao existem ou falta GRANT SELECT)."),
        "hint_08001": ("Host/porta inalcancavel: confira SERVER, VPN e se o SQL Server "
                       "aceita TCP/IP remoto."),
        "hint_08S01": "Conexao caiu no meio: rede instavel ou firewall cortando a sessao.",
        "hint_28000": "Login rejeitado: confira DB_USER/DB_PASSWORD.",
        "hint_4060": ("Login existe mas nao tem acesso a este database: confira o nome em "
                      "DATABASE_<BASE> e se o usuario read-only tem permissao nele."),
        "hint_42000": ("Conectou no servidor mas nao abriu o database: confira o nome em "
                       "DATABASE_<BASE>."),
        "hint_IM002": ("Driver ODBC nao encontrado: confira ODBC_DRIVER e o que esta "
                       "instalado na maquina."),

        # meses dos rotulos de cohort ("Jul-26")
        "meses": "Jan,Fev,Mar,Abr,Mai,Jun,Jul,Ago,Set,Out,Nov,Dez",
    },

    # ------------------------------------------------------------------ es --- #
    "es": {
        "param_inicio": "Inicio",
        "param_fim": "Fin",
        "param_inicio_comp": "Inicio (comparación)",
        "param_fim_comp": "Fin (comparación)",
        "param_visao": "Vista",
        "param_metricas": "Métricas",

        "chart_overview": "Overview operativo",

        "variant_total": "Total",
        "variant_total_hint": "Suma de la métrica por cohorte en cada mes.",
        "variant_agregado": "Agregado",
        "variant_agregado_hint": "Media por {u} acumulada mes a mes (mes 1 = mes 0 + mes 1).",

        "kpi_cohorts": "Cohortes analizadas",
        "kpi_recente": "Cohorte más reciente",
        "kpi_total_periodo": "{m} total (período)",
        "kpi_m0": "{m} medio en el mes 0",
        "kpi_m0_por": "{m} medio en el mes 0 (por {u})",
        "kpi_queda": "Caída media M0→M1",
        "kpi_melhor_acum": "Mejor cohorte ({m} acum.)",
        "kpi_melhor_medias": "Mejor cohorte (suma de las medias)",
        "kpi_melhor_final": "Mejor cohorte (acumulado final)",
        "kpi_pior_final": "Peor cohorte (acumulado final)",

        "ins_cohorts": "{n} cohorte(s) en el período; la más reciente ({c}) con {meses} mes(es).",
        "ins_maior_menor": ("Mayor {m}{por} {rotulo}: <b>{melhor}</b> ({vmelhor}); "
                            "menor: <b>{pior}</b> ({vpior})."),
        "ins_queda": "Caída {t} del mes 0 al 1: en promedio <b>{pct}</b>.",
        "ins_queda_forte": "fuerte",
        "ins_queda_moderada": "moderada",
        "ins_queda_suave": "suave",
        "ins_avg": ("La curva mide a quien <b>siguió activo</b>: el denominador se encoge "
                    "junto con la cohorte, así que subir aquí no significa más ingresos — "
                    "significa ingresos más concentrados en quien se quedó."),
        "ins_agregado": ("Curva siempre creciente por construcción: cada mes suma la media "
                         "del anterior. Lo que importa es la <b>pendiente</b> — donde se "
                         "aplana, la cohorte dejó de rendir."),
        "ins_negativos": "⚠️ {n} punto(s) con {m} negativo.",
        "ins_vazio": "Sin datos suficientes para insights.",
        "rot_acumulado": "acumulado",
        "rot_acumulado_final": "acumulado final",
        "por_ativo": " por {u} activo",

        "passo_kpis": "Indicadores del período",
        "passo_serie": "Serie diaria",
        "passo_canais": "Canales de adquisición",
        "passo_provedores": "Proveedores y verticales",
        "passo_consultando": "Consultando {o}",
        "passo_retencao": "Consultando retención",
        "passo_query": "Query {n}",
        "tabela_geral": "General",
        "tabela_afiliados": "Afiliados",

        "erro_data_campo": "Fecha inválida en '{campo}' (use AAAA-MM-DD).",
        "erro_datas": "Fechas inválidas (use AAAA-MM-DD).",
        "erro_periodo": "Período inválido: el fin es anterior al inicio.",
        "erro_periodo_comp": "Período de comparación inválido: el fin es anterior al inicio.",
        "erro_metrica": "Seleccione al menos una métrica.",
        "erro_visao": "Vista inválida: {v}.",
        "erro_base": "Base inválida.",
        "erro_base_valor": "Base inválida: {b}",
        "erro_grafico_404": "Informe no encontrado.",
        "erro_grafico_base": "Informe no disponible para esta base.",
        "erro_job_404": "Consulta no encontrada o expirada.",
        "erro_consulta": "Error al consultar los datos: {e}",
        "erro_sem_sql": "Ningún SQL en el catálogo para {r}/{b}.",
        "erro_nao_autenticado": "No autenticado",
        "erro_sso": "SSO aún no integrado",
        "sem_retencao": "Sin datos de retención para el período.",

        "saude_falta_env": "Faltan en el .env: {vars}",
        "saude_tabelas": ("Conecta, pero estas tablas no aparecen para este usuario "
                          "(no existen o falta GRANT SELECT)."),
        "hint_08001": ("Host/puerto inalcanzable: revise SERVER, la VPN y si el SQL Server "
                       "acepta TCP/IP remoto."),
        "hint_08S01": "La conexion se cayo a mitad: red inestable o firewall cortando la sesion.",
        "hint_28000": "Login rechazado: revise DB_USER/DB_PASSWORD.",
        "hint_4060": ("El login existe pero no tiene acceso a este database: revise el nombre "
                      "en DATABASE_<BASE> y si el usuario read-only tiene permiso."),
        "hint_42000": ("Conecto al servidor pero no abrio el database: revise el nombre en "
                       "DATABASE_<BASE>."),
        "hint_IM002": ("Driver ODBC no encontrado: revise ODBC_DRIVER y lo que esta instalado "
                       "en la maquina."),

        "meses": "Ene,Feb,Mar,Abr,May,Jun,Jul,Ago,Sep,Oct,Nov,Dic",
    },

    # ------------------------------------------------------------------ en --- #
    "en": {
        "param_inicio": "Start",
        "param_fim": "End",
        "param_inicio_comp": "Start (comparison)",
        "param_fim_comp": "End (comparison)",
        "param_visao": "View",
        "param_metricas": "Metrics",

        "chart_overview": "Operational overview",

        "variant_total": "Total",
        "variant_total_hint": "Sum of the metric per cohort in each month.",
        "variant_agregado": "Cumulative",
        "variant_agregado_hint": ("Average per {u} accumulated month over month "
                                  "(month 1 = month 0 + month 1)."),

        "kpi_cohorts": "Cohorts analysed",
        "kpi_recente": "Most recent cohort",
        "kpi_total_periodo": "Total {m} (period)",
        "kpi_m0": "Average {m} in month 0",
        "kpi_m0_por": "Average {m} in month 0 (per {u})",
        "kpi_queda": "Average drop M0→M1",
        "kpi_melhor_acum": "Best cohort (cum. {m})",
        "kpi_melhor_medias": "Best cohort (sum of averages)",
        "kpi_melhor_final": "Best cohort (final cumulative)",
        "kpi_pior_final": "Worst cohort (final cumulative)",

        "ins_cohorts": "{n} cohort(s) in the period; the most recent ({c}) with {meses} month(s).",
        "ins_maior_menor": ("Highest {rotulo} {m}{por}: <b>{melhor}</b> ({vmelhor}); "
                            "lowest: <b>{pior}</b> ({vpior})."),
        "ins_queda": "{t} drop from month 0 to month 1: <b>{pct}</b> on average.",
        "ins_queda_forte": "Steep",
        "ins_queda_moderada": "Moderate",
        "ins_queda_suave": "Gentle",
        "ins_avg": ("The curve measures who <b>stayed active</b>: the denominator shrinks "
                    "along with the cohort, so going up here does not mean more revenue — it "
                    "means revenue concentrated in whoever stayed."),
        "ins_agregado": ("Always rising by construction: each month adds the previous "
                         "month's average. What matters is the <b>slope</b> — where it "
                         "flattens, the cohort stopped paying off."),
        "ins_negativos": "⚠️ {n} point(s) with negative {m}.",
        "ins_vazio": "Not enough data for insights.",
        "rot_acumulado": "cumulative",
        "rot_acumulado_final": "final cumulative",
        "por_ativo": " per active {u}",

        "passo_kpis": "Period indicators",
        "passo_serie": "Daily series",
        "passo_canais": "Acquisition channels",
        "passo_provedores": "Providers and verticals",
        "passo_consultando": "Querying {o}",
        "passo_retencao": "Querying retention",
        "passo_query": "Query {n}",
        "tabela_geral": "General",
        "tabela_afiliados": "Affiliates",

        "erro_data_campo": "Invalid date in '{campo}' (use YYYY-MM-DD).",
        "erro_datas": "Invalid dates (use YYYY-MM-DD).",
        "erro_periodo": "Invalid period: the end is before the start.",
        "erro_periodo_comp": "Invalid comparison period: the end is before the start.",
        "erro_metrica": "Select at least one metric.",
        "erro_visao": "Invalid view: {v}.",
        "erro_base": "Invalid database.",
        "erro_base_valor": "Invalid database: {b}",
        "erro_grafico_404": "Report not found.",
        "erro_grafico_base": "Report not available for this database.",
        "erro_job_404": "Query not found or expired.",
        "erro_consulta": "Error querying the data: {e}",
        "erro_sem_sql": "No SQL in the catalog for {r}/{b}.",
        "erro_nao_autenticado": "Not authenticated",
        "erro_sso": "SSO not integrated yet",
        "sem_retencao": "No retention data for the period.",

        "saude_falta_env": "Missing from .env: {vars}",
        "saude_tabelas": ("Connected, but these tables do not show up for this user "
                          "(they do not exist or GRANT SELECT is missing)."),
        "hint_08001": ("Host/port unreachable: check SERVER, the VPN and whether SQL Server "
                       "accepts remote TCP/IP."),
        "hint_08S01": "Connection dropped midway: unstable network or a firewall cutting the session.",
        "hint_28000": "Login rejected: check DB_USER/DB_PASSWORD.",
        "hint_4060": ("The login exists but has no access to this database: check the name in "
                      "DATABASE_<BASE> and whether the read-only user has permission on it."),
        "hint_42000": ("Connected to the server but could not open the database: check the "
                       "name in DATABASE_<BASE>."),
        "hint_IM002": ("ODBC driver not found: check ODBC_DRIVER against what is installed on "
                       "the machine."),

        "meses": "Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec",
    },
}
