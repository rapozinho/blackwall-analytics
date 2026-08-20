import { useState } from "react";
import type { ParamSpec } from "../lib/api";
import { useI18n } from "../lib/i18n";

const iso = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

function diasAtras(n: number) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d;
}

/** Atalhos de período. Digitar duas datas para toda consulta é o atrito que mais
 *  aparece no uso diário; a janela padrão são os últimos 30 dias. */
const ATALHOS: { label: string; range: () => [Date, Date] }[] = [
  { label: "atalho_7", range: () => [diasAtras(7), diasAtras(1)] },
  { label: "atalho_30", range: () => [diasAtras(30), diasAtras(1)] },
  { label: "atalho_90", range: () => [diasAtras(90), diasAtras(1)] },
  {
    label: "atalho_mes",
    range: () => { const h = new Date(); return [new Date(h.getFullYear(), h.getMonth(), 1), h]; },
  },
  {
    label: "atalho_mes_passado",
    range: () => {
      const h = new Date();
      return [new Date(h.getFullYear(), h.getMonth() - 1, 1), new Date(h.getFullYear(), h.getMonth(), 0)];
    },
  },
];

/** Janela anterior de mesma duração, colada no início da atual. */
function janelaAnterior(ini: Date, fim: Date): [Date, Date] {
  const dias = Math.round((fim.getTime() - ini.getTime()) / 86_400_000) + 1;
  const fim2 = new Date(ini);
  fim2.setDate(fim2.getDate() - 1);
  const ini2 = new Date(fim2);
  ini2.setDate(ini2.getDate() - (dias - 1));
  return [ini2, fim2];
}

// Monta o formulário de filtro a partir do spec `params` do gráfico.
export default function DynamicFilter({
  params, onApply, loading, iniciais, atalhos,
}: {
  params: Record<string, ParamSpec>;
  onApply: (values: Record<string, string>) => void;
  loading: boolean;
  /** Valores com que o form abre. Sem isto: 30 dias + padrão do spec. */
  iniciais?: Record<string, string>;
  /** Substitui os atalhos de calendário por conjuntos de params prontos —
   *  usado pelo modo demonstração, onde só existe o que está em disco. */
  atalhos?: { label: string; params: Record<string, string> }[];
}) {
  const { t } = useI18n();
  const temPeriodo = "date_start" in params && "date_end" in params;
  const temComparacao = "date_start2" in params && "date_end2" in params;

  const [vals, setVals] = useState<Record<string, string>>(() => {
    // Escolha única já entra com o padrão do spec: o form abre pronto para aplicar.
    const base: Record<string, string> = {};
    for (const [k, s] of Object.entries(params))
      if (s.type === "select" && typeof s.default === "string") base[k] = s.default;

    if (!temPeriodo) return base;
    const [ini, fim] = ATALHOS[1].range();          // últimos 30 dias
    base.date_start = iso(ini);
    base.date_end = iso(fim);
    if ("date_start2" in params) {
      const [ini2, fim2] = janelaAnterior(ini, fim);
      base.date_start2 = iso(ini2);
      base.date_end2 = iso(fim2);
    }
    return { ...base, ...(iniciais ?? {}) };
  });

  const [multi, setMulti] = useState<Record<string, string[]>>(() => {
    const init: Record<string, string[]> = {};
    for (const [k, s] of Object.entries(params))
      if (s.type === "multiselect") {
        const doSnapshot = iniciais?.[k];
        init[k] = doSnapshot !== undefined
          ? doSnapshot.split(",").filter(Boolean)
          : (s.default as string[]) ?? [];
      }
    return init;
  });

  /** Atalho da demo: aplica o conjunto inteiro de params daquele snapshot. */
  function aplicarSnapshot(alvo: Record<string, string>) {
    setVals((v) => ({ ...v, ...alvo }));
    setMulti((m) => {
      const out = { ...m };
      for (const [k, s] of Object.entries(params))
        if (s.type === "multiselect" && alvo[k] !== undefined)
          out[k] = alvo[k].split(",").filter(Boolean);
      return out;
    });
  }

  function aplicarAtalho(range: () => [Date, Date]) {
    const [ini, fim] = range();
    setVals((v) => {
      const out: Record<string, string> = { ...v, date_start: iso(ini), date_end: iso(fim) };
      if (temComparacao) {
        const [ini2, fim2] = janelaAnterior(ini, fim);
        out.date_start2 = iso(ini2);
        out.date_end2 = iso(fim2);
      }
      return out;
    });
  }

  function toggle(key: string, value: string) {
    setMulti((m) => {
      const cur = new Set(m[key] ?? []);
      cur.has(value) ? cur.delete(value) : cur.add(value);
      return { ...m, [key]: [...cur] };
    });
  }

  function submit() {
    const out: Record<string, string> = { ...vals };
    for (const [k, arr] of Object.entries(multi)) out[k] = arr.join(",");
    onApply(out);
  }

  const ready = Object.entries(params).every(([k, s]) => {
    if (!s.required) return true;
    if (s.type === "multiselect") return (multi[k] ?? []).length > 0;
    return !!vals[k];
  });

  return (
    <div className="filtro">
      {atalhos && atalhos.length > 0 && (
        <div className="atalhos">
          {atalhos.map((a) => (
            <button key={a.label} className="pill" onClick={() => aplicarSnapshot(a.params)}>
              {a.label}
            </button>
          ))}
          <span className="muted atalhos-nota">{t("snapshots_nota")}</span>
        </div>
      )}

      {!atalhos && temPeriodo && (
        <div className="atalhos">
          {ATALHOS.map((a) => (
            <button key={a.label} className="pill" onClick={() => aplicarAtalho(a.range)}>
              {t(a.label)}
            </button>
          ))}
          {temComparacao && (
            <span className="muted atalhos-nota">{t("atalho_nota")}</span>
          )}
        </div>
      )}

      <div className="filter">
        {Object.entries(params).map(([key, spec]) => {
          if (spec.type === "date")
            return (
              <div className="field" key={key}>
                <label htmlFor={`f-${key}`}>{spec.label}</label>
                <input id={`f-${key}`} type="date" value={vals[key] ?? ""}
                  onChange={(e) => setVals((v) => ({ ...v, [key]: e.target.value }))} />
              </div>
            );
          if (spec.type === "select")
          return (
            <div className="field" key={key}>
              <label>{spec.label}</label>
              <div className="checks">
                {spec.options?.map((o) => {
                  const on = vals[key] === o.value;
                  return (
                    <label key={o.value} className="chk" title={o.hint}>
                      <input type="radio" name={key} checked={on}
                        onChange={() => setVals((v) => ({ ...v, [key]: o.value }))} />
                      {o.label}
                    </label>
                  );
                })}
              </div>
            </div>
          );
        if (spec.type === "multiselect")
            return (
              <div className="field" key={key}>
                <label>{spec.label}</label>
                <div className="checks">
                  {spec.options?.map((o) => {
                    const on = (multi[key] ?? []).includes(o.value);
                    // <label>: o checkbox recebe foco e responde a teclado.
                    return (
                      <label key={o.value} className="chk">
                        <input type="checkbox" checked={on} onChange={() => toggle(key, o.value)} />
                        {o.label}
                      </label>
                    );
                  })}
                </div>
              </div>
            );
          return null;
        })}
        <button className="btn" disabled={!ready || loading} onClick={submit}>
          {loading ? t("consultando") : t("consultar")}
        </button>
      </div>
    </div>
  );
}
