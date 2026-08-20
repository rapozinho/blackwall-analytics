import { Link } from "react-router-dom";

/** Volta um nível na hierarquia — não `history.back()`.
 *
 * O histórico do navegador guarda por onde a pessoa passou, que nem sempre é
 * onde ela está: quem chega numa consulta por link direto, ou depois de trocar
 * de aba, voltaria para fora do site. O destino aqui é sempre o nível acima.
 */
export default function Voltar({ para, rotulo }: { para: string; rotulo: string }) {
  return (
    <Link to={para} className="voltar">
      <span className="voltar-seta" aria-hidden="true">←</span>
      {rotulo}
    </Link>
  );
}
