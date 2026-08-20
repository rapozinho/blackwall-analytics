import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { api, fmtDuration, type BaseHealth, type ChartMeta } from "../lib/api";
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
  return "date_start2" in c.params ? "dois períodos" : "um período";
}

const CONEXAO: Record<BaseHealth["status"], { tag: string; cls: string; nota?: string }> = {
  ok:             { tag: "conectado", cls: "ok" },
  missing_tables: { tag: "tabelas faltando", cls: "warn",
                    nota: "Algumas consultas vão falhar: faltam tabelas ou GRANT SELECT." },
  not_configured: { tag: "sem configuração", cls: "off",
                    nota: "Falta preencher as credenciais desta base no .env do backend." },
  error:          { tag: "sem conexão", cls: "err",
                    nota: "Não foi possível conectar. As consultas vão falhar até isso ser resolvido." },
  unknown:        { tag: "verificando…", cls: "idle" },
};

/** Cartão de painel: o custo vem antes do clique, não depois da espera. */
function CartaoPainel({ base, chart }: { base: string; chart: ChartMeta }) {
  const { duracao } = useJobs();
  const ultima = duracao(chart.id, base);

  return (
    <Link to={`/${base}/${chart.id}`} className="consulta">
      <span className="consulta-tipo">Painel</span>
      <h3 className="consulta-nome">{chart.label}</h3>
      <p className="consulta-desc">{chart.description}</p>
      <span className="consulta-pe">
        <span className="consulta-tags">
          <span className="tag">{periodos(chart)}</span>
          {"metrics" in chart.params && <span className="tag">métricas</span>}
          {"variant" in chart.params && <span className="tag">visões</span>}
        </span>
        <span className="consulta-custo">
          {ultima ? `última: ${fmtDuration(ultima)}` : "ainda não executado"}
        </span>
      </span>
    </Link>
  );
}

function LinhaExtracao({ base, chart }: { base: string; chart: ChartMeta }) {
  const { duracao } = useJobs();
  const ultima = duracao(chart.id, base);

  return (
    <li>
      <Link to={`/${base}/${chart.id}`} className="extracao">
        <span className="extracao-nome">{chart.label}</span>
        <span className="extracao-desc">{chart.description}</span>
        <span className="extracao-tag">{periodos(chart)}</span>
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
  }, [base]);

  const paineis = charts.filter(ehPainel);
  const extracoes = charts.filter((c) => !ehPainel(c));
  const conexao = CONEXAO[saude?.status ?? "unknown"];

  return (
    <div>
      <Voltar para="/" rotulo="Todas as bases" />
      <div className="crumb"><Link to="/">Bases</Link> / {base}</div>

      <header className="base-hero">
        <div className="base-id">
          <span className={`base-led ${conexao.cls}`} aria-hidden="true" />
          <h1 className="base-nome">{base}</h1>
          <span className="base-conexao" title={saude?.detail ?? undefined}>{conexao.tag}</span>
        </div>

        <dl className="base-tel">
          <div><dt>Banco</dt><dd>{saude?.database ?? "—"}</dd></div>
          <div><dt>Painéis</dt><dd>{charts.length ? paineis.length : "—"}</dd></div>
          <div><dt>Extrações</dt><dd>{charts.length ? extracoes.length : "—"}</dd></div>
          <div><dt>Modo</dt><dd>somente leitura</dd></div>
        </dl>
      </header>

      {conexao.nota && (
        <p className="aviso">
          <span aria-hidden="true">!</span>
          {conexao.nota}
          {saude?.missing_tables?.length ? ` Faltando: ${saude.missing_tables.join(", ")}.` : ""}
        </p>
      )}

      {err && <p className="err">Erro: {err}</p>}
      {!err && !charts.length && <p className="muted">Carregando o catálogo desta base…</p>}

      {base && <ConsultasAtivas base={base} />}

      {paineis.length > 0 && (
        <section className="secao">
          <h2 className="secao-t">Painéis<span className="secao-n">{paineis.length}</span></h2>
          <p className="secao-d">Indicadores e gráficos interativos, para ler na tela.</p>
          <div className="consultas-grid">
            {paineis.map((c) => <CartaoPainel key={c.id} base={base!} chart={c} />)}
          </div>
        </section>
      )}

      {extracoes.length > 0 && (
        <section className="secao">
          <h2 className="secao-t">Extrações<span className="secao-n">{extracoes.length}</span></h2>
          <p className="secao-d">
            O mesmo SQL do kpi-bot, em tabela, com download em CSV.
          </p>
          <ul className="extracoes">
            {extracoes.map((c) => <LinhaExtracao key={c.id} base={base!} chart={c} />)}
          </ul>
        </section>
      )}
    </div>
  );
}
