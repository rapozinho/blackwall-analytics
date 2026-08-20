import { LANGS, useI18n, type Lang } from "../lib/i18n";

/** Seletor de idioma: três bandeiras no canto direito do header.
 *
 * SVG e não emoji: no Windows não existe glifo de bandeira em nenhuma fonte do
 * sistema — 🇧🇷 aparece como as duas letras "BR". Os desenhos são simplificados
 * de propósito (16px de altura não carrega brasão nem 50 estrelas), mas cada um
 * mantém o que identifica a bandeira à distância: o losango e o círculo, as três
 * faixas, o cantão com listras.
 */
const BANDEIRAS: Record<Lang, JSX.Element> = {
  pt: (
    <>
      <rect width="24" height="16" fill="#009c3b" />
      <path d="M12 1.6 22.4 8 12 14.4 1.6 8Z" fill="#ffdf00" />
      <circle cx="12" cy="8" r="3.4" fill="#002776" />
      <path d="M8.9 6.9a9 9 0 0 1 6.2 2.4" stroke="#fff" strokeWidth=".9" fill="none" />
    </>
  ),
  es: (
    <>
      <rect width="24" height="16" fill="#aa151b" />
      <rect y="4" width="24" height="8" fill="#f1bf00" />
      <rect x="4" y="6" width="2.6" height="4" fill="#aa151b" opacity=".85" />
    </>
  ),
  en: (
    <>
      <rect width="24" height="16" fill="#fff" />
      {[0, 2, 4, 6].map((i) => (
        <rect key={i} y={i * 2.46} width="24" height="1.23" fill="#b31942" />
      ))}
      {[1, 3, 5].map((i) => (
        <rect key={i} y={i * 2.46} width="24" height="1.23" fill="#b31942" />
      ))}
      <rect width="10" height="8.6" fill="#0a3161" />
      {[1.4, 4.3, 7.2].map((x) =>
        [1.6, 4.3, 7].map((y) => (
          <circle key={`${x}-${y}`} cx={x + 1.2} cy={y} r=".55" fill="#fff" />
        )),
      )}
    </>
  ),
};

export default function LangSwitch() {
  const { lang, setLang } = useI18n();

  return (
    <div className="langs" role="group" aria-label="Idioma / Idioma / Language">
      {LANGS.map((l) => (
        <button
          key={l.code}
          type="button"
          className={"lang" + (l.code === lang ? " on" : "")}
          // `aria-pressed` e não `disabled`: o botão do idioma ativo continua
          // focável, e um leitor de tela precisa saber qual está ligado.
          aria-pressed={l.code === lang}
          aria-label={l.aria}
          title={l.nome}
          onClick={() => setLang(l.code)}
        >
          <svg viewBox="0 0 24 16" width="24" height="16" aria-hidden="true">
            {BANDEIRAS[l.code]}
          </svg>
        </button>
      ))}
    </div>
  );
}
