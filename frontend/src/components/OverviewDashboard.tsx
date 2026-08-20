import { useMemo, useState } from "react";
import { Bar, Line } from "react-chartjs-2";
import {
  Chart as ChartJS, BarElement, CategoryScale, Filler, LineElement, LinearScale,
  PointElement, Tooltip, type ChartOptions,
} from "chart.js";
import DonutPanel from "./DonutPanel";
import {
  SERIES, POS, NEG, agrupar, compact, delta, exact, soma,
  type Format, type Grain,
} from "../lib/viz";
import type { DashboardData, SeriePonto } from "../lib/api";

ChartJS.register(BarElement, CategoryScale, Filler, LineElement, LinearScale, PointElement, Tooltip);

const GRAOS: { key: Grain; label: string }[] = [
  { key: "dia", label: "Diário" },
  { key: "semana", label: "Semanal" },
  { key: "mes", label: "Mensal" },
];

/** Métricas da linha do tempo. `split` = tem quebra entre as duas operações.
 *
 * O `label` aqui é o da vertical de apostas e serve de fallback: o rótulo real vem
 * em `data.labels` (o backend sabe se é "GGR" ou "Receita"). A `key` nunca muda —
 * é ela que liga a métrica ao campo da série. */
const METRICAS: { key: string; label: string; format: Format; campo: (r: SeriePonto) => number; split?: boolean }[] = [
  { key: "ggr", label: "GGR", format: "currency", campo: (r) => r.ggr, split: true },
  { key: "ngr", label: "NGR", format: "currency", campo: (r) => r.ngr },
  { key: "turnover", label: "Turnover", format: "currency", campo: (r) => r.turnover },
  { key: "depositos", label: "Depósitos", format: "currency", campo: (r) => r.depositos },
  { key: "netcash", label: "Netcash", format: "currency", campo: (r) => r.netcash },
  { key: "ftds", label: "FTDs", format: "int", campo: (r) => r.ftds },
];

/** Rótulo das duas operações, com o par de apostas como fallback. */
const OPS_PADRAO = { casino: "Casino", sports: "Sportsbook" };

/** Acima disso a barra fica com 1px e vira serrote: troca por linha. */
const LIMITE_BARRAS = 62;

function Kpi({ kpi }: { kpi: DashboardData["kpis"][number] }) {
  const subiu = kpi.delta !== null && kpi.delta > 0;
  const desceu = kpi.delta !== null && kpi.delta < 0;
  const bom = kpi.higher_is_better ? subiu : desceu;
  const ruim = kpi.higher_is_better ? desceu : subiu;
  const cor = bom ? POS : ruim ? NEG : undefined;

  return (
    <div className="tile" title={kpi.hint}>
      <span className="tile-l">{kpi.label}</span>
      <span className="tile-v">{compact(kpi.value, kpi.format as Format)}</span>
      <span className="tile-d" style={cor ? { color: cor } : undefined}>
        <span aria-hidden="true">{subiu ? "▲" : desceu ? "▼" : "—"}</span>
        {delta(kpi.delta, kpi.delta_unit)}
        <span className="tile-prev">vs {compact(kpi.previous, kpi.format as Format)}</span>
      </span>
    </div>
  );
}

function Evolucao({ series, labels: termos, ops }: {
  series: SeriePonto[];
  labels: Record<string, string>;
  ops: { casino: string; sports: string };
}) {
  const [grain, setGrain] = useState<Grain>("dia");
  const [metrica, setMetrica] = useState(METRICAS[0]);
  const rotulo = (m: { key: string; label: string }) => termos[m.key] ?? m.label;

  const buckets = useMemo(() => agrupar(series, grain), [series, grain]);
  const labels = buckets.map((b) => b.label);
  const usarLinha = buckets.length > LIMITE_BARRAS;

  const valores = buckets.map((b) => soma(b.rows, metrica.campo));
  const casino = buckets.map((b) => soma(b.rows, (r) => r.ggr_casino));
  const sports = buckets.map((b) => soma(b.rows, (r) => r.ggr_sports));
  const partido = !!metrica.split && !usarLinha;

  const eixo = {
    x: {
      grid: { display: false },
      border: { color: "#1b2434" },
      ticks: {
        color: "#8593a8", font: { family: "Arial, Helvetica, sans-serif", size: 10 },
        maxRotation: 0, autoSkipPadding: 18,
      },
    },
    y: {
      grid: { color: "rgba(49,64,79,.34)" },
      border: { display: false },
      ticks: {
        color: "#8593a8", font: { family: "Arial, Helvetica, sans-serif", size: 10 },
        callback: (v: string | number) => compact(Number(v), metrica.format),
      },
    },
  };

  const tooltip = {
    backgroundColor: "#0e141f", borderColor: "#31404f", borderWidth: 1, padding: 10,
    titleFont: { family: "Arial, Helvetica, sans-serif" },
    bodyFont: { family: "Arial, Helvetica, sans-serif" },
    callbacks: {
      title: (items: any[]) => buckets[items[0].dataIndex]?.title ?? "",
      label: (item: any) =>
        `${item.dataset.label}: ${exact(Number(item.parsed.y), metrica.format)}`,
    },
  };

  const comum = {
    responsive: true, maintainAspectRatio: false,
    interaction: { mode: "index" as const, intersect: false },
    plugins: { legend: { display: false }, tooltip },
    scales: eixo,
  };

  const dadosBarra = {
    labels,
    datasets: partido
      ? [
          { label: ops.casino, data: casino, backgroundColor: SERIES[0], stack: "ggr",
            borderRadius: 0, borderColor: "#0a0e16", borderWidth: { top: 2 } as any },
          { label: ops.sports, data: sports, backgroundColor: SERIES[3], stack: "ggr",
            borderRadius: { topLeft: 4, topRight: 4 } as any },
        ]
      : [{ label: rotulo(metrica), data: valores, backgroundColor: SERIES[0],
           borderRadius: { topLeft: 4, topRight: 4 } as any }],
  };

  const dadosLinha = {
    labels,
    datasets: [{
      label: rotulo(metrica), data: valores,
      borderColor: SERIES[0], backgroundColor: "rgba(15,156,181,.14)",
      borderWidth: 2, pointRadius: 0, pointHoverRadius: 5, tension: 0.22, fill: true,
    }],
  };

  const total = valores.reduce((a, v) => a + v, 0);
  const pico = buckets[valores.indexOf(Math.max(...valores))];

  return (
    <section className="panel viz">
      <div className="head">
        <strong>
          {rotulo(metrica)} por período
          {partido && (
            <span className="muted"> · {ops.casino.toLowerCase()} + {ops.sports.toLowerCase()}</span>
          )}
        </strong>
        <div className="seg" role="group" aria-label="Granularidade">
          {GRAOS.map((g) => (
            <button key={g.key} className={"seg-btn" + (g.key === grain ? " on" : "")}
              onClick={() => setGrain(g.key)}>{g.label}</button>
          ))}
        </div>
      </div>

      <div className="metricas" role="group" aria-label="Métrica">
        {METRICAS.map((m) => (
          <button key={m.key} className={"pill" + (m.key === metrica.key ? " on" : "")}
            onClick={() => setMetrica(m)}>{rotulo(m)}</button>
        ))}
      </div>

      <div className="body">
        <div className="chart-box serie">
          {usarLinha
            ? <Line data={dadosLinha} options={comum as ChartOptions<"line">} />
            : <Bar data={dadosBarra} options={{
                ...comum,
                scales: partido
                  ? { x: { ...eixo.x, stacked: true }, y: { ...eixo.y, stacked: true } }
                  : eixo,
              } as ChartOptions<"bar">} />}
        </div>
        {partido && (
          <ul className="legenda-inline">
            <li><span className="cdot" style={{ background: SERIES[0] }} />{ops.casino}</li>
            <li><span className="cdot" style={{ background: SERIES[3] }} />{ops.sports}</li>
          </ul>
        )}
      </div>

      <div className="viz-foot">
        <span className="muted">
          {buckets.length} {grain === "dia" ? "dias" : grain === "semana" ? "semanas" : "meses"} ·
          total {exact(total, metrica.format)}
          {pico && ` · pico em ${pico.title.toLowerCase()}`}
        </span>
      </div>
    </section>
  );
}

export default function OverviewDashboard({ data }: { data: DashboardData }) {
  if (data.empty)
    return <p className="muted">Sem movimento no período selecionado.</p>;

  return (
    <div className="dash">
      <p className="sub dash-periodo">
        <strong>{data.periodo}</strong>
        <span className="muted"> comparado com {data.periodo_anterior}</span>
      </p>

      {data.notes.map((n, i) => (
        <p className="aviso" key={i}><span aria-hidden="true">!</span>{n}</p>
      ))}

      <div className="tiles">
        {data.kpis.map((k) => <Kpi key={k.key} kpi={k} />)}
      </div>

      <Evolucao series={data.series} labels={data.labels ?? {}}
        ops={data.verticais ?? OPS_PADRAO} />

      <div className="donuts">
        {data.donuts.map((d) => <DonutPanel key={d.id} donut={d} />)}
      </div>
    </div>
  );
}
