import { useState } from "react";
import type { ParamSpec } from "../lib/api";

// Monta o formulário de filtro a partir do spec `params` do gráfico.
export default function DynamicFilter({
  params, onApply, loading,
}: {
  params: Record<string, ParamSpec>;
  onApply: (values: Record<string, string>) => void;
  loading: boolean;
}) {
  const [vals, setVals] = useState<Record<string, string>>({});
  const [multi, setMulti] = useState<Record<string, string[]>>(() => {
    const init: Record<string, string[]> = {};
    for (const [k, s] of Object.entries(params))
      if (s.type === "multiselect") init[k] = (s.default as string[]) ?? [];
    return init;
  });

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
    <div className="filter">
      {Object.entries(params).map(([key, spec]) => {
        if (spec.type === "date")
          return (
            <div className="field" key={key}>
              <label>{spec.label}</label>
              <input type="date" value={vals[key] ?? ""}
                onChange={(e) => setVals((v) => ({ ...v, [key]: e.target.value }))} />
            </div>
          );
        if (spec.type === "multiselect")
          return (
            <div className="field" key={key}>
              <label>{spec.label}</label>
              <div className="checks">
                {spec.options?.map((o) => {
                  const on = (multi[key] ?? []).includes(o.value);
                  return (
                    <span key={o.value} className="chk" onClick={() => toggle(key, o.value)}>
                      <input type="checkbox" readOnly checked={on} /> {o.label}
                    </span>
                  );
                })}
              </div>
            </div>
          );
        return null;
      })}
      <button className="btn" disabled={!ready || loading} onClick={submit}>
        {loading ? "Consultando…" : "Consultar"}
      </button>
    </div>
  );
}
