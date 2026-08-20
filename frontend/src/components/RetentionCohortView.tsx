import { useMemo, useState } from "react";
import { Line } from "react-chartjs-2";
import {
  Chart as ChartJS, CategoryScale, LinearScale, PointElement, LineElement,
  Tooltip, Legend, type ChartOptions,
} from "chart.js";
import { download, fileName, toCSV } from "../lib/csv";
import { compact } from "../lib/viz";

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Tooltip, Legend);

type Point = [number, number, number]; // [mes_index, valor_plotado, valor_exato]
interface Series { label: string; points: Point[]; }
interface Metric {
  key: string; label: string; col: string;
  /** "k" = plotado em milhar (visão Total); "abs" = reais por jogador. */
  unit?: "k" | "abs";
  axis?: string;
  series: Series[]; kpis: {label:string;value:string}[]; insights: string[];
}
interface Data {
  base: string; periodo: string; empty?: boolean; message?: string;
  variant?: string; variant_label?: string;
  /** "jogador" ou "cliente", conforme a vertical do backend. */
  unidade_ativo?: string;
  metrics: Metric[];
}

const palette = (n: number) =>
  Array.from({ length: n }, (_, i) => `hsl(${Math.round((360 * i) / Math.max(n, 1))},68%,58%)`);
const fade = (hsl: string, a: number) => hsl.replace("hsl(", "hsla(").replace(")", `,${a})`);
const fmtK = (v: number) => {
  if (v === 0) return "0";
  const a = Math.abs(v);
  if (a >= 1000) return (v / 1000).toFixed(1).replace(/\.0$/, "") + "M";
  return Number.isInteger(v) ? v + "k" : v.toFixed(1) + "k";
};
const brl = (v: number) => v.toLocaleString("pt-BR", { style: "currency", currency: "BRL" });

/** Converte o `<b>` dos insights em elemento React.
 *
 *  Antes isto ia por `dangerouslySetInnerHTML`. O texto é montado no backend e
 *  hoje só carrega rótulo de cohort e número — mas basta um insight passar a
 *  citar nome de provedor ou afiliado vindo do banco para virar XSS. Aqui só
 *  `<b>` existe; qualquer outra marcação aparece como texto literal.
 */
function destacar(texto: string) {
  return texto.split(/<b>(.*?)<\/b>/g).map((parte, i) =>
    i % 2 === 1 ? <strong key={i}>{parte}</strong> : parte);
}

/** Arredonda para cima até um valor "redondo" — sem isso o topo do eixo vira
 *  51.847 e os ticks saem quebrados.
 *
 *  A régua é fina de propósito: com passos só de 1/2/5, um pico de 52 subiria o
 *  eixo até 100 e devolveria metade do espaço vazio que essa função existe para
 *  eliminar. */
const PASSOS = [1, 1.2, 1.5, 1.8, 2, 2.2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5, 6, 7, 8, 9, 10];

function tetoRedondo(v: number): number {
  if (v <= 0) return 0;
  const escala = 10 ** Math.floor(Math.log10(v));
  const passo = PASSOS.find((p) => v <= p * escala) ?? 10;
  return passo * escala;
}

/** Limites do eixo Y considerando só as linhas em foco.
 *
 *  Com 5 milhões no topo, um cohort de 49 mil vira uma reta colada no zero. A
 *  escala acompanha a seleção: com nada selecionado usa todas as linhas.
 *
 *  O piso fica em zero quando não há valor negativo — encolher a base também
 *  ampliaria a variação e faria uma curva quase plana parecer uma queda.
 */
function limites(series: Series[], selecionadas: Set<number>) {
  const nenhuma = selecionadas.size === 0;
  const ys = series
    .filter((_, i) => nenhuma || selecionadas.has(i))
    .flatMap((s) => s.points.map((p) => p[1]))
    .filter((y) => Number.isFinite(y));

  if (!ys.length) return { min: undefined, max: undefined };

  const maior = Math.max(...ys);
  const menor = Math.min(...ys);

  // Série inteira em zero (ou só negativos): deixa o Chart.js decidir.
  if (maior <= 0) return { min: undefined, max: 0 };

  return {
    // 3% de folga: o suficiente para o pico não encostar na borda.
    min: menor < 0 ? -tetoRedondo(Math.abs(menor) * 1.03) : 0,
    max: tetoRedondo(maior * 1.03),
  };
}

function MetricPanel({ metric, base, periodo, variante }:
  { metric: Metric; base: string; periodo: string; variante?: string }) {
  // Média por jogador anda na casa das centenas: plotar em milhar viraria "0,5k".
  const emReais = metric.unit === "abs";
  const fmtEixo = (v: number) => (emReais ? compact(v, "currency") : fmtK(v));
  const fmtPonto = (v: number) => (emReais ? brl(v) : fmtK(v));
  const colors = useMemo(() => palette(metric.series.length), [metric]);
  const [selected, setSelected] = useState<Set<number>>(new Set());
  const toggle = (i: number) =>
    setSelected((s) => { const n = new Set(s); n.has(i) ? n.delete(i) : n.add(i); return n; });

  const none = selected.size === 0;
  const escala = useMemo(() => limites(metric.series, selected), [metric, selected]);
  const datasets = metric.series.map((s, i) => {
    const on = none || selected.has(i);
    return {
      label: s.label,
      data: s.points.map((p) => ({ x: p[0], y: p[1], exact: p[2] })),
      borderColor: on ? colors[i] : fade(colors[i], 0.12),
      backgroundColor: on ? colors[i] : fade(colors[i], 0.12),
      borderWidth: !none && selected.has(i) ? 3 : 1.8,
      pointRadius: on ? 2.2 : 0,
      pointHoverRadius: 6,
      pointHitRadius: on ? (none ? 12 : 16) : 0,
      tension: 0.25,
      spanGaps: true,
    };
  });

  const options: ChartOptions<"line"> = {
    responsive: true, maintainAspectRatio: false,
    interaction: { mode: "nearest", intersect: true, axis: "xy" },
    onClick: (_e, els) => { if (els.length) toggle(els[0].datasetIndex); },
    scales: {
      x: { type: "linear", title: { display: true, text: "Meses desde a aquisição" }, ticks: { stepSize: 1 }, grid: { display: false } },
      y: {
        title: { display: true, text: metric.axis ?? `${metric.label} (k)` },
        ticks: { callback: (v) => fmtEixo(Number(v)) },
        grid: { color: "rgba(128,128,128,0.14)" },
        // Reage à seleção: as linhas fora de foco continuam desenhadas (e são
        // cortadas pela área do gráfico), mas não mandam mais no eixo.
        min: escala.min,
        max: escala.max,
      },
    },
    plugins: {
      legend: { position: "top", labels: { boxWidth: 12, usePointStyle: true }, onClick: (_e, item) => toggle(item.datasetIndex!) },
      tooltip: {
        filter: (item) => none || selected.has(item.datasetIndex),
        callbacks: {
          title: (items) => `Mês ${items[0].parsed.x}`,
          // parsed.y é `number | null` no tipo do Chart.js: Number() normaliza.
          label: (item) => `${item.dataset.label} · ${metric.label}: ${fmtPonto(Number(item.parsed.y))}`,
          // Em reais o plotado já é o valor cheio; repetir seria ruído.
          afterLabel: (item) =>
            emReais ? "" : `Valor exato: ${brl((item.raw as any).exact)}`,
        },
      },
    },
  };

  const rows = metric.series.flatMap((s, ci) => s.points.map((p) => ({ ci, label: s.label, mi: p[0], exact: p[2] })));

  // O CSV leva a tabela inteira, como ela aparece: destacar cohort é leitura, não
  // filtro. Vai o valor exato (não o arredondado em milhar do gráfico).
  const colunas = ["cohort", "mes_index", metric.col];
  const linhasCSV = rows.map((r) => [r.label, r.mi, r.exact]);
  const csvName = fileName(base, "Retention Cohort", variante, metric.label, periodo);

  return (
    <div>
      <div className="panel"><div className="body"><div className="chart-box"><Line data={{ datasets }} options={options} /></div></div></div>

      <div className="kpis">
        {metric.kpis.map((k, i) => (
          <div className="kpi" key={i}><div className="v">{k.value}</div><div className="l">{k.label}</div></div>
        ))}
      </div>

      <div className="panel">
        <div className="head">
          <strong>Resultado da consulta — {metric.label}</strong>
          <span className="head-acoes">
            <span className="muted" style={{ fontSize: 11 }}>clique numa linha p/ destacar</span>
            <button className="btn ghost" disabled={!rows.length} title={csvName}
              onClick={() => download(toCSV(colunas, linhasCSV), csvName)}>
              Baixar CSV
            </button>
          </span>
        </div>
        <div className="body">
          <div className="result-wrap">
            <table className="grid-tbl">
              <thead><tr><th>cohort</th><th>mes_index</th><th>{metric.col}</th></tr></thead>
              <tbody>
                {rows.map((r, i) => {
                  const on = selected.has(r.ci);
                  return (
                    <tr key={i} onClick={() => toggle(r.ci)}
                      style={on ? { background: fade(colors[r.ci], 0.16), boxShadow: `inset 3px 0 0 ${colors[r.ci]}` } : undefined}>
                      <td><span className="cdot" style={{ background: colors[r.ci] }} />{r.label}</td>
                      <td className="num">{r.mi}</td>
                      <td className="num">{r.exact.toLocaleString("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div className="panel" style={{ marginTop: 16 }}>
        <div className="head"><strong>Resumo &amp; insights</strong></div>
        <div className="body"><ul className="insights">{metric.insights.map((t, i) => <li key={i}>{destacar(t)}</li>)}</ul></div>
      </div>
    </div>
  );
}

export default function RetentionCohortView({ data }: { data: Data }) {
  const [active, setActive] = useState(0);
  if (data.empty) return <p className="muted">{data.message ?? "Sem dados."}</p>;

  return (
    <div>
      <p className="sub">
        Período {data.periodo} · {data.variant_label ?? "Total"} ·{" "}
        {data.variant && data.variant !== "total"
          ? `valores em reais por ${data.unidade_ativo ?? "jogador"} ativo (mês 0 = cohort)`
          : "valores em milhar (mês 0 = cohort)"}
      </p>
      <div className="tabs">
        {data.metrics.map((m, i) => (
          <button key={m.key} className={"tab" + (i === active ? " active" : "")} onClick={() => setActive(i)}>{m.label}</button>
        ))}
      </div>
      {data.metrics[active] && (
        <MetricPanel key={data.metrics[active].key} metric={data.metrics[active]}
          base={data.base} periodo={data.periodo} variante={data.variant_label} />
      )}
    </div>
  );
}
