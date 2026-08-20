/** Modo demonstração — a aplicação inteira sem backend nem banco.
 *
 * A versão publicada no GitHub Pages é só arquivo estático: não existe FastAPI
 * nem SQL Server do outro lado. Este módulo põe no lugar do `fetch("/api/...")`
 * um snapshot em disco (`public/fixtures/`), capturado da stack real por
 * `tools/gen_fixtures.py` — mesmos payloads, mesmos números, mesmo caminho de
 * render. O que ele NÃO reproduz é a consulta: filtro fora do snapshot cai no
 * período capturado e o aviso do topo diz isso.
 *
 * Ativa com `VITE_DEMO=1` no build. Sem a variável, `api.ts` fala com a API de
 * verdade e nada aqui é carregado.
 */

export const DEMO = import.meta.env.VITE_DEMO === "1";

/** `BASE_URL` já vem com a barra final e com o subcaminho do Pages. */
const RAIZ = `${import.meta.env.BASE_URL}fixtures/`;

export interface EntradaFixture {
  arquivo: string;
  params: Record<string, string>;
  kind: "dashboard" | "chart" | "tables";
  chart_id: string;
  base: string;
  /** Snapshot usado quando o filtro escolhido não existe em disco. */
  padrao: boolean;
  /** Duração real da consulta que gerou este arquivo, no servidor. */
  segundos: number;
  bytes: number;
}

export interface Manifesto {
  gerado_em: string;
  /** `bet` ou `ecommerce`: a vertical em que o snapshot foi capturado. */
  vertical?: string;
  periodo: { date_start: string; date_end: string };
  periodo_comparacao: { date_start2: string; date_end2: string };
  entradas: Record<string, EntradaFixture>;
  falhas: Record<string, string>;
}

// --- carga dos arquivos ----------------------------------------------------- //

const cache = new Map<string, Promise<unknown>>();

function arquivo<T>(nome: string): Promise<T> {
  let p = cache.get(nome) as Promise<T> | undefined;
  if (!p) {
    p = fetch(RAIZ + nome).then((r) => {
      if (!r.ok) throw new Error(`Snapshot ausente: ${nome}`);
      return r.json() as Promise<T>;
    });
    cache.set(nome, p);
  }
  return p;
}

export const manifesto = () => arquivo<Manifesto>("manifest.json");

// --- aviso de snapshot ------------------------------------------------------ //

export interface Aviso {
  /** `exato` = o filtro escolhido existe em disco; `aproximado` = caiu no padrão. */
  tipo: "exato" | "aproximado";
  chartId: string;
  base: string;
  /** Período do snapshot que foi realmente entregue. */
  periodo: string;
  /** Duração da consulta original, no servidor. */
  segundos: number;
}

let avisoAtual: Aviso | null = null;
const ouvintes = new Set<(a: Aviso | null) => void>();

export function assinarAviso(cb: (a: Aviso | null) => void): () => void {
  ouvintes.add(cb);
  cb(avisoAtual);
  return () => ouvintes.delete(cb);
}

function publicar(a: Aviso | null) {
  avisoAtual = a;
  ouvintes.forEach((cb) => cb(a));
}

const br = (iso: string) => iso.split("-").reverse().join("/");

const periodoDe = (p: Record<string, string>) =>
  p.date_start && p.date_end ? `${br(p.date_start)} – ${br(p.date_end)}` : "período capturado";

// --- resolução de fixture --------------------------------------------------- //

/** Params que identificam um snapshot. `base` sai fora: já está na chave. */
function canonico(p: Record<string, string>): string {
  return Object.keys(p).sort().map((k) => `${k}=${p[k]}`).join("&");
}

async function resolver(chartId: string, base: string, params: Record<string, string>) {
  const m = await manifesto();
  const candidatas = Object.values(m.entradas)
    .filter((e) => e.chart_id === chartId && e.base === base);
  if (!candidatas.length)
    throw new Error(
      `Esta combinação não entrou no snapshot da demo (${chartId} · ${base}). ` +
      `Na stack real ela roda: veja o README.`,
    );

  const alvo = canonico(params);
  const exata = candidatas.find((e) => canonico(e.params) === alvo);
  const escolhida = exata ?? candidatas.find((e) => e.padrao) ?? candidatas[0];

  publicar({
    tipo: exata ? "exato" : "aproximado",
    chartId, base,
    periodo: periodoDe(escolhida.params),
    segundos: escolhida.segundos,
  });

  return { entrada: escolhida, dados: await arquivo<unknown>(escolhida.arquivo) };
}

/** Snapshots disponiveis de um grafico numa base, na ordem do manifesto.
 *
 * O filtro da demo usa isto em vez dos atalhos de calendario: oferecer "ultimos
 * 30 dias" quando so' existe julho em disco seria prometer o que nao tem. O
 * primeiro da lista e o padrao — e o que o form abre preenchido.
 */
export async function snapshotsDe(chartId: string, base: string) {
  const m = await manifesto();
  const lista = Object.values(m.entradas)
    .filter((e) => e.chart_id === chartId && e.base === base);
  const padrao = lista.filter((e) => e.padrao);
  const resto = lista.filter((e) => !e.padrao);
  return [...padrao, ...resto].map((e) => ({
    label: rotulo(e.params),
    params: e.params,
    segundos: e.segundos,
  }));
}

/** "01/07 – 31/07/2026 · média por jogador" — o que distingue um snapshot do outro. */
function rotulo(p: Record<string, string>): string {
  const partes: string[] = [];
  if (p.date_start && p.date_end) partes.push(`${br(p.date_start)} – ${br(p.date_end)}`);
  if (p.variant && p.variant !== "total") partes.push(p.variant);
  const metricas = (p.metrics ?? "").split(",").filter(Boolean);
  if (metricas.length > 1) partes.push(`${metricas.length} métricas`);
  return partes.join(" · ") || "snapshot";
}

// --- jobs simulados --------------------------------------------------------- //
//
// A interface real inicia a consulta, recebe um id e faz polling: o gráfico só
// aparece quando o job termina. A demo mantém esse fluxo — inclusive o encerrar
// — para a tela ser a mesma; o que muda é que o "trabalho" é ler um JSON.

type Status = "queued" | "running" | "done" | "error" | "cancelled";

interface JobDemo {
  job_id: string;
  label: string;
  chart_id: string;
  base: string;
  params: Record<string, string>;
  status: Status;
  progress: number;
  step: string;
  inicio: number;
  /** Duração fingida na tela, proporcional à real mas em ~1,5 s. */
  duracao: number;
  segundos: number;
  result?: unknown;
  error?: string;
}

const jobs = new Map<string, JobDemo>();
let seq = 0;

/** Progresso e passo derivados do relógio: nada roda em background aqui. */
function tick(j: JobDemo) {
  if (j.status === "done" || j.status === "error" || j.status === "cancelled") return j;
  const frac = Math.min(1, (Date.now() - j.inicio) / j.duracao);
  if (frac >= 1) {
    j.status = j.error ? "error" : "done";
    j.progress = 100;
    j.step = "";
  } else {
    j.status = frac > 0.05 ? "running" : "queued";
    j.progress = Math.round(frac * 100);
    j.step = "Lendo o snapshot da demonstração";
  }
  return j;
}

function publico(j: JobDemo, comResultado: boolean) {
  tick(j);
  const feito = j.status === "done" || j.status === "error";
  return {
    job_id: j.job_id,
    label: j.label,
    status: j.status,
    progress: j.progress,
    step: j.step,
    chart_id: j.chart_id,
    base: j.base,
    params: j.params,
    // Concluído: mostra a duração real da consulta que gerou o arquivo, não o
    // 1,5 s de leitura de JSON — o número na tela é o custo verdadeiro.
    elapsed_seconds: feito ? j.segundos : (Date.now() - j.inicio) / 1000,
    ...(comResultado && j.status === "done" ? { result: j.result } : {}),
    ...(j.status === "error" ? { error: j.error } : {}),
  };
}

async function iniciar(chartId: string, base: string, params: Record<string, string>) {
  const job_id = `demo-${++seq}`;
  const j: JobDemo = {
    job_id, label: `${chartId} (${base})`, chart_id: chartId, base, params,
    status: "queued", progress: 0, step: "", inicio: Date.now(),
    duracao: 1500, segundos: 0,
  };
  jobs.set(job_id, j);
  try {
    const { entrada, dados } = await resolver(chartId, base, params);
    j.result = dados;
    j.segundos = entrada.segundos;
  } catch (e: any) {
    j.error = e?.message ?? "falha ao ler o snapshot";
    // Erro também espera: piscar a mensagem antes da barra aparecer confunde.
    j.duracao = 600;
  }
  return { job_id };
}

// --- roteador --------------------------------------------------------------- //

/** Responde a uma URL da API a partir dos arquivos do snapshot. */
export async function demoJSON<T>(url: string, init?: RequestInit): Promise<T> {
  const u = new URL(url, window.location.origin);
  const rota = u.pathname.replace(/^\/api/, "");
  const q = u.searchParams;
  const params: Record<string, string> = {};
  q.forEach((v, k) => { if (k !== "base") params[k] = v; });
  const base = q.get("base") ?? "";
  const metodo = (init?.method ?? "GET").toUpperCase();

  if (rota === "/bases") return arquivo<T>("bases.json");
  if (rota === "/meta") return arquivo<T>("meta.json");
  if (rota === "/health/db") return arquivo<T>("health.json");
  if (rota === "/charts") return arquivo<T>(`charts__${base}.json`);

  const dados = rota.match(/^\/charts\/([^/]+)\/data$/);
  if (dados) return (await resolver(dados[1], base, params)).dados as T;

  const start = rota.match(/^\/charts\/([^/]+)\/start$/);
  if (start) return (await iniciar(start[1], base, params)) as T;

  if (rota === "/jobs")
    return [...jobs.values()].map((j) => publico(j, false)).reverse() as T;

  const um = rota.match(/^\/jobs\/([^/]+)$/);
  if (um) {
    const j = jobs.get(um[1]);
    if (!j) throw new Error("Job não encontrado ou expirado.");
    return publico(j, true) as T;
  }

  const cancel = rota.match(/^\/jobs\/([^/]+)\/cancel$/);
  if (cancel && metodo === "POST") {
    const j = jobs.get(cancel[1]);
    if (!j) throw new Error("Job não encontrado ou expirado.");
    j.status = "cancelled";
    j.step = "";
    return publico(j, false) as T;
  }

  throw new Error(`Rota fora da demonstração: ${u.pathname}`);
}
