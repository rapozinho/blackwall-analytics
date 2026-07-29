import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { api, type ChartMeta } from "../lib/api";

// preview estático (não bate no DB): mini sparkline decorativo
function Spark() {
  return (
    <svg className="spark" width="100%" height="40" viewBox="0 0 200 40" preserveAspectRatio="none">
      <polyline fill="none" stroke="var(--accent)" strokeWidth="2"
        points="0,34 30,20 60,26 90,10 120,18 150,6 200,14" />
    </svg>
  );
}

export default function GalleryPage() {
  const { base } = useParams();
  const [charts, setCharts] = useState<ChartMeta[]>([]);
  const [err, setErr] = useState("");

  useEffect(() => {
    if (base) api.charts(base).then(setCharts).catch((e) => setErr(e.message));
  }, [base]);

  return (
    <div>
      <div className="crumb"><Link to="/">Bases</Link> / {base}</div>
      <h1>Gráficos — {base}</h1>
      <p className="sub">Clique num gráfico para escolher o período e consultar.</p>
      {err && <p className="err">Erro: {err}</p>}
      {!err && charts.length === 0 && <p className="muted">Nenhum gráfico disponível para esta base ainda.</p>}
      <div className="grid">
        {charts.map((c) => (
          <Link key={c.id} to={`/${base}/${c.id}`} className="card click">
            <h3>{c.label}</h3>
            <p>{c.description}</p>
            <Spark />
          </Link>
        ))}
      </div>
    </div>
  );
}
