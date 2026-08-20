/** Exportação de CSV — mesma regra em toda tela que oferece download.
 *
 * O separador segue o idioma, porque quem abre o arquivo é o Excel local: em
 * pt/es, `;` com vírgula decimal (o que o Excel dessas regiões abre sem passar
 * pelo assistente de importação); em en, `,` com ponto decimal.
 */
import { langAtual } from "./i18n";

export type Cell = string | number | null;

/** `,` decimal e `;` separador fora do inglês. */
const virgulaDecimal = () => langAtual() !== "en";

function cell(v: Cell, sep: string): string {
  if (v === null || v === undefined) return "";
  const s = typeof v === "number" && virgulaDecimal()
    ? String(v).replace(".", ",")
    : String(v);
  // Escapa quando o texto contém o próprio separador, aspas ou quebra de linha.
  const perigo = new RegExp(`[${sep}"\n]`);
  return perigo.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export function toCSV(columns: Cell[], rows: Cell[][]): string {
  const sep = virgulaDecimal() ? ";" : ",";
  return [columns.map((c) => cell(c, sep)).join(sep),
          ...rows.map((r) => r.map((v) => cell(v, sep)).join(sep))].join("\r\n");
}

/** Windows/macOS barram `< > : " / \ | ? *`; o período vem como "01/06/2026 – 30/06/2026". */
function safe(part: string): string {
  return part
    .replace(/\//g, "-")
    .replace(/\s*[–—]\s*/g, " a ")        // en/em dash do backend vira "a"
    .replace(/[<>:"\\|?*]/g, "-")
    .replace(/\s+/g, " ")
    .trim();
}

/** "BASE - NOME DA CONSULTA - DATA.csv" */
export function fileName(...parts: (string | undefined)[]): string {
  return parts.filter(Boolean).map((p) => safe(p as string)).join(" - ") + ".csv";
}

export function download(csv: string, name: string): void {
  // BOM: sem ele o Excel lê UTF-8 como ANSI e quebra acento.
  const blob = new Blob(["\ufeff" + csv], { type: "text/csv;charset=utf-8" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = name;
  a.click();
  URL.revokeObjectURL(a.href);
}
