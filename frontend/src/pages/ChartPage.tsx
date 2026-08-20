import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { api, fmtDuration, type ChartMeta } from "../lib/api";
import { useJobs } from "../lib/jobs";
import { DEMO, snapshotsDe } from "../lib/demo";
import DynamicFilter from "../components/DynamicFilter";
import OverviewDashboard from "../components/OverviewDashboard";
import RetentionCohortView from "../components/RetentionCohortView";
import TableReportView from "../components/TableReportView";
import Voltar from "../components/Voltar";

export default function ChartPage() {
  const { base, chartId } = useParams();
  const [meta, setMeta] = useState<ChartMeta | null>(null);
  const [err, setErr] = useState("");
  // Demo: os filtros possiveis sao os snapshots em disco, nao um calendario.
  const [snaps, setSnaps] = useState<{ label: string; params: Record<string, string> }[]>([]);
  const { consultas, iniciar, encerrar } = useJobs();

  // A consulta vive no provider: voltar para cá encontra o que ficou rodando —
  // ou o resultado que chegou enquanto o usuário estava em outra tela.
  const consulta = consultas.find((c) => c.chartId === chartId && c.base === base);
  const rodando = consulta?.status === "queued" || consulta?.status === "running";
  const data = consulta?.status === "done" ? consulta.result : null;
  const erro = err || (consulta?.status === "error" ? consulta.error : "");

  useEffect(() => {
    if (!DEMO || !base || !chartId) return;
    snapshotsDe(chartId, base).then(setSnaps).catch(() => setSnaps([]));
  }, [base, chartId]);

  useEffect(() => {
    if (base && chartId)
      api.charts(base)
        .then((cs) => setMeta(cs.find((c) => c.id === chartId) ?? null))
        .catch((e) => setErr(e.message));
  }, [base, chartId]);

  async function aplicar(values: Record<string, string>) {
    if (!base || !chartId) return;
    setErr("");
    try {
      await iniciar(chartId, base, meta?.label ?? chartId, values);
    } catch (e: any) {
      setErr(e.message);
    }
  }

  return (
    <div>
      <Voltar para={`/${base}`} rotulo={`Consultas de ${base}`} />
      <div className="crumb">
        <Link to="/">Bases</Link> / <Link to={`/${base}`}>{base}</Link> / {meta?.label ?? chartId}
      </div>
      <h1>{meta?.label ?? chartId}</h1>
      <p className="sub">{meta?.description}</p>

      <div className="panel" style={{ marginBottom: 20 }}>
        <div className="body">
          {meta ? (
            <DynamicFilter
              // `key`: trocar o snapshot padrao remonta o form com os valores novos.
              key={snaps[0]?.label ?? "filtro"}
              params={meta.params}
              onApply={aplicar}
              loading={rodando}
              iniciais={DEMO ? snaps[0]?.params : undefined}
              atalhos={DEMO && snaps.length ? snaps : undefined}
            />
          ) : <span className="muted">Carregando filtro…</span>}
        </div>
      </div>

      {rodando && consulta && (
        <div className="panel" style={{ marginBottom: 20 }}>
          <div className="body">
            <div className="progress"><div className="bar" style={{ width: `${consulta.progress}%` }} /></div>
            <p className="sub" style={{ margin: "10px 0 0" }}>
              {consulta.step ? `Executando: ${consulta.step}` : "Consultando o banco…"}
              {consulta.elapsed !== null && ` · ${fmtDuration(consulta.elapsed)} até agora`} — pode
              sair desta tela: a consulta continua e aparece na inicial.
            </p>
            <button className="btn ghost" style={{ marginTop: 14 }}
              onClick={() => encerrar(consulta.id)}>
              Encerrar consulta
            </button>
          </div>
        </div>
      )}

      {consulta?.status === "cancelled" && (
        <p className="sub">Consulta encerrada. Ajuste o filtro e consulte de novo.</p>
      )}

      {erro && (
        <p className="err">
          Erro: {erro}
          {consulta?.elapsed != null && ` (falhou após ${fmtDuration(consulta.elapsed)})`}
        </p>
      )}

      {data && meta?.kind === "tables" && (
        <TableReportView data={data} reportLabel={meta.label} />
      )}
      {data && meta?.kind === "dashboard" && <OverviewDashboard data={data} />}
      {data && meta?.kind === "chart" && chartId === "retention_cohort" && (
        <RetentionCohortView data={data} />
      )}
      {data && meta?.kind === "chart" && chartId !== "retention_cohort" && (
        <pre className="muted">{JSON.stringify(data, null, 2)}</pre>
      )}

      {data && consulta?.elapsed != null && (
        <p className="sub" style={{ marginTop: 12 }}>
          Consulta concluída em {fmtDuration(consulta.elapsed)}.
        </p>
      )}
    </div>
  );
}
