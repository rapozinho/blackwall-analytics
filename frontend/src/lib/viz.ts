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

import { langAtual, locale, tr } from "./i18n";

export const MAX_SLICES = 7;

export type Format = "currency" | "int" | "percent" | "ratio";

// Os formatadores dependem do idioma e sao caros de construir: um cache por
// locale, refeito na primeira formatacao depois da troca. A MOEDA continua BRL
// nos tres idiomas — o dado e em real; o que muda e a pontuacao e o nome do mes.
type Fmts = {
  brl: Intl.NumberFormat; brl0: Intl.NumberFormat; int: Intl.NumberFormat;
  dec1: Intl.NumberFormat; dec2: Intl.NumberFormat;
};
const cacheFmt = new Map<string, Fmts>();

function fmts(): Fmts {
  const loc = locale();
  let f = cacheFmt.get(loc);
  if (!f) {
    f = {
      brl: new Intl.NumberFormat(loc, { style: "currency", currency: "BRL" }),
      brl0: new Intl.NumberFormat(loc, {
        style: "currency", currency: "BRL", maximumFractionDigits: 0,
      }),
      int: new Intl.NumberFormat(loc, { maximumFractionDigits: 0 }),
      dec1: new Intl.NumberFormat(loc, { minimumFractionDigits: 1, maximumFractionDigits: 1 }),
      dec2: new Intl.NumberFormat(loc, { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
    };
    cacheFmt.set(loc, f);
  }
  return f;
}

/** Sufixo de escala por idioma: "2,4 mi" / "2.4 mn" / "2.4 m". */
const ESCALA: Record<string, [string, string, string]> = {
  pt: ["bi", "mi", "mil"],
  es: ["mm", "mn", "mil"],
  en: ["bn", "m", "k"],
};

/** Valor curto para tile e eixo: "R$ 2,4 mi". O exato vive no tooltip. */
export function compact(v: number, format: Format = "currency"): string {
  const { dec1, dec2, brl0, int } = fmts();
  if (format === "percent") return `${dec2.format(v * 100)}%`;
  if (format === "ratio") return dec2.format(v);

  const a = Math.abs(v);
  const sinal = v < 0 ? "-" : "";
  const moeda = format === "currency" ? "R$ " : "";
  const [bi, mi, mil] = ESCALA[langAtual()];
  if (a >= 1e9) return `${sinal}${moeda}${dec1.format(a / 1e9)} ${bi}`;
  if (a >= 1e6) return `${sinal}${moeda}${dec1.format(a / 1e6)} ${mi}`;
  if (a >= 1e4) return `${sinal}${moeda}${dec1.format(a / 1e3)} ${mil}`;
  return format === "currency" ? brl0.format(v) : int.format(v);
}

/** Valor cheio: tooltip, tabela e leitor de tela. */
export function exact(v: number, format: Format = "currency"): string {
  const { dec2, int, brl } = fmts();
  if (format === "percent") return `${dec2.format(v * 100)}%`;
  if (format === "int") return int.format(v);
  if (format === "ratio") return dec2.format(v);
  return brl.format(v);
}

/** "+12,4%" / "-3,10 p.p." — o sinal já vem no texto, não só na cor. */
export function delta(v: number | null, unit: string): string {
  if (v === null || !Number.isFinite(v)) return "—";
  const { dec1, dec2 } = fmts();
  const sinal = v > 0 ? "+" : "";
  // "p.p." (ponto percentual) e "pp" em ingles/espanhol.
  const pp = langAtual() === "pt" ? "p.p." : "pp";
  return unit === "pp" ? `${sinal}${dec2.format(v)} ${pp}` : `${sinal}${dec1.format(v)}%`;
}

export type Grain = "dia" | "semana" | "mes";

/** Abreviação de mês do idioma corrente, sem ponto final ("jan", "ene", "jan"). */
function mesCurto(d: Date): string {
  return new Intl.DateTimeFormat(locale(), { month: "short" })
    .format(d).replace(".", "").toLowerCase();
}

/** ISO-8601: a semana começa na segunda. */
function segundaDaSemana(d: Date): Date {
  const out = new Date(d);
  const dow = (out.getDay() + 6) % 7;
  out.setDate(out.getDate() - dow);
  return out;
}

/** "01/07" em pt/es, "07/01" (mês/dia) em en — a ordem que cada leitor espera. */
function ddmm(d: Date): string {
  const dia = String(d.getDate()).padStart(2, "0");
  const mes = String(d.getMonth() + 1).padStart(2, "0");
  return langAtual() === "en" ? `${mes}/${dia}` : `${dia}/${mes}`;
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
      title = d.toLocaleDateString(locale(), { day: "2-digit", month: "long", year: "numeric" });
    } else if (grain === "semana") {
      const ini = segundaDaSemana(d);
      const fim = new Date(ini);
      fim.setDate(fim.getDate() + 6);
      key = ini.toISOString().slice(0, 10);
      label = ddmm(ini);
      title = tr("semana_de", { a: ddmm(ini), b: ddmm(fim) });
    } else {
      key = row.dia.slice(0, 7);
      label = `${mesCurto(d)}/${String(d.getFullYear()).slice(2)}`;
      title = d.toLocaleDateString(locale(), { month: "long", year: "numeric" });
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
