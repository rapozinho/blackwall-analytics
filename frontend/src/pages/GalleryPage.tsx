import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { api, fmtDuration, type BaseHealth, type ChartMeta } from "../lib/api";
import { useBaseLabel } from "../lib/bases";
import { useI18n } from "../lib/i18n";
import { useJobs } from "../lib/jobs";
import ConsultasAtivas from "../components/ConsultasAtivas";
import Voltar from "../components/Voltar";

/** Painéis e extrações respondem a perguntas diferentes e por isso não moram na
 *  mesma lista: painel é para olhar na tela, extração é para virar arquivo. */
function ehPainel(c: ChartMeta) {
  return c.kind === "dashboard" || c.kind === "chart";
}

/** Resume o filtro sem abrir a página: "dois períodos" muda o que você prepara. */
function periodos(c: ChartMeta) {
  return "date_start2" in c.params ? "dois_periodos" : "um_periodo";
}

// `tag`/`nota` sao chaves do catalogo, resolvidas no idioma da tela.
const CONEXAO: Record<BaseHealth["status"], { tag: string; cls: string; nota?: string }> = {
  ok:             { tag: "st_ok", cls: "ok" },
  missing_tables: { tag: "st_missing", cls: "warn", nota: "nota_missing" },
  not_configured: { tag: "st_notcfg", cls: "off", nota: "nota_notcfg" },
  error:          { tag: "st_error", cls: "err", nota: "nota_error" },
  unknown:        { tag: "st_unknown", cls: "idle" },
};

/** Cartão de painel: o custo vem antes do clique, não depois da espera. */
function CartaoPainel({ base, chart }: { base: string; chart: ChartMeta }) {
  const { duracao } = useJobs();
  const { t } = useI18n();
  const ultima = duracao(chart.id, base);

  return (
    <Link to={`/${base}/${chart.id}`} className="consulta">
      <span className="consulta-tipo">{t("painel")}</span>
      <h3 className="consulta-nome">{chart.label}</h3>
      <p className="consulta-desc">{chart.description}</p>
      <span className="consulta-pe">
        <span className="consulta-tags">
          <span className="tag">{t(periodos(chart))}</span>
          {"metrics" in chart.params && <span className="tag">{t("tag_metricas")}</span>}
          {"variant" in chart.params && <span className="tag">{t("tag_visoes")}</span>}
        </span>
        <span className="consulta-custo">
          {ultima ? t("ultima_exec", { d: fmtDuration(ultima) }) : t("nao_executado")}
        </span>
      </span>
    </Link>
  );
}

function LinhaExtracao({ base, chart }: { base: string; chart: ChartMeta }) {
  const { duracao } = useJobs();
  const { t } = useI18n();
  const ultima = duracao(chart.id, base);

  return (
    <li>
      <Link to={`/${base}/${chart.id}`} className="extracao">
        <span className="extracao-nome">{chart.label}</span>
        <span className="extracao-desc">{chart.description}</span>
        <span className="extracao-tag">{t(periodos(chart))}</span>
        <span className="extracao-tempo">{ultima ? fmtDuration(ultima) : "—"}</span>
        <span className="extracao-csv" aria-hidden="true">CSV</span>
      </Link>
    </li>
  );
}

export default function GalleryPage() {
  const { base } = useParams();
  const [charts, setCharts] = useState<ChartMeta[]>([]);
  const [saude, setSaude] = useState<BaseHealth | null>(null);
  const [err, setErr] = useState("");
  // A rota carrega a chave; a tela mostra o nome da operação.
  const nome = useBaseLabel(base);
  const { t, lang } = useI18n();

  useEffect(() => {
    if (!base) return;
    setCharts([]);
    setSaude(null);
    api.charts(base).then(setCharts).catch((e) => setErr(e.message));
    // Health testa as 4 bases em sequência: chega depois da lista e preenche o
    // LED sem segurar a tela.
    api.health()
      .then((h) => setSaude(h.bases.find((b) => b.key === base) ?? null))
      .catch(() => { /* sem health a navegação continua liberada */ });
    // Rotulo e descricao de cada relatorio vem da API: idioma novo, catalogo novo.
  }, [base, lang]);

  const paineis = charts.filter(ehPainel);
  const extracoes = charts.filter((c) => !ehPainel(c));
  const conexao = CONEXAO[saude?.status ?? "unknown"];

  return (
    <div>
      <Voltar para="/" rotulo={t("todas_as_bases")} />
      <div className="crumb"><Link to="/">{t("bases")}</Link> / {nome}</div>

      <header className="base-hero">
        <div className="base-id">
          <span className={`base-led ${conexao.cls}`} aria-hidden="true" />
          <h1 className="base-nome">{nome}</h1>
          <span className="base-conexao" title={saude?.detail ?? undefined}>
            {t(conexao.tag)}
          </span>
        </div>

        <dl className="base-tel">
          <div><dt>{t("banco")}</dt><dd>{saude?.database ?? "—"}</dd></div>
          <div><dt>{t("paineis")}</dt><dd>{charts.length ? paineis.length : "—"}</dd></div>
          <div><dt>{t("extracoes")}</dt><dd>{charts.length ? extracoes.length : "—"}</dd></div>
          <div><dt>{t("modo")}</dt><dd>{t("somente_leitura")}</dd></div>
        </dl>
      </header>

      {conexao.nota && (
        <p className="aviso">
          <span aria-hidden="true">!</span>
          {t(conexao.nota!)}
          {saude?.missing_tables?.length
            ? ` ${t("faltando", { t: saude.missing_tables.join(", ") })}.`
            : ""}
        </p>
      )}

      {err && <p className="err">{t("erro")}: {err}</p>}
      {!err && !charts.length && <p className="muted">{t("carregando_catalogo")}</p>}

      {base && <ConsultasAtivas base={base} />}

      {paineis.length > 0 && (
        <section className="secao">
          <h2 className="secao-t">
            {t("paineis")}<span className="secao-n">{paineis.length}</span>
          </h2>
          <p className="secao-d">{t("paineis_desc")}</p>
          <div className="consultas-grid">
            {paineis.map((c) => <CartaoPainel key={c.id} base={base!} chart={c} />)}
          </div>
        </section>
      )}

      {extracoes.length > 0 && (
        <section className="secao">
          <h2 className="secao-t">
            {t("extracoes")}<span className="secao-n">{extracoes.length}</span>
          </h2>
          <p className="secao-d">{t("extracoes_desc")}</p>
          <ul className="extracoes">
            {extracoes.map((c) => <LinhaExtracao key={c.id} base={base!} chart={c} />)}
          </ul>
        </section>
      )}
    </div>
  );
}
