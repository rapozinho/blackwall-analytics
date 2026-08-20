import {
  createContext, useCallback, useContext, useEffect, useMemo, useRef, useState,
  type ReactNode,
} from "react";
import { api, type JobStatus } from "./api";

/** Consulta acompanhada pela interface.
 *
 * O polling vive aqui, e não na página do gráfico: sair da tela não pode
 * cancelar o acompanhamento — a consulta continua no servidor de qualquer jeito,
 * e antes disto o resultado se perdia quando o usuário navegava.
 */
export interface Consulta {
  id: string;
  chartId: string;
  base: string;
  label: string;
  params: Record<string, string>;
  status: JobStatus["status"];
  progress: number;
  step: string;
  elapsed: number | null;
  result?: any;
  error?: string;
  /** Relógio do cliente, só para ordenar a lista. */
  iniciada: number;
}

interface Ctx {
  consultas: Consulta[];
  /** Consulta mais recente de um gráfico numa base (ativa ou já concluída). */
  para: (chartId: string, base: string) => Consulta | undefined;
  /** Segundos da última execução bem-sucedida — o custo real desta máquina
   *  contra este banco, não uma estimativa genérica. */
  duracao: (chartId: string, base: string) => number | undefined;
  iniciar: (chartId: string, base: string, label: string,
            params: Record<string, string>) => Promise<void>;
  encerrar: (id: string) => Promise<void>;
  descartar: (id: string) => void;
}

const JobsCtx = createContext<Ctx | null>(null);
const CHAVE = "blackwall.consultas";
const CHAVE_DUR = "blackwall.duracoes";
const POLL_MS = 2000;

/** Histórico de duração por gráfico+base. Guardado à parte das consultas: ele
 *  sobrevive ao "dispensar" e é o que a galeria usa para avisar o custo antes
 *  de o usuário clicar. */
function lerDuracoes(): Record<string, number> {
  try {
    const bruto = JSON.parse(localStorage.getItem(CHAVE_DUR) ?? "{}");
    return bruto && typeof bruto === "object" ? bruto : {};
  } catch {
    return {};
  }
}

const ativo = (s: JobStatus["status"]) => s === "queued" || s === "running";

/** Persiste só a identidade — resultado de report grande não cabe no storage e
 *  volta do servidor quando necessário. */
function salvar(consultas: Consulta[]) {
  const enxuto = consultas.map(({ id, chartId, base, label, params, iniciada }) =>
    ({ id, chartId, base, label, params, iniciada }));
  try {
    localStorage.setItem(CHAVE, JSON.stringify(enxuto));
  } catch {
    /* storage cheio ou bloqueado: acompanhar em memória ainda funciona */
  }
}

function carregar(): Consulta[] {
  try {
    const bruto = JSON.parse(localStorage.getItem(CHAVE) ?? "[]");
    if (!Array.isArray(bruto)) return [];
    return bruto.map((c: any) => ({
      ...c, status: "queued" as const, progress: 0, step: "", elapsed: null,
    }));
  } catch {
    return [];
  }
}

export function JobsProvider({ children }: { children: ReactNode }) {
  const [consultas, setConsultas] = useState<Consulta[]>(carregar);
  // Ref espelha o estado: o loop de polling não pode virar dependência do
  // efeito, senão reinicia a cada tick.
  const ref = useRef(consultas);
  ref.current = consultas;

  const [duracoes, setDuracoes] = useState<Record<string, number>>(lerDuracoes);

  const aplicar = useCallback((id: string, job: JobStatus) => {
    // Só consulta concluída vira histórico: erro e cancelamento param no meio e
    // registrariam um tempo que não corresponde ao trabalho completo.
    if (job.status === "done" && job.elapsed_seconds != null && job.chart_id && job.base) {
      setDuracoes((atual) => {
        const proximas = { ...atual, [`${job.base}:${job.chart_id}`]: job.elapsed_seconds! };
        try { localStorage.setItem(CHAVE_DUR, JSON.stringify(proximas)); } catch { /* ignora */ }
        return proximas;
      });
    }

    setConsultas((atual) => {
      const proximas = atual.map((c) => c.id !== id ? c : {
        ...c,
        status: job.status,
        progress: job.progress,
        step: job.step,
        elapsed: job.elapsed_seconds,
        error: job.error,
        // Lista não traz `result`; preserva o que já tinha.
        result: job.result !== undefined ? job.result : c.result,
      });
      salvar(proximas);
      return proximas;
    });
  }, []);

  useEffect(() => {
    let vivo = true;

    async function tick() {
      const pendentes = ref.current.filter((c) => ativo(c.status));
      if (!pendentes.length) return;

      await Promise.all(pendentes.map(async (c) => {
        try {
          const job = await api.job(c.id);
          if (vivo) aplicar(c.id, job);
        } catch {
          // 404 = job expirou no servidor (TTL) ou o backend reiniciou. Sai da
          // lista em vez de piscar "consultando" para sempre.
          if (vivo) setConsultas((atual) => {
            const proximas = atual.filter((x) => x.id !== c.id);
            salvar(proximas);
            return proximas;
          });
        }
      }));
    }

    tick();                                   // reidrata logo ao abrir a aba
    const t = setInterval(tick, POLL_MS);
    return () => { vivo = false; clearInterval(t); };
  }, [aplicar]);

  const iniciar = useCallback(async (chartId: string, base: string, label: string,
                                     params: Record<string, string>) => {
    const { job_id } = await api.startJob(chartId, base, params);
    setConsultas((atual) => {
      // Uma consulta por gráfico+base: disparar de novo substitui a anterior em
      // vez de empilhar duas linhas do mesmo relatório na tela inicial.
      const proximas: Consulta[] = [
        { id: job_id, chartId, base, label, params, status: "queued",
          progress: 0, step: "", elapsed: null, iniciada: Date.now() },
        ...atual.filter((c) => !(c.chartId === chartId && c.base === base)),
      ];
      salvar(proximas);
      return proximas;
    });
  }, []);

  const encerrar = useCallback(async (id: string) => {
    try {
      const job = await api.cancelJob(id);
      aplicar(id, job);
    } catch {
      // Some do painel de qualquer forma: insistir em mostrar algo que o
      // servidor não conhece mais não ajuda ninguém.
      setConsultas((atual) => {
        const proximas = atual.filter((c) => c.id !== id);
        salvar(proximas);
        return proximas;
      });
    }
  }, [aplicar]);

  const descartar = useCallback((id: string) => {
    setConsultas((atual) => {
      const proximas = atual.filter((c) => c.id !== id);
      salvar(proximas);
      return proximas;
    });
  }, []);

  const para = useCallback((chartId: string, base: string) =>
    ref.current.find((c) => c.chartId === chartId && c.base === base), []);

  const duracao = useCallback(
    (chartId: string, base: string) => duracoes[`${base}:${chartId}`],
    [duracoes],
  );

  const valor = useMemo<Ctx>(
    () => ({ consultas, para, duracao, iniciar, encerrar, descartar }),
    [consultas, para, duracao, iniciar, encerrar, descartar],
  );

  return <JobsCtx.Provider value={valor}>{children}</JobsCtx.Provider>;
}

export function useJobs(): Ctx {
  const ctx = useContext(JobsCtx);
  if (!ctx) throw new Error("useJobs precisa do <JobsProvider>.");
  return ctx;
}
