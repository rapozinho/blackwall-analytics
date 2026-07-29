import { useMemo, useState } from "react";
import { Line } from "react-chartjs-2";
import {
  Chart as ChartJS, CategoryScale, LinearScale, PointElement, LineElement,
  Tooltip, Legend, type ChartOptions,
} from "chart.js";

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Tooltip, Legend);

type Point = [number, number, number]; // [mes_index, valor_k, valor_bruto]
interface Series { label: string; points: Point[]; }
interface Metric { key: string; label: string; col: string; series: Series[]; kpis: {label:string;value:string}[]; insights: string[]; }
interface Data { base: string; periodo: string; empty?: boolean; message?: string; metrics: Metric[]; }

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

function MetricPanel({ metric }: { metric: Metric }) {
  const colors = useMemo(() => palette(metric.series.length), [metric]);
  const [selected, setSelected] = useState<Set<number>>(new Set());
  const toggle = (i: number) =>
    setSelected((s) => { const n = new Set(s); n.has(i) ? n.delete(i) : n.add(i); return n; });

  const none = selected.size === 0;
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
      y: { title: { display: true, text: `${metric.label} (k)` }, ticks: { callback: (v) => fmtK(Number(v)) }, grid: { color: "rgba(128,128,128,0.14)" } },
    },
    plugins: {
      legend: { position: "top", labels: { boxWidth: 12, usePointStyle: true }, onClick: (_e, item) => toggle(item.datasetIndex!) },
      tooltip: {
        filter: (item) => none || selected.has(item.datasetIndex),
        callbacks: {
          title: (items) => `Mês ${items[0].parsed.x}`,
          label: (item) => `${item.dataset.label} · ${metric.label}: ${fmtK(item.parsed.y)}`,
          afterLabel: (item) => `Valor exato: ${brl((item.raw as any).exact)}`,
        },
      },
    },
  };

  const rows = metric.series.flatMap((s, ci) => s.points.map((p) => ({ ci, label: s.label, mi: p[0], exact: p[2] })));

  return (
    <div>
      <div className="panel"><div className="body"><div className="chart-box"><Line data={{ datasets }} options={options} /></div></div></div>

      <div className="kpis">
        {metric.kpis.map((k, i) => (
          <div className="kpi" key={i}><div className="v">{k.value}</div><div className="l">{k.label}</div></div>
        ))}
      </div>

      <div className="panel">
        <div className="head"><strong>Resultado da consulta — {metric.label}</strong><span className="muted" style={{ fontSize: 11 }}>clique numa linha p/ destacar</span></div>
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
        <div className="body"><ul className="insights">{metric.insights.map((t, i) => <li key={i} dangerouslySetInnerHTML={{ __html: t }} />)}</ul></div>
      </div>
    </div>
  );
}

export default function RetentionCohortView({ data }: { data: Data }) {
  const [active, setActive] = useState(0);
  if (data.empty) return <p className="muted">{data.message ?? "Sem dados."}</p>;

  return (
    <div>
      <p className="sub">Período {data.periodo} · valores em milhar (mês 0 = cohort)</p>
      <div className="tabs">
        {data.metrics.map((m, i) => (
          <button key={m.key} className={"tab" + (i === active ? " active" : "")} onClick={() => setActive(i)}>{m.label}</button>
        ))}
      </div>
      {data.metrics[active] && <MetricPanel key={data.metrics[active].key} metric={data.metrics[active]} />}
    </div>
  );
}
