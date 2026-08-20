import { useState } from "react";
import type { TableData } from "../lib/api";
import { download, fileName, toCSV } from "../lib/csv";

interface Props {
  data: { base: string; periodo: string; empty: boolean; tables: TableData[] };
  /** Label do relatório (ex. "Monitoring"): entra no nome do CSV. */
  reportLabel?: string;
}

const nf = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 2 });
// Percentual sempre com 2 casas: coluna de variação fica alinhada na tabela.
const pf = new Intl.NumberFormat("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

function fmt(v: string | number | null, isPercent = false) {
  if (v === null || v === undefined || v === "") return "–";
  if (typeof v !== "number") return String(v);
  return isPercent ? `${pf.format(v)}%` : nf.format(v);
}

export default function TableReportView({ data, reportLabel }: Props) {
  const [active, setActive] = useState(0);

  if (data.empty)
    return <p className="muted">Sem dados para o período selecionado.</p>;

  const t = data.tables[active] ?? data.tables[0];
  const pct = new Set(t.percent_columns ?? []);
  const csvName = fileName(data.base, reportLabel ?? t.name, data.periodo);

  return (
    <div>
      <p className="sub">{data.base} · {data.periodo}</p>

      {data.tables.length > 1 && (
        <div className="tabs">
          {data.tables.map((tb, i) => (
            <button
              key={tb.file}
              className={"tab" + (i === active ? " active" : "")}
              onClick={() => setActive(i)}
            >
              {tb.name}{tb.rows.length === 0 ? " (vazio)" : ""}
            </button>
          ))}
        </div>
      )}

      <div className="panel">
        <div className="head">
          <span>{t.name} <span className="muted">· {t.rows.length} linhas</span></span>
          <button className="btn ghost" disabled={!t.rows.length}
            onClick={() => download(toCSV(t.columns, t.rows), csvName)}
            title={csvName}>
            Baixar CSV
          </button>
        </div>
        <div className="body">
          {t.rows.length === 0 ? (
            <p className="muted">Esta query não retornou linhas para o período.</p>
          ) : (
            <div className="result-wrap">
              <table className="grid-tbl">
                <thead>
                  <tr>{t.columns.map((c, i) => <th key={i}>{c || " "}</th>)}</tr>
                </thead>
                <tbody>
                  {t.rows.map((row, ri) => (
                    <tr key={ri}>
                      {row.map((v, ci) => (
                        <td key={ci} className={typeof v === "number" ? "num" : undefined}>
                          {fmt(v, pct.has(t.columns[ci]))}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      <p className="sub" style={{ marginTop: 12 }}>
        Origem: {t.sources.map((s, i) => (
          <span key={s}>{i > 0 && ", "}<code>{s}</code></span>
        ))} — mesmo SQL do kpi-bot.
        {pct.size > 0 && " Percentuais são exibidos com % e exportados como número no CSV."}
      </p>
    </div>
  );
}
