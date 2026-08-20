import { useEffect, useState } from "react";
import { assinarAviso, manifesto, type Aviso, type Manifesto } from "../lib/demo";

/** Barra do modo demonstração.
 *
 * Existe para o visitante não confundir as duas coisas: os números são reais
 * (saíram do SQL Server), a consulta não — o que está no ar é um snapshot. A
 * segunda linha aparece só quando o filtro escolhido não existe em disco.
 */
export default function DemoBanner() {
  const [m, setM] = useState<Manifesto | null>(null);
  const [aviso, setAviso] = useState<Aviso | null>(null);

  useEffect(() => { manifesto().then(setM).catch(() => { /* barra fica curta */ }); }, []);
  useEffect(() => assinarAviso(setAviso), []);

  const repo = import.meta.env.VITE_REPO_URL as string | undefined;
  const captura = m?.gerado_em?.slice(0, 10).split("-").reverse().join("/");
  // A vertical muda rótulo E ordem de grandeza do dado: vale dizer qual está no ar.
  const vertical = m?.vertical === "ecommerce" ? "e-commerce"
                 : m?.vertical === "bet" ? "apostas" : null;

  return (
    <div className="demo-bar">
      <span className="demo-tag">demo estática</span>
      <span className="demo-txt">
        Sem backend no ar: esta página lê um snapshot dos payloads da API real
        {vertical ? ` na vertical de ${vertical}` : ""}
        {captura ? `, capturado em ${captura}` : ""}. Os números vieram do SQL Server
        — a consulta ao banco é que não roda aqui. A stack completa (FastAPI + SQL
        Server + nginx) sobe com um <code>docker compose up</code>.
        {repo && <> <a href={repo} target="_blank" rel="noreferrer">Código no GitHub →</a></>}
      </span>
      {aviso?.tipo === "aproximado" && (
        <span className="demo-alerta">
          Filtro fora do snapshot — mostrando {aviso.periodo}.
        </span>
      )}
    </div>
  );
}
