/** Exportação de CSV — mesma regra em toda tela que oferece download.
 *
 * `;` como separador e vírgula decimal: é o que o Excel pt-BR abre sem passar
 * pelo assistente de importação.
 */
export type Cell = string | number | null;

function cell(v: Cell): string {
  if (v === null || v === undefined) return "";
  const s = typeof v === "number" ? String(v).replace(".", ",") : String(v);
  return /[;"\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export function toCSV(columns: Cell[], rows: Cell[][]): string {
  return [columns.map(cell).join(";"), ...rows.map((r) => r.map(cell).join(";"))].join("\r\n");
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
