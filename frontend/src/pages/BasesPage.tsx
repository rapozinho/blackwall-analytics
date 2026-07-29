import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, type Base } from "../lib/api";

export default function BasesPage() {
  const [bases, setBases] = useState<Base[]>([]);
  const [err, setErr] = useState("");

  useEffect(() => { api.bases().then(setBases).catch((e) => setErr(e.message)); }, []);

  return (
    <div>
      <h1>Selecione a base</h1>
      <p className="sub">Escolha a operação para ver os gráficos disponíveis.</p>
      {err && <p className="err">Erro: {err}</p>}
      <div className="grid">
        {bases.map((b) => (
          <Link key={b.key} to={`/${b.key}`} className="card click">
            <h3>{b.label}</h3>
            <p>Ver gráficos e métricas</p>
          </Link>
        ))}
      </div>
    </div>
  );
}
