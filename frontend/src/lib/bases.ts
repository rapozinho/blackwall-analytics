import { useEffect, useState } from "react";
import { api, type Base } from "./api";

/** Nome de exibição de uma base, resolvido pela chave da URL.
 *
 * A base tem duas identidades e elas não se misturam: a **chave** (`Zephyr`)
 * nomeia a pasta do catálogo de SQL, o database e a rota; o **rótulo**
 * (`Nordika`) é o nome da operação, e muda com a vertical. A tela mostra só o
 * rótulo — ver os dois lado a lado era ler dois nomes para a mesma coisa.
 *
 * A lista vem de `/api/bases` uma vez por sessão: são 4 itens e todas as telas
 * pedem a mesma coisa.
 */
let cache: Promise<Base[]> | null = null;

function todas(): Promise<Base[]> {
  if (!cache) cache = api.bases().catch((e) => { cache = null; throw e; });
  return cache;
}

/** Rótulo da base; cai na própria chave enquanto a lista não chegou. */
export function useBaseLabel(key: string | undefined): string {
  const [label, setLabel] = useState<string>(key ?? "");

  useEffect(() => {
    if (!key) return;
    let vivo = true;
    setLabel(key);
    todas()
      .then((bases) => {
        const achada = bases.find((b) => b.key === key);
        if (vivo && achada) setLabel(achada.label);
      })
      .catch(() => { /* sem a lista, a chave serve de nome */ });
    return () => { vivo = false; };
  }, [key]);

  return label;
}
