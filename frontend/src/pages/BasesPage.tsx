import { useEffect, useRef, useState, type MouseEvent } from "react";
import { useNavigate } from "react-router-dom";
import { api, type AppMeta, type Base, type BaseHealth } from "../lib/api";
import Blackwall from "../components/Blackwall";
import ConsultasAtivas from "../components/ConsultasAtivas";

/** Status do backend -> rótulo do portal. O LED diz se dá para entrar, não é enfeite. */
const STATUS: Record<BaseHealth["status"], { tag: string; cls: string; help: string }> = {
  ok:              { tag: "conectado",     cls: "ok",   help: "Base respondendo e com as tabelas necessárias." },
  missing_tables:  { tag: "tabelas faltando", cls: "warn", help: "Conecta, mas faltam tabelas ou GRANT SELECT." },
  not_configured:  { tag: "sem configuração", cls: "off",  help: "Falta preencher o .env desta base." },
  error:           { tag: "sem conexão",   cls: "err",  help: "Não foi possível conectar." },
  unknown:         { tag: "verificando…",  cls: "idle", help: "Testando a conexão." },
};

const BREACH_MS = 620;

export default function BasesPage() {
  const [bases, setBases] = useState<Base[]>([]);
  const [meta, setMeta] = useState<AppMeta | null>(null);
  const [health, setHealth] = useState<Record<string, BaseHealth>>({});
  const [checking, setChecking] = useState(true);
  const [err, setErr] = useState("");
  const [focus, setFocus] = useState<number | null>(null);
  const [breaching, setBreaching] = useState<string | null>(null);
  const navigate = useNavigate();
  const timer = useRef<number | undefined>(undefined);

  useEffect(() => {
    api.bases().then(setBases).catch((e) => setErr(e.message));
    // Vertical ativa (apostas / e-commerce): rótulo do readout. Falha aqui não
    // impede navegar — some o rótulo, não a tela.
    api.meta().then(setMeta).catch(() => { /* readout fica sem a linha */ });
    // Health separado: a lista aparece na hora, o LED preenche quando chega.
    api.health()
      .then((h) => setHealth(Object.fromEntries(h.bases.map((b) => [b.key, b]))))
      .catch(() => { /* sem health a navegação continua liberada */ })
      .finally(() => setChecking(false));
    return () => clearTimeout(timer.current);
  }, []);

  /** Deixa o glitch de entrada rodar antes de trocar de rota. */
  function enter(key: string, e: MouseEvent) {
    e.preventDefault();
    if (breaching) return;
    setBreaching(key);
    const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
    timer.current = window.setTimeout(() => navigate(`/${key}`), reduce ? 0 : BREACH_MS);
  }

  const online = Object.values(health).filter((b) => b.status === "ok").length;

  return (
    <div className={"wall" + (breaching ? " is-breaching" : "")}>
      <Blackwall focus={focus} breaching={!!breaching} />
      <div className="bw-grain" aria-hidden="true" />

      <section className="wall-hero">
        <p className="eyebrow">Netwatch · perímetro analítico</p>
        <h1 className="wall-title" data-text="BLACKWALL">BLACKWALL</h1>
        <p className="wall-lede">
          Cada operação fica atrás da parede. Escolha uma para atravessar e consultar os dados.
        </p>
        <dl className="wall-readout">
          <div><dt>Portais</dt><dd>{bases.length || "—"}</dd></div>
          <div><dt>Conectados</dt><dd>{checking ? "…" : online}</dd></div>
          <div><dt>Vertical</dt><dd>{meta?.label ?? "…"}</dd></div>
          <div><dt>Modo</dt><dd>somente leitura</dd></div>
        </dl>
      </section>

      <ConsultasAtivas />

      {err && <p className="err wall-err">Não foi possível carregar as bases: {err}</p>}

      <ul className="gates" onMouseLeave={() => setFocus(null)}>
        {bases.map((b, i) => {
          const h = health[b.key];
          const st = STATUS[h?.status ?? "unknown"];
          const blocked = h && h.status !== "ok";
          return (
            <li key={b.key}>
              <a
                href={`/${b.key}`}
                className={`gate st-${st.cls}` + (breaching === b.key ? " is-open" : "")}
                // Centro do card em 0..1: alimenta o foco da parede no canvas.
                onMouseEnter={() => setFocus((i + 0.5) / Math.max(bases.length, 1))}
                onFocus={() => setFocus((i + 0.5) / Math.max(bases.length, 1))}
                onClick={(e) => enter(b.key, e)}
              >
                <span className="gate-slot" aria-hidden="true">
                  <i /><i /><i />
                </span>
                <span className="gate-key">{b.key}</span>
                <span className="gate-label">{b.label}</span>
                <span className={"gate-status " + st.cls} title={h?.detail ?? st.help}>
                  <em aria-hidden="true" />{st.tag}
                </span>
                {blocked && h?.status === "missing_tables" && h.missing_tables.length > 0 && (
                  <span className="gate-note">Faltando: {h.missing_tables.join(", ")}</span>
                )}
                <span className="gate-go">
                  {breaching === b.key ? "Abrindo…" : "Abrir gráficos"}
                </span>
              </a>
            </li>
          );
        })}
        {!bases.length && !err && <li className="gate-skel" aria-hidden="true" />}
      </ul>

      <p className="wall-foot">
        Consultas somente leitura. Bases com falha continuam navegáveis — o erro aparece na consulta.
      </p>
    </div>
  );
}
