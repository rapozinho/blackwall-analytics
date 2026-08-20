import { useEffect, useState } from "react";
import { assinarAviso, manifesto, type Aviso, type Manifesto } from "../lib/demo";
import { useI18n } from "../lib/i18n";

/** Barra do modo demonstração.
 *
 * Existe para o visitante não confundir as duas coisas: os números são reais
 * (saíram do SQL Server), a consulta não — o que está no ar é um snapshot. A
 * segunda linha aparece só quando o filtro escolhido não existe em disco.
 */
export default function DemoBanner() {
  const [m, setM] = useState<Manifesto | null>(null);
  const [aviso, setAviso] = useState<Aviso | null>(null);
  const { t, lang } = useI18n();

  // `lang` na dependência: trocar de idioma troca a pasta de fixtures, e o
  // manifesto do idioma novo tem a sua própria data de captura.
  useEffect(() => { manifesto().then(setM).catch(() => { /* barra fica curta */ }); }, [lang]);
  useEffect(() => assinarAviso(setAviso), []);

  const repo = import.meta.env.VITE_REPO_URL as string | undefined;
  const captura = m?.gerado_em?.slice(0, 10).split("-").reverse().join("/");
  // A vertical muda rótulo E ordem de grandeza do dado: vale dizer qual está no ar.
  const vertical = m?.vertical === "ecommerce" ? t("demo_vertical_ecom")
                 : m?.vertical === "bet" ? t("demo_vertical_bet") : null;

  return (
    <div className="demo-bar">
      <span className="demo-tag">{t("demo_tag")}</span>
      <span className="demo-txt">
        {t("demo_txt", {
          v: vertical ? t("demo_vertical", { v: vertical }) : "",
          c: captura ? t("demo_captura", { d: captura }) : "",
        })}{" "}
        <code>docker compose up</code>.
        {repo && <> <a href={repo} target="_blank" rel="noreferrer">{t("demo_codigo")}</a></>}
      </span>
      {aviso?.tipo === "aproximado" && (
        <span className="demo-alerta">{t("demo_fora", { p: aviso.periodo })}</span>
      )}
    </div>
  );
}
