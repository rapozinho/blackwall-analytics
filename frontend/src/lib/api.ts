import { DEMO, demoJSON } from "./demo";

export interface Base { key: string; label: string; }

/** Vocabulário da vertical ativa (`VERTICAL=bet|ecommerce` no backend). */
export interface AppMeta {
  vertical: "bet" | "ecommerce";
  label: string;
  unidade_cliente: string;
  unidade_cliente_plural: string;
  /** Rótulo das duas operações: casino/sportsbook ou marketplace/loja própria. */
  verticais: { casino: string; sports: string };
  verticais_par: string;
  /** Rótulo por chave da série diária — o gráfico é o mesmo, o nome muda. */
  series: Record<string, string>;
}

export interface BaseHealth {
  key: string; label: string; database: string | null;
  status: "ok" | "missing_tables" | "not_configured" | "error" | "unknown";
  detail: string | null;
  missing_tables: string[];
  sqlstate?: string | null;
  hint?: string | null;
}
export interface DbHealth {
  driver: { configured: string; installed: boolean; available: string[] };
  server: string | null;
  ok: boolean;
  bases: BaseHealth[];
}
export interface ParamSpec {
  /** "select" = escolha única; "multiselect" = zero ou mais. */
  type: "date" | "select" | "multiselect";
  label: string;
  required?: boolean;
  default?: unknown;
  options?: { value: string; label: string; hint?: string }[];
}
export interface ChartMeta {
  id: string; label: string; description: string;
  bases: string[]; params: Record<string, ParamSpec>;
  /** "dashboard"/"chart" = painel de leitura; "tables" = extração p/ CSV. */
  kind: "dashboard" | "chart" | "tables";
}

/** Um ponto da série diária do Overview; semana/mês são agregados no cliente. */
export interface SeriePonto {
  dia: string;
  ggr: number; ggr_casino: number; ggr_sports: number;
  ngr: number; turnover: number;
  depositos: number; saques: number; netcash: number;
  ftds: number;
}
export interface Kpi {
  key: string; label: string; hint: string;
  format: "currency" | "int" | "percent" | "ratio";
  value: number; previous: number;
  /** null quando o período anterior é zero: variação não existe, não é 0%. */
  delta: number | null;
  delta_unit: "pct" | "pp";
  higher_is_better: boolean;
}
export interface Donut {
  id: string; label: string; description: string;
  metrics: { key: string; label: string; format: string }[];
  slices: { label: string; values: Record<string, number> }[];
}
export interface DashboardData {
  base: string; kind: "dashboard";
  periodo: string; periodo_anterior: string; empty: boolean;
  kpis: Kpi[]; series: SeriePonto[]; donuts: Donut[]; notes: string[];
  /** Vocabulário da vertical, no próprio payload: evita uma segunda chamada. */
  labels?: Record<string, string>;
  verticais?: { casino: string; sports: string };
}

export interface JobStatus {
  job_id: string; label: string;
  status: "queued" | "running" | "done" | "error" | "cancelled";
  progress: number; step: string;
  /** Contexto para remontar o link de volta sem consultar o catálogo. */
  chart_id: string; base: string; params: Record<string, string>;
  /** Tempo de execução no servidor (parcial enquanto roda). */
  elapsed_seconds: number | null;
  result?: any; error?: string;
}

/** "12,3 s" / "2 min 05 s" — duração de consulta, não timestamp. */
export function fmtDuration(seconds: number): string {
  // 59.96 arredondaria para "60,0 s": acima disso já sai em minutos.
  if (seconds < 59.95) return `${seconds.toFixed(1).replace(".", ",")} s`;
  const m = Math.floor(seconds / 60);
  const s = Math.round(seconds - m * 60);
  return `${m} min ${String(s).padStart(2, "0")} s`;
}

export interface TableData {
  name: string; file: string; sources: string[];
  columns: string[];
  /** Colunas numéricas a exibir com sufixo "%": o SQL devolve o número puro. */
  percent_columns: string[];
  rows: (string | number | null)[][];
}

async function getJSON<T>(url: string, init?: RequestInit): Promise<T> {
  // Build de demonstracao (GitHub Pages): nao existe /api do outro lado, e o
  // snapshot em `public/fixtures/` responde no lugar. Ver `lib/demo.ts`.
  if (DEMO) return demoJSON<T>(url, init);
  const r = await fetch(url, init);
  if (!r.ok) {
    let msg = r.statusText;
    try { const j = await r.json(); msg = j.detail ?? msg; } catch { /* ignore */ }
    throw new Error(msg);
  }
  return r.json() as Promise<T>;
}

export const api = {
  bases: () => getJSON<Base[]>("/api/bases"),
  meta: () => getJSON<AppMeta>("/api/meta"),
  // Testa 4 bases em sequência (5s de timeout cada): carregue sem bloquear a tela.
  health: () => getJSON<DbHealth>("/api/health/db"),
  charts: (base: string) => getJSON<ChartMeta[]>(`/api/charts?base=${encodeURIComponent(base)}`),
  chartData: (id: string, base: string, params: Record<string, string>) => {
    const qs = new URLSearchParams({ base, ...params });
    return getJSON<any>(`/api/charts/${id}/data?${qs.toString()}`);
  },
  // Monitoring/Big Picture passam de 1 min por arquivo: roda como job + polling.
  startJob: (id: string, base: string, params: Record<string, string>) => {
    const qs = new URLSearchParams({ base, ...params });
    return getJSON<{ job_id: string }>(`/api/charts/${id}/start?${qs.toString()}`);
  },
  job: (jobId: string) => getJSON<JobStatus>(`/api/jobs/${jobId}`),
  // Sem `result`: é polling de lista, e um report grande passa de 1 MB.
  jobs: () => getJSON<JobStatus[]>("/api/jobs"),
  // POST: encerrar muda estado no servidor (derruba a query no banco).
  cancelJob: (jobId: string) =>
    getJSON<JobStatus>(`/api/jobs/${jobId}/cancel`, { method: "POST" }),
};
