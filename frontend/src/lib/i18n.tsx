import {
  createContext, useCallback, useContext, useEffect, useMemo, useState,
  type ReactNode,
} from "react";

/** Idioma da interface: português, espanhol ou inglês.
 *
 * Divisão de responsabilidade com o backend: o que está aqui é a **casca** —
 * menu, botão, aviso, rótulo de coluna da tela. Nome de métrica, aba de report e
 * frase de insight vêm prontos da API (ou do snapshot da demo), porque dependem
 * também da vertical de negócio; `api.ts` manda o idioma na query string e o
 * backend responde traduzido (ver `backend/app/i18n.py`).
 *
 * O idioma escolhido fica em `localStorage`: trocar de tela — ou voltar amanhã —
 * não devolve a pessoa para o português.
 *
 * Módulos que não são componentes (`api.ts`, `demo.ts`, `viz.ts`, `csv.ts`) leem
 * `langAtual()`, um espelho do estado; `assinarLang()` avisa quem precisa
 * reagir (a demo troca a pasta de fixtures).
 */

export type Lang = "pt" | "es" | "en";

export const LANGS: { code: Lang; nome: string; aria: string }[] = [
  { code: "pt", nome: "Português", aria: "Mudar para português" },
  { code: "es", nome: "Español", aria: "Cambiar a español" },
  { code: "en", nome: "English", aria: "Switch to English" },
];

const CHAVE = "blackwall.lang";

/** Locale de formatação de número e data. A moeda continua BRL nos três: o dado
 *  é em real, o que muda é a pontuação e o nome do mês. */
const LOCALES: Record<Lang, string> = { pt: "pt-BR", es: "es-ES", en: "en-US" };

// --- catálogo --------------------------------------------------------------- //

type Dic = Record<string, string>;

const PT: Dic = {
  // casca / genéricos
  erro: "Erro",
  modo: "Modo",
  somente_leitura: "somente leitura",
  banco: "Banco",
  vertical: "Vertical",
  categoria: "Categoria",
  outros: "Outros",
  baixar_csv: "Baixar CSV",
  linhas: "linhas",
  vazio: "vazio",

  // tela das bases
  eyebrow: "Netwatch · perímetro analítico",
  lede: "Cada operação fica atrás da parede. Escolha uma para atravessar e consultar os dados.",
  portais: "Portais",
  conectados: "Conectados",
  bases_erro: "Não foi possível carregar as bases: {e}",
  abrindo: "Abrindo…",
  abrir_graficos: "Abrir relatórios",
  faltando: "Faltando: {t}",
  bases_foot: "Consultas somente leitura. Bases com falha continuam navegáveis — o erro aparece na consulta.",

  // estado da conexão
  st_ok: "conectado",
  st_ok_help: "Base respondendo e com as tabelas necessárias.",
  st_missing: "tabelas faltando",
  st_missing_help: "Conecta, mas faltam tabelas ou GRANT SELECT.",
  st_notcfg: "sem configuração",
  st_notcfg_help: "Falta preencher o .env desta base.",
  st_error: "sem conexão",
  st_error_help: "Não foi possível conectar.",
  st_unknown: "verificando…",
  st_unknown_help: "Testando a conexão.",
  nota_missing: "Algumas consultas vão falhar: faltam tabelas ou GRANT SELECT.",
  nota_notcfg: "Falta preencher as credenciais desta base no .env do backend.",
  nota_error: "Não foi possível conectar. As consultas vão falhar até isso ser resolvido.",

  // galeria
  bases: "Bases",
  todas_as_bases: "Todas as bases",
  paineis: "Painéis",
  paineis_desc: "Indicadores e gráficos interativos, para ler na tela.",
  extracoes: "Extrações",
  extracoes_desc: "O mesmo SQL do kpi-bot, em tabela, com download em CSV.",
  carregando_catalogo: "Carregando o catálogo desta base…",
  painel: "Painel",
  um_periodo: "um período",
  dois_periodos: "dois períodos",
  tag_metricas: "métricas",
  tag_visoes: "visões",
  ultima_exec: "última: {d}",
  nao_executado: "ainda não executado",

  // página do relatório
  consultas_de: "Consultas de {b}",
  carregando_filtro: "Carregando filtro…",
  executando: "Executando: {p}",
  consultando_banco: "Consultando o banco…",
  ate_agora: "{d} até agora",
  pode_sair: "pode sair desta tela: a consulta continua e aparece na inicial.",
  encerrar_consulta: "Encerrar consulta",
  consulta_encerrada: "Consulta encerrada. Ajuste o filtro e consulte de novo.",
  falhou_apos: "(falhou após {d})",
  concluida_em: "Consulta concluída em {d}.",

  // filtro
  atalho_7: "7 dias",
  atalho_30: "30 dias",
  atalho_90: "90 dias",
  atalho_mes: "Este mês",
  atalho_mes_passado: "Mês passado",
  atalho_nota: "o atalho preenche também o período de comparação",
  consultar: "Consultar",
  consultando: "Consultando…",
  snapshots_nota: "snapshots capturados — outro filtro cai no primeiro da lista",

  // overview
  sem_movimento: "Sem movimento no período selecionado.",
  comparado_com: "comparado com {p}",
  por_periodo: "{m} por período",
  granularidade: "Granularidade",
  metrica: "Métrica",
  diario: "Diário",
  semanal: "Semanal",
  mensal: "Mensal",
  dias: "dias",
  semanas: "semanas",
  meses: "meses",
  semana_de: "Semana de {a} a {b}",
  total_de: "total {v}",
  pico_em: "pico em {p}",
  vs: "vs {v}",

  // donut
  ver_tabela: "Ver tabela",
  ocultar_tabela: "Ocultar tabela",
  itens_somados: "{n} itens menores estão somados em “Outros”.",

  // retention
  ret_periodo: "Período {p}",
  ret_valores_reais: "valores em reais por {u} ativo (mês 0 = cohort)",
  ret_valores_milhar: "valores em milhar (mês 0 = cohort)",
  ret_meses_desde: "Meses desde a aquisição",
  ret_mes_n: "Mês {n}",
  ret_valor_exato: "Valor exato: {v}",
  ret_resultado: "Resultado da consulta — {m}",
  ret_clique: "clique numa linha p/ destacar",
  ret_insights: "Resumo & insights",
  ret_sem_dados: "Sem dados.",

  // tabelas
  tab_sem_dados: "Sem dados para o período selecionado.",
  tab_sem_linhas: "Esta query não retornou linhas para o período.",
  tab_origem: "Origem:",
  tab_mesmo_sql: "— mesmo SQL do kpi-bot.",
  tab_percent_nota: "Percentuais são exibidos com % e exportados como número no CSV.",

  // consultas em andamento
  consultas: "Consultas",
  consultas_aria: "Consultas em andamento",
  n_em_andamento: "{n} em andamento",
  n_recentes: "{n} recente(s)",
  cq_fila: "na fila",
  cq_rodando: "rodando",
  cq_pronta: "pronta",
  cq_falhou: "falhou",
  cq_encerrada: "encerrada",
  encerrar: "Encerrar",
  encerrar_hint: "Derruba a consulta no banco",
  dispensar: "Dispensar",
  dispensar_hint: "Tira da lista; o resultado continua no servidor por 30 min",

  // demo
  demo_tag: "demo estática",
  demo_txt: "Sem backend no ar: esta página lê um snapshot dos payloads da API real{v}{c}. Os números vieram do SQL Server — a consulta ao banco é que não roda aqui. A stack completa (FastAPI + SQL Server + nginx) sobe com um",
  demo_vertical: " na vertical de {v}",
  demo_vertical_bet: "apostas",
  demo_vertical_ecom: "e-commerce",
  demo_captura: ", capturado em {d}",
  demo_codigo: "Código no GitHub →",
  demo_fora: "Filtro fora do snapshot — mostrando {p}.",

  // duração
  dur_s: "{v} s",
  dur_min: "{m} min {s} s",
};

const ES: Dic = {
  erro: "Error",
  modo: "Modo",
  somente_leitura: "solo lectura",
  banco: "Base",
  vertical: "Vertical",
  categoria: "Categoría",
  outros: "Otros",
  baixar_csv: "Descargar CSV",
  linhas: "filas",
  vazio: "vacío",

  eyebrow: "Netwatch · perímetro analítico",
  lede: "Cada operación está detrás del muro. Elija una para atravesarlo y consultar los datos.",
  portais: "Portales",
  conectados: "Conectados",
  bases_erro: "No se pudieron cargar las bases: {e}",
  abrindo: "Abriendo…",
  abrir_graficos: "Abrir informes",
  faltando: "Faltan: {t}",
  bases_foot: "Consultas de solo lectura. Las bases con fallo siguen navegables — el error aparece en la consulta.",

  st_ok: "conectado",
  st_ok_help: "La base responde y tiene las tablas necesarias.",
  st_missing: "faltan tablas",
  st_missing_help: "Conecta, pero faltan tablas o GRANT SELECT.",
  st_notcfg: "sin configuración",
  st_notcfg_help: "Falta completar el .env de esta base.",
  st_error: "sin conexión",
  st_error_help: "No se pudo conectar.",
  st_unknown: "verificando…",
  st_unknown_help: "Probando la conexión.",
  nota_missing: "Algunas consultas van a fallar: faltan tablas o GRANT SELECT.",
  nota_notcfg: "Falta completar las credenciales de esta base en el .env del backend.",
  nota_error: "No se pudo conectar. Las consultas van a fallar hasta que se resuelva.",

  bases: "Bases",
  todas_as_bases: "Todas las bases",
  paineis: "Paneles",
  paineis_desc: "Indicadores y gráficos interactivos, para leer en pantalla.",
  extracoes: "Extracciones",
  extracoes_desc: "El mismo SQL del kpi-bot, en tabla, con descarga en CSV.",
  carregando_catalogo: "Cargando el catálogo de esta base…",
  painel: "Panel",
  um_periodo: "un período",
  dois_periodos: "dos períodos",
  tag_metricas: "métricas",
  tag_visoes: "vistas",
  ultima_exec: "última: {d}",
  nao_executado: "aún no ejecutado",

  consultas_de: "Consultas de {b}",
  carregando_filtro: "Cargando filtro…",
  executando: "Ejecutando: {p}",
  consultando_banco: "Consultando la base…",
  ate_agora: "{d} hasta ahora",
  pode_sair: "puede salir de esta pantalla: la consulta sigue y aparece en la inicial.",
  encerrar_consulta: "Detener consulta",
  consulta_encerrada: "Consulta detenida. Ajuste el filtro y consulte de nuevo.",
  falhou_apos: "(falló tras {d})",
  concluida_em: "Consulta completada en {d}.",

  atalho_7: "7 días",
  atalho_30: "30 días",
  atalho_90: "90 días",
  atalho_mes: "Este mes",
  atalho_mes_passado: "Mes pasado",
  atalho_nota: "el atajo también completa el período de comparación",
  consultar: "Consultar",
  consultando: "Consultando…",
  snapshots_nota: "snapshots capturados — otro filtro cae en el primero de la lista",

  sem_movimento: "Sin movimiento en el período seleccionado.",
  comparado_com: "comparado con {p}",
  por_periodo: "{m} por período",
  granularidade: "Granularidad",
  metrica: "Métrica",
  diario: "Diario",
  semanal: "Semanal",
  mensal: "Mensual",
  dias: "días",
  semanas: "semanas",
  meses: "meses",
  semana_de: "Semana del {a} al {b}",
  total_de: "total {v}",
  pico_em: "pico en {p}",
  vs: "vs {v}",

  ver_tabela: "Ver tabla",
  ocultar_tabela: "Ocultar tabla",
  itens_somados: "{n} ítems menores están sumados en “Otros”.",

  ret_periodo: "Período {p}",
  ret_valores_reais: "valores en reales por {u} activo (mes 0 = cohorte)",
  ret_valores_milhar: "valores en miles (mes 0 = cohorte)",
  ret_meses_desde: "Meses desde la adquisición",
  ret_mes_n: "Mes {n}",
  ret_valor_exato: "Valor exacto: {v}",
  ret_resultado: "Resultado de la consulta — {m}",
  ret_clique: "clic en una fila para destacar",
  ret_insights: "Resumen e insights",
  ret_sem_dados: "Sin datos.",

  tab_sem_dados: "Sin datos para el período seleccionado.",
  tab_sem_linhas: "Esta query no devolvió filas para el período.",
  tab_origem: "Origen:",
  tab_mesmo_sql: "— el mismo SQL del kpi-bot.",
  tab_percent_nota: "Los porcentajes se muestran con % y se exportan como número en el CSV.",

  consultas: "Consultas",
  consultas_aria: "Consultas en curso",
  n_em_andamento: "{n} en curso",
  n_recentes: "{n} reciente(s)",
  cq_fila: "en cola",
  cq_rodando: "corriendo",
  cq_pronta: "lista",
  cq_falhou: "falló",
  cq_encerrada: "detenida",
  encerrar: "Detener",
  encerrar_hint: "Corta la consulta en la base",
  dispensar: "Descartar",
  dispensar_hint: "La saca de la lista; el resultado sigue en el servidor por 30 min",

  demo_tag: "demo estática",
  demo_txt: "Sin backend en el aire: esta página lee un snapshot de los payloads de la API real{v}{c}. Los números salieron del SQL Server — lo que no corre aquí es la consulta. El stack completo (FastAPI + SQL Server + nginx) se levanta con un",
  demo_vertical: " en la vertical de {v}",
  demo_vertical_bet: "apuestas",
  demo_vertical_ecom: "e-commerce",
  demo_captura: ", capturado el {d}",
  demo_codigo: "Código en GitHub →",
  demo_fora: "Filtro fuera del snapshot — mostrando {p}.",

  dur_s: "{v} s",
  dur_min: "{m} min {s} s",
};

const EN: Dic = {
  erro: "Error",
  modo: "Mode",
  somente_leitura: "read-only",
  banco: "Database",
  vertical: "Vertical",
  categoria: "Category",
  outros: "Others",
  baixar_csv: "Download CSV",
  linhas: "rows",
  vazio: "empty",

  eyebrow: "Netwatch · analytics perimeter",
  lede: "Every operation sits behind the wall. Pick one to break through and query its data.",
  portais: "Gates",
  conectados: "Connected",
  bases_erro: "Could not load the databases: {e}",
  abrindo: "Opening…",
  abrir_graficos: "Open reports",
  faltando: "Missing: {t}",
  bases_foot: "Read-only queries. Databases that fail stay navigable — the error shows up in the query.",

  st_ok: "connected",
  st_ok_help: "Database responding and with the required tables.",
  st_missing: "missing tables",
  st_missing_help: "Connects, but tables or GRANT SELECT are missing.",
  st_notcfg: "not configured",
  st_notcfg_help: "The .env for this database is incomplete.",
  st_error: "no connection",
  st_error_help: "Could not connect.",
  st_unknown: "checking…",
  st_unknown_help: "Testing the connection.",
  nota_missing: "Some queries will fail: tables or GRANT SELECT are missing.",
  nota_notcfg: "The credentials for this database are missing from the backend .env.",
  nota_error: "Could not connect. Queries will fail until this is fixed.",

  bases: "Databases",
  todas_as_bases: "All databases",
  paineis: "Dashboards",
  paineis_desc: "Indicators and interactive charts, made to read on screen.",
  extracoes: "Extracts",
  extracoes_desc: "The same SQL as the kpi-bot, as a table, with CSV download.",
  carregando_catalogo: "Loading this database's catalog…",
  painel: "Dashboard",
  um_periodo: "one period",
  dois_periodos: "two periods",
  tag_metricas: "metrics",
  tag_visoes: "views",
  ultima_exec: "last: {d}",
  nao_executado: "not run yet",

  consultas_de: "{b} reports",
  carregando_filtro: "Loading filter…",
  executando: "Running: {p}",
  consultando_banco: "Querying the database…",
  ate_agora: "{d} so far",
  pode_sair: "you can leave this screen: the query keeps running and shows up on the home page.",
  encerrar_consulta: "Stop query",
  consulta_encerrada: "Query stopped. Adjust the filter and run it again.",
  falhou_apos: "(failed after {d})",
  concluida_em: "Query finished in {d}.",

  atalho_7: "7 days",
  atalho_30: "30 days",
  atalho_90: "90 days",
  atalho_mes: "This month",
  atalho_mes_passado: "Last month",
  atalho_nota: "the shortcut fills the comparison period too",
  consultar: "Run query",
  consultando: "Running…",
  snapshots_nota: "captured snapshots — any other filter falls back to the first one",

  sem_movimento: "No activity in the selected period.",
  comparado_com: "compared with {p}",
  por_periodo: "{m} per period",
  granularidade: "Granularity",
  metrica: "Metric",
  diario: "Daily",
  semanal: "Weekly",
  mensal: "Monthly",
  dias: "days",
  semanas: "weeks",
  meses: "months",
  semana_de: "Week of {a} to {b}",
  total_de: "total {v}",
  pico_em: "peak on {p}",
  vs: "vs {v}",

  ver_tabela: "Show table",
  ocultar_tabela: "Hide table",
  itens_somados: "{n} smaller items are added up under “Others”.",

  ret_periodo: "Period {p}",
  ret_valores_reais: "values in reais per active {u} (month 0 = cohort)",
  ret_valores_milhar: "values in thousands (month 0 = cohort)",
  ret_meses_desde: "Months since acquisition",
  ret_mes_n: "Month {n}",
  ret_valor_exato: "Exact value: {v}",
  ret_resultado: "Query result — {m}",
  ret_clique: "click a row to highlight",
  ret_insights: "Summary & insights",
  ret_sem_dados: "No data.",

  tab_sem_dados: "No data for the selected period.",
  tab_sem_linhas: "This query returned no rows for the period.",
  tab_origem: "Source:",
  tab_mesmo_sql: "— the same SQL as the kpi-bot.",
  tab_percent_nota: "Percentages are shown with % and exported as plain numbers in the CSV.",

  consultas: "Queries",
  consultas_aria: "Running queries",
  n_em_andamento: "{n} running",
  n_recentes: "{n} recent",
  cq_fila: "queued",
  cq_rodando: "running",
  cq_pronta: "ready",
  cq_falhou: "failed",
  cq_encerrada: "stopped",
  encerrar: "Stop",
  encerrar_hint: "Kills the query on the database",
  dispensar: "Dismiss",
  dispensar_hint: "Removes it from the list; the result stays on the server for 30 min",

  demo_tag: "static demo",
  demo_txt: "No backend running: this page reads a snapshot of the real API payloads{v}{c}. The numbers came out of SQL Server — what does not run here is the query itself. The full stack (FastAPI + SQL Server + nginx) comes up with a single",
  demo_vertical: " on the {v} vertical",
  demo_vertical_bet: "betting",
  demo_vertical_ecom: "e-commerce",
  demo_captura: ", captured on {d}",
  demo_codigo: "Code on GitHub →",
  demo_fora: "Filter outside the snapshot — showing {p}.",

  dur_s: "{v} s",
  dur_min: "{m} min {s} s",
};

const DICS: Record<Lang, Dic> = { pt: PT, es: ES, en: EN };

// Chave faltando numa tradução é erro de programação e aparece como texto cru na
// tela. Em dev isso grita no console; em produção não vale derrubar a página.
if (import.meta.env.DEV) {
  const base = Object.keys(PT);
  for (const lang of ["es", "en"] as Lang[]) {
    const faltando = base.filter((k) => !(k in DICS[lang]));
    const sobrando = Object.keys(DICS[lang]).filter((k) => !base.includes(k));
    if (faltando.length || sobrando.length)
      console.error(`i18n [${lang}]`, { faltando, sobrando });
  }
}

// --- estado ---------------------------------------------------------------- //

function inicial(): Lang {
  try {
    const salvo = localStorage.getItem(CHAVE);
    if (salvo && salvo in DICS) return salvo as Lang;
  } catch { /* storage bloqueado: segue no idioma do navegador */ }
  for (const nav of navigator.languages ?? [navigator.language]) {
    const curto = (nav ?? "").slice(0, 2).toLowerCase();
    if (curto in DICS) return curto as Lang;
  }
  return "pt";
}

let atual: Lang = inicial();
const ouvintes = new Set<(l: Lang) => void>();

/** Idioma corrente para módulos que não são componentes. */
export const langAtual = (): Lang => atual;

/** Locale de formatação do idioma corrente. */
export const locale = (): string => LOCALES[atual];

export function assinarLang(cb: (l: Lang) => void): () => void {
  ouvintes.add(cb);
  return () => ouvintes.delete(cb);
}

function aplicar(l: Lang) {
  atual = l;
  try { localStorage.setItem(CHAVE, l); } catch { /* storage bloqueado */ }
  // O `lang` do documento importa para leitor de tela e para hifenização.
  document.documentElement.lang = LOCALES[l];
  ouvintes.forEach((cb) => cb(l));
}

/** Interpola `{chave}` — o mesmo formato do catálogo do backend. */
function formatar(texto: string, vars?: Record<string, string | number>): string {
  if (!vars) return texto;
  return texto.replace(/{(\w+)}/g, (bruto, chave) =>
    chave in vars ? String(vars[chave]) : bruto);
}

interface Ctx {
  lang: Lang;
  setLang: (l: Lang) => void;
  t: (chave: string, vars?: Record<string, string | number>) => string;
}

const I18nCtx = createContext<Ctx | null>(null);

export function I18nProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>(atual);

  // Primeiro render também precisa acertar o <html lang>.
  useEffect(() => { document.documentElement.lang = LOCALES[lang]; }, [lang]);

  const setLang = useCallback((l: Lang) => {
    aplicar(l);
    setLangState(l);
  }, []);

  const t = useCallback(
    (chave: string, vars?: Record<string, string | number>) => {
      const texto = DICS[lang][chave] ?? DICS.pt[chave] ?? chave;
      return formatar(texto, vars);
    },
    [lang],
  );

  const valor = useMemo<Ctx>(() => ({ lang, setLang, t }), [lang, setLang, t]);
  return <I18nCtx.Provider value={valor}>{children}</I18nCtx.Provider>;
}

export function useI18n(): Ctx {
  const ctx = useContext(I18nCtx);
  if (!ctx) throw new Error("useI18n precisa do <I18nProvider>.");
  return ctx;
}

/** Tradução fora de componente (formatadores em `api.ts`, `csv.ts`). */
export function tr(chave: string, vars?: Record<string, string | number>): string {
  const texto = DICS[atual][chave] ?? DICS.pt[chave] ?? chave;
  return formatar(texto, vars);
}
