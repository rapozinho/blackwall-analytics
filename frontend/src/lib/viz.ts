/** Paleta e formatação dos painéis.
 *
 * As 7 cores de série passaram no validador de daltonismo contra a superfície
 * real (#0a0e16): pior par adjacente ΔE 10,2 em deuteranopia, contraste ≥ 3:1.
 * Não reordene sem revalidar — a ordem É o mecanismo de segurança.
 *
 * Vermelho e âmbar ficam de fora de propósito: neste tema eles significam
 * "alerta" e "ação do usuário". Série nenhuma pode falar essa língua.
 */
export const SERIES = [
  "#0f9cb5", "#b98317", "#d1478f", "#7c6ce6", "#17a679", "#d96a26", "#3a72d8",
] as const;

/** "Outros" nunca ganha matiz: é o resto, não uma categoria. */
export const REST = "#5c6a80";
export const SURFACE = "#0a0e16";
export const POS = "#17a679";
export const NEG = "#ff2f45";

export const MAX_SLICES = 7;

export type Format = "currency" | "int" | "percent" | "ratio";

const brl = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });
const brl0 = new Intl.NumberFormat("pt-BR", {
  style: "currency", currency: "BRL", maximumFractionDigits: 0,
});
const int = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 0 });
const dec1 = new Intl.NumberFormat("pt-BR", { minimumFractionDigits: 1, maximumFractionDigits: 1 });
const dec2 = new Intl.NumberFormat("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

/** Valor curto para tile e eixo: "R$ 2,4 mi". O exato vive no tooltip. */
export function compact(v: number, format: Format = "currency"): string {
  if (format === "percent") return `${dec2.format(v * 100)}%`;
  if (format === "ratio") return dec2.format(v);

  const a = Math.abs(v);
  const sinal = v < 0 ? "-" : "";
  const moeda = format === "currency" ? "R$ " : "";
  if (a >= 1e9) return `${sinal}${moeda}${dec1.format(a / 1e9)} bi`;
  if (a >= 1e6) return `${sinal}${moeda}${dec1.format(a / 1e6)} mi`;
  if (a >= 1e4) return `${sinal}${moeda}${dec1.format(a / 1e3)} mil`;
  return format === "currency" ? brl0.format(v) : int.format(v);
}

/** Valor cheio: tooltip, tabela e leitor de tela. */
export function exact(v: number, format: Format = "currency"): string {
  if (format === "percent") return `${dec2.format(v * 100)}%`;
  if (format === "int") return int.format(v);
  if (format === "ratio") return dec2.format(v);
  return brl.format(v);
}

/** "+12,4%" / "-3,10 p.p." — o sinal já vem no texto, não só na cor. */
export function delta(v: number | null, unit: string): string {
  if (v === null || !Number.isFinite(v)) return "—";
  const sinal = v > 0 ? "+" : "";
  return unit === "pp" ? `${sinal}${dec2.format(v)} p.p.` : `${sinal}${dec1.format(v)}%`;
}

export type Grain = "dia" | "semana" | "mes";

const MESES = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"];

/** ISO-8601: a semana começa na segunda. */
function segundaDaSemana(d: Date): Date {
  const out = new Date(d);
  const dow = (out.getDay() + 6) % 7;
  out.setDate(out.getDate() - dow);
  return out;
}

function ddmm(d: Date): string {
  return `${String(d.getDate()).padStart(2, "0")}/${String(d.getMonth() + 1).padStart(2, "0")}`;
}

/** Data ISO -> Date local. `new Date("2026-07-01")` seria UTC e voltaria um dia. */
export function parseDia(iso: string): Date {
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(y, m - 1, d);
}

export interface Bucket<T> { key: string; label: string; title: string; rows: T[] }

/** Agrupa a série diária em dia/semana/mês sem voltar ao banco. */
export function agrupar<T extends { dia: string }>(rows: T[], grain: Grain): Bucket<T>[] {
  const mapa = new Map<string, Bucket<T>>();

  for (const row of rows) {
    const d = parseDia(row.dia);
    let key: string, label: string, title: string;

    if (grain === "dia") {
      key = row.dia;
      label = ddmm(d);
      title = d.toLocaleDateString("pt-BR", { day: "2-digit", month: "long", year: "numeric" });
    } else if (grain === "semana") {
      const ini = segundaDaSemana(d);
      const fim = new Date(ini);
      fim.setDate(fim.getDate() + 6);
      key = ini.toISOString().slice(0, 10);
      label = ddmm(ini);
      title = `Semana de ${ddmm(ini)} a ${ddmm(fim)}`;
    } else {
      key = row.dia.slice(0, 7);
      label = `${MESES[d.getMonth()]}/${String(d.getFullYear()).slice(2)}`;
      title = d.toLocaleDateString("pt-BR", { month: "long", year: "numeric" });
    }

    const b = mapa.get(key) ?? { key, label, title, rows: [] };
    b.rows.push(row);
    mapa.set(key, b);
  }

  return [...mapa.values()].sort((a, b) => a.key.localeCompare(b.key));
}

export function soma<T>(rows: T[], campo: (r: T) => number): number {
  return rows.reduce((acc, r) => acc + campo(r), 0);
}
