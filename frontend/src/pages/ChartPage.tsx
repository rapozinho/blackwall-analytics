import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { api, fmtDuration, type ChartMeta } from "../lib/api";
import { useJobs } from "../lib/jobs";
import { DEMO, snapshotsDe } from "../lib/demo";
import { useBaseLabel } from "../lib/bases";
import { useI18n } from "../lib/i18n";
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
  const nome = useBaseLabel(base);
  const { t, lang } = useI18n();

  // A consulta vive no provider: voltar para cá encontra o que ficou rodando —
  // ou o resultado que chegou enquanto o usuário estava em outra tela.
  const consulta = consultas.find((c) => c.chartId === chartId && c.base === base);
  const rodando = consulta?.status === "queued" || consulta?.status === "running";
  const data = consulta?.status === "done" ? consulta.result : null;
  const erro = err || (consulta?.status === "error" ? consulta.error : "");

  useEffect(() => {
    if (!DEMO || !base || !chartId) return;
    snapshotsDe(chartId, base).then(setSnaps).catch(() => setSnaps([]));
  }, [base, chartId, lang]);

  useEffect(() => {
    if (base && chartId)
      api.charts(base)
        .then((cs) => setMeta(cs.find((c) => c.id === chartId) ?? null))
        .catch((e) => setErr(e.message));
    // O `label` do filtro e a descricao vem traduzidos da API.
  }, [base, chartId, lang]);

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
      <Voltar para={`/${base}`} rotulo={t("consultas_de", { b: nome })} />
      <div className="crumb">
        <Link to="/">{t("bases")}</Link> / <Link to={`/${base}`}>{nome}</Link> / {meta?.label ?? chartId}
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
          ) : <span className="muted">{t("carregando_filtro")}</span>}
        </div>
      </div>

      {rodando && consulta && (
        <div className="panel" style={{ marginBottom: 20 }}>
          <div className="body">
            <div className="progress"><div className="bar" style={{ width: `${consulta.progress}%` }} /></div>
            <p className="sub" style={{ margin: "10px 0 0" }}>
              {consulta.step
                ? t("executando", { p: consulta.step })
                : t("consultando_banco")}
              {consulta.elapsed !== null
                && ` · ${t("ate_agora", { d: fmtDuration(consulta.elapsed) })}`}
              {" — "}{t("pode_sair")}
            </p>
            <button className="btn ghost" style={{ marginTop: 14 }}
              onClick={() => encerrar(consulta.id)}>
              {t("encerrar_consulta")}
            </button>
          </div>
        </div>
      )}

      {consulta?.status === "cancelled" && (
        <p className="sub">{t("consulta_encerrada")}</p>
      )}

      {erro && (
        <p className="err">
          {t("erro")}: {erro}
          {consulta?.elapsed != null
            && ` ${t("falhou_apos", { d: fmtDuration(consulta.elapsed) })}`}
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
          {t("concluida_em", { d: fmtDuration(consulta.elapsed) })}
        </p>
      )}
    </div>
  );
}
