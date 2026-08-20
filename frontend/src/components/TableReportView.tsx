import { useState } from "react";
import type { TableData } from "../lib/api";
import { download, fileName, toCSV } from "../lib/csv";
import { locale, useI18n } from "../lib/i18n";

interface Props {
  data: { base: string; periodo: string; empty: boolean; tables: TableData[] };
  /** Label do relatório (ex. "Monitoring"): entra no nome do CSV. */
  reportLabel?: string;
}

// Formatadores por idioma, montados na hora: a tabela e' a tela com mais numeros
// e refazer o Intl.NumberFormat por celula custaria caro.
function fmt(v: string | number | null, isPercent = false) {
  if (v === null || v === undefined || v === "") return "–";
  if (typeof v !== "number") return String(v);
  const loc = locale();
  return isPercent
    ? `${v.toLocaleString(loc, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}%`
    : v.toLocaleString(loc, { maximumFractionDigits: 2 });
}

export default function TableReportView({ data, reportLabel }: Props) {
  const [active, setActive] = useState(0);
  const { t } = useI18n();

  if (data.empty)
    return <p className="muted">{t("tab_sem_dados")}</p>;

  const tabela = data.tables[active] ?? data.tables[0];
  const pct = new Set(tabela.percent_columns ?? []);
  const csvName = fileName(data.base, reportLabel ?? tabela.name, data.periodo);

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
              {tb.name}{tb.rows.length === 0 ? ` (${t("vazio")})` : ""}
            </button>
          ))}
        </div>
      )}

      <div className="panel">
        <div className="head">
          <span>{tabela.name}{" "}
            <span className="muted">· {tabela.rows.length} {t("linhas")}</span>
          </span>
          <button className="btn ghost" disabled={!tabela.rows.length}
            onClick={() => download(toCSV(tabela.columns, tabela.rows), csvName)}
            title={csvName}>
            {t("baixar_csv")}
          </button>
        </div>
        <div className="body">
          {tabela.rows.length === 0 ? (
            <p className="muted">{t("tab_sem_linhas")}</p>
          ) : (
            <div className="result-wrap">
              <table className="grid-tbl">
                <thead>
                  <tr>{tabela.columns.map((c, i) => <th key={i}>{c || " "}</th>)}</tr>
                </thead>
                <tbody>
                  {tabela.rows.map((row, ri) => (
                    <tr key={ri}>
                      {row.map((v, ci) => (
                        <td key={ci} className={typeof v === "number" ? "num" : undefined}>
                          {fmt(v, pct.has(tabela.columns[ci]))}
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
        {t("tab_origem")} {tabela.sources.map((s, i) => (
          <span key={s}>{i > 0 && ", "}<code>{s}</code></span>
        ))} {t("tab_mesmo_sql")}
        {pct.size > 0 && ` ${t("tab_percent_nota")}`}
      </p>
    </div>
  );
}
