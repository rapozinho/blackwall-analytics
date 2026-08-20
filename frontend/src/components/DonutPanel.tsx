import { useMemo, useState } from "react";
import { Doughnut } from "react-chartjs-2";
import {
  Chart as ChartJS, ArcElement, Tooltip, type ChartOptions,
} from "chart.js";
import { SERIES, REST, SURFACE, MAX_SLICES, compact, exact, type Format } from "../lib/viz";
import type { Donut } from "../lib/api";

ChartJS.register(ArcElement, Tooltip);

/** Fatias acima do limite viram uma só. Oito matizes é o teto do que se
 *  distingue com daltonismo; acima disso a pizza vira confete. A tabela
 *  embaixo continua mostrando tudo. */
function recortar(slices: Donut["slices"], metric: string) {
  const ordenado = [...slices]
    .map((s) => ({ label: s.label, value: s.values[metric] ?? 0 }))
    .filter((s) => s.value > 0)
    .sort((a, b) => b.value - a.value);

  // "Outros" do SQL entra na mesma sacola do "Outros" da tela: uma fatia só.
  const nomeados = ordenado.filter((s) => s.label !== "Outros");
  const visiveis = nomeados.slice(0, MAX_SLICES);
  const resto = [...nomeados.slice(MAX_SLICES), ...ordenado.filter((s) => s.label === "Outros")];
  const somaResto = resto.reduce((a, s) => a + s.value, 0);

  return {
    fatias: somaResto > 0 ? [...visiveis, { label: "Outros", value: somaResto }] : visiveis,
    agrupadas: resto.length,
  };
}

export default function DonutPanel({ donut }: { donut: Donut }) {
  const [metric, setMetric] = useState(donut.metrics[0].key);
  const [foco, setFoco] = useState<number | null>(null);
  const [tabela, setTabela] = useState(false);

  const spec = donut.metrics.find((m) => m.key === metric) ?? donut.metrics[0];
  const formato = spec.format as Format;
  const { fatias, agrupadas } = useMemo(() => recortar(donut.slices, metric), [donut, metric]);
  const total = fatias.reduce((a, s) => a + s.value, 0);
  const cor = (i: number) => (fatias[i]?.label === "Outros" ? REST : SERIES[i % SERIES.length]);

  if (!fatias.length)
    return (
      <section className="panel viz">
        <div className="head"><strong>{donut.label}</strong></div>
        <div className="body"><p className="muted">Sem {spec.label.toLowerCase()} no período.</p></div>
      </section>
    );

  const data = {
    labels: fatias.map((s) => s.label),
    datasets: [{
      data: fatias.map((s) => s.value),
      backgroundColor: fatias.map((_, i) =>
        foco === null || foco === i ? cor(i) : cor(i) + "33"),
      // Vão de 2px na cor da superfície: separa fatia vizinha sem desenhar borda.
      borderColor: SURFACE,
      borderWidth: 2,
      hoverBorderColor: SURFACE,
      offset: fatias.map((_, i) => (foco === i ? 8 : 0)),
    }],
  };

  const options: ChartOptions<"doughnut"> = {
    responsive: true,
    maintainAspectRatio: false,
    cutout: "62%",
    animation: { duration: 380 },
    onClick: (_e, els) => setFoco((f) => (els.length ? (f === els[0].index ? null : els[0].index) : null)),
    plugins: {
      legend: { display: false },        // a legenda é a lista ao lado, com valor
      tooltip: {
        backgroundColor: "#0e141f",
        borderColor: "#31404f",
        borderWidth: 1,
        titleFont: { family: "Arial, Helvetica, sans-serif" },
        bodyFont: { family: "Arial, Helvetica, sans-serif" },
        padding: 10,
        displayColors: false,
        callbacks: {
          title: (items) => String(items[0].label),
          label: (item) => {
            const v = Number(item.parsed);
            const pct = total ? (v / total) * 100 : 0;
            return [`${spec.label}: ${exact(v, formato)}`,
                    `Participação: ${pct.toFixed(1).replace(".", ",")}%`];
          },
        },
      },
    },
  };

  return (
    <section className="panel viz">
      <div className="head">
        <strong>{donut.label}</strong>
        {donut.metrics.length > 1 && (
          <div className="seg" role="group" aria-label={`Métrica de ${donut.label}`}>
            {donut.metrics.map((m) => (
              <button key={m.key} className={"seg-btn" + (m.key === metric ? " on" : "")}
                onClick={() => { setMetric(m.key); setFoco(null); }}>
                {m.label}
              </button>
            ))}
          </div>
        )}
      </div>

      <div className="body donut-body">
        <div className="donut-plot">
          <Doughnut data={data} options={options} />
          <div className="donut-core">
            <span className="donut-core-v">{compact(total, formato)}</span>
            <span className="donut-core-l">{spec.label} total</span>
          </div>
        </div>

        <ul className="legenda">
          {fatias.map((s, i) => {
            const pct = total ? (s.value / total) * 100 : 0;
            const on = foco === null || foco === i;
            return (
              <li key={s.label}>
                <button className={"legenda-item" + (foco === i ? " on" : "")}
                  onClick={() => setFoco((f) => (f === i ? null : i))}
                  aria-pressed={foco === i}>
                  <span className="cdot" style={{ background: cor(i), opacity: on ? 1 : 0.3 }} />
                  <span className="legenda-nome">{s.label}</span>
                  <span className="legenda-v">{compact(s.value, formato)}</span>
                  <span className="legenda-pct">{pct.toFixed(1).replace(".", ",")}%</span>
                </button>
              </li>
            );
          })}
        </ul>
      </div>

      <div className="viz-foot">
        <span className="muted">
          {donut.description}
          {agrupadas > 1 && ` ${agrupadas} itens menores estão somados em “Outros”.`}
        </span>
        <button className="link-btn" onClick={() => setTabela((t) => !t)}>
          {tabela ? "Ocultar tabela" : "Ver tabela"}
        </button>
      </div>

      {tabela && (
        <div className="body" style={{ paddingTop: 0 }}>
          <div className="result-wrap">
            <table className="grid-tbl">
              <thead>
                <tr>
                  <th>{donut.label.replace("Receita por ", "").replace("Aquisição por ", "")}</th>
                  {donut.metrics.map((m) => <th key={m.key} className="num-h">{m.label}</th>)}
                </tr>
              </thead>
              <tbody>
                {[...donut.slices]
                  .sort((a, b) => (b.values[metric] ?? 0) - (a.values[metric] ?? 0))
                  .map((s) => (
                    <tr key={s.label}>
                      <td>{s.label}</td>
                      {donut.metrics.map((m) => (
                        <td key={m.key} className="num">
                          {exact(s.values[m.key] ?? 0, m.format as Format)}
                        </td>
                      ))}
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </section>
  );
}
