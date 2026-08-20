import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { fmtDuration } from "../lib/api";
import { useJobs, type Consulta } from "../lib/jobs";

/** Duração da desintegração. Casa com `bw-desintegra` no styles.css — mudar num
 *  lugar sem o outro deixa a linha sumir antes da hora ou piscar de volta. */
const DESINTEGRA_MS = 620;

/** Estado da consulta na linguagem da parede: o LED diz o que está havendo. */
const ESTADO: Record<Consulta["status"], { tag: string; cls: string }> = {
  queued:    { tag: "na fila",   cls: "fila" },
  running:   { tag: "rodando",   cls: "roda" },
  done:      { tag: "pronta",    cls: "ok" },
  error:     { tag: "falhou",    cls: "err" },
  cancelled: { tag: "encerrada", cls: "off" },
};

/** Resumo do filtro: as datas são o que identifica uma consulta na lista. */
function resumo(c: Consulta): string {
  const br = (iso?: string) => (iso ? iso.split("-").reverse().join("/") : "");
  const partes: string[] = [];
  if (c.params.date_start && c.params.date_end)
    partes.push(`${br(c.params.date_start)} – ${br(c.params.date_end)}`);
  if (c.params.date_start2 && c.params.date_end2)
    partes.push(`vs ${br(c.params.date_start2)} – ${br(c.params.date_end2)}`);
  if (c.params.metrics) partes.push(c.params.metrics.split(",").join(" · "));
  return partes.join("  ");
}

/** `base` limita a lista à operação aberta — dentro de uma base, consulta de
 *  outra é ruído. Sem ela mostra tudo (tela inicial). */
export default function ConsultasAtivas({ base }: { base?: string } = {}) {
  const { consultas: todas, encerrar, descartar } = useJobs();
  // Linhas que já receberam "Dispensar": continuam montadas até a animação
  // terminar, senão o React as removeria antes de dar tempo de ver.
  const [sumindo, setSumindo] = useState<Set<string>>(new Set());
  const timers = useRef<number[]>([]);

  useEffect(() => () => { timers.current.forEach(clearTimeout); }, []);

  function dispensar(id: string, alvo: HTMLElement) {
    // `height: auto` não anima: o colapso precisa da altura real, medida agora e
    // publicada como variável CSS na própria linha.
    const linha = alvo.closest(".tx") as HTMLElement | null;
    if (linha) linha.style.setProperty("--tx-h", `${linha.offsetHeight}px`);

    setSumindo((s) => new Set(s).add(id));
    const reduzido = matchMedia("(prefers-reduced-motion: reduce)").matches;
    timers.current.push(window.setTimeout(() => {
      descartar(id);
      setSumindo((s) => { const n = new Set(s); n.delete(id); return n; });
    }, reduzido ? 0 : DESINTEGRA_MS));
  }

  const consultas = base ? todas.filter((c) => c.base === base) : todas;
  if (!consultas.length) return null;

  const rodando = consultas.filter((c) => c.status === "queued" || c.status === "running").length;

  return (
    <section className="transmissoes" aria-label="Consultas em andamento">
      <h2 className="transmissoes-t">
        Consultas
        <span className="transmissoes-n">
          {rodando ? `${rodando} em andamento` : `${consultas.length} recente(s)`}
        </span>
      </h2>

      <ul className="tx-lista">
        {consultas.map((c) => {
          const e = ESTADO[c.status];
          const ativa = c.status === "queued" || c.status === "running";
          const indo = sumindo.has(c.id);
          return (
            <li key={c.id} className={`tx st-${e.cls}${indo ? " desintegra" : ""}`}
              aria-hidden={indo || undefined}>
              <Link to={`/${c.base}/${c.chartId}`} className="tx-alvo">
                <span className="tx-led" aria-hidden="true" />
                <span className="tx-nome">
                  {c.label}
                  <span className="tx-base">{c.base}</span>
                </span>
                <span className="tx-resumo">{resumo(c)}</span>
                <span className="tx-estado">
                  {e.tag}
                  {c.elapsed !== null && ` · ${fmtDuration(c.elapsed)}`}
                </span>
              </Link>

              {ativa ? (
                <button className="tx-acao abortar" onClick={() => encerrar(c.id)}
                  title="Derruba a consulta no banco">
                  Encerrar
                </button>
              ) : (
                <button className="tx-acao" disabled={indo}
                  onClick={(ev) => dispensar(c.id, ev.currentTarget)}
                  title="Tira da lista; o resultado continua no servidor por 30 min">
                  Dispensar
                </button>
              )}

              {/* Barra viva só enquanto roda: parada, ela mentiria sobre o estado. */}
              <span className="tx-barra" aria-hidden="true">
                <span className="tx-barra-fill" style={{ width: `${ativa ? c.progress : 100}%` }} />
              </span>
              {ativa && c.step && <span className="tx-passo">{c.step}</span>}
            </li>
          );
        })}
      </ul>
    </section>
  );
}
