import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { api, type ChartMeta } from "../lib/api";
import DynamicFilter from "../components/DynamicFilter";
import RetentionCohortView from "../components/RetentionCohortView";

export default function ChartPage() {
  const { base, chartId } = useParams();
  const [meta, setMeta] = useState<ChartMeta | null>(null);
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState("");

  useEffect(() => {
    if (base && chartId)
      api.charts(base)
        .then((cs) => setMeta(cs.find((c) => c.id === chartId) ?? null))
        .catch((e) => setErr(e.message));
  }, [base, chartId]);

  async function apply(values: Record<string, string>) {
    if (!base || !chartId) return;
    setLoading(true); setErr(""); setData(null);
    try { setData(await api.chartData(chartId, base, values)); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }

  return (
    <div>
      <div className="crumb">
        <Link to="/">Bases</Link> / <Link to={`/${base}`}>{base}</Link> / {meta?.label ?? chartId}
      </div>
      <h1>{meta?.label ?? chartId}</h1>
      <p className="sub">{meta?.description}</p>

      <div className="panel" style={{ marginBottom: 20 }}>
        <div className="body">
          {meta ? <DynamicFilter params={meta.params} onApply={apply} loading={loading} />
                : <span className="muted">Carregando filtro…</span>}
        </div>
      </div>

      {err && <p className="err">Erro: {err}</p>}

      {data && chartId === "retention_cohort" && <RetentionCohortView data={data} />}
      {data && chartId !== "retention_cohort" && (
        <pre className="muted">{JSON.stringify(data, null, 2)}</pre>
      )}
    </div>
  );
}
