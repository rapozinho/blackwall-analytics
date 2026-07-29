export interface Base { key: string; label: string; }
export interface ParamSpec {
  type: "date" | "multiselect";
  label: string;
  required?: boolean;
  default?: unknown;
  options?: { value: string; label: string }[];
}
export interface ChartMeta {
  id: string; label: string; description: string;
  bases: string[]; params: Record<string, ParamSpec>;
}

async function getJSON<T>(url: string): Promise<T> {
  const r = await fetch(url);
  if (!r.ok) {
    let msg = r.statusText;
    try { const j = await r.json(); msg = j.detail ?? msg; } catch { /* ignore */ }
    throw new Error(msg);
  }
  return r.json() as Promise<T>;
}

export const api = {
  bases: () => getJSON<Base[]>("/api/bases"),
  charts: (base: string) => getJSON<ChartMeta[]>(`/api/charts?base=${encodeURIComponent(base)}`),
  chartData: (id: string, base: string, params: Record<string, string>) => {
    const qs = new URLSearchParams({ base, ...params });
    return getJSON<any>(`/api/charts/${id}/data?${qs.toString()}`);
  },
};
