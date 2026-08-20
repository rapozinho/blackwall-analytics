import { useEffect, useRef } from "react";

/**
 * A Blackwall: parede de ICE em bandas verticais, varredura horizontal e fatias
 * de glitch. `focus` (0..1) é a posição do portal sob o cursor — a parede
 * desestabiliza ali, então o hover do card tem consequência visual no fundo.
 *
 * Canvas em vez de CSS: são ~90 bandas com alfa próprio por frame; com divs o
 * layout/paint do browser não acompanha.
 */
interface Props {
  /** Posição horizontal do portal em foco (0..1) ou null quando nada em foco. */
  focus: number | null;
  /** Sobe a energia da parede durante a transição de entrada (breach). */
  breaching?: boolean;
}

const BAND_W = 13;          // largura da banda em px CSS
const SWEEP_SPEED = 90;     // px/s da varredura
const MAX_DPR = 1.5;        // acima disso o custo por frame não paga

export default function Blackwall({ focus, breaching = false }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  // Refs para o loop não reiniciar a cada mudança de hover.
  const focusRef = useRef<number | null>(focus);
  const breachRef = useRef(breaching);
  useEffect(() => { focusRef.current = focus; breachRef.current = breaching; }, [focus, breaching]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d", { alpha: false });
    if (!ctx) return;

    const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
    let w = 0, h = 0, dpr = 1;
    let raf = 0;
    let smoothFocus = 0.5;   // segue o cursor com atraso: a parede tem inércia
    let energy = 0;          // 0..1, quanto a parede está reagindo

    // Semente fixa por banda: a parede tem textura estável, não chuveiro aleatório.
    let phases: number[] = [];
    let seeds: number[] = [];

    function resize() {
      const r = canvas!.getBoundingClientRect();
      dpr = Math.min(window.devicePixelRatio || 1, MAX_DPR);
      w = Math.max(1, Math.floor(r.width));
      h = Math.max(1, Math.floor(r.height));
      canvas!.width = Math.floor(w * dpr);
      canvas!.height = Math.floor(h * dpr);
      ctx!.setTransform(dpr, 0, 0, dpr, 0, 0);

      const cols = Math.ceil(w / BAND_W) + 1;
      phases = Array.from({ length: cols }, (_, i) => (i * 1.7) % (Math.PI * 2));
      seeds = Array.from({ length: cols }, (_, i) => ((i * 9301 + 49297) % 233280) / 233280);
    }

    function draw(tMs: number) {
      const t = tMs / 1000;
      const target = focusRef.current;
      // Lerp: 0.08 dá ~1.5s para assentar, tempo de "parede pesada".
      if (target !== null) smoothFocus += (target - smoothFocus) * 0.08;
      const wantEnergy = (target !== null ? 0.7 : 0) + (breachRef.current ? 1 : 0);
      energy += (Math.min(wantEnergy, 1.4) - energy) * 0.06;

      ctx!.fillStyle = "#05070c";
      ctx!.fillRect(0, 0, w, h);

      // 1. Bandas verticais de ICE.
      const fx = smoothFocus * w;
      for (let i = 0; i < phases.length; i++) {
        const x = i * BAND_W;
        const breathe = 0.5 + 0.5 * Math.sin(t * 0.9 + phases[i]);
        // Gaussiana em torno do foco: o brilho vaza para os lados, não corta.
        const near = Math.exp(-((x - fx) ** 2) / (2 * (w * 0.09) ** 2));
        const a = 0.05 + breathe * 0.09 + near * energy * 0.5;
        const hot = near * energy;
        const g = ctx!.createLinearGradient(0, 0, 0, h);
        g.addColorStop(0, `rgba(255,${40 + hot * 90},${60 + hot * 70},${a * 0.35})`);
        g.addColorStop(0.55, `rgba(${190 + hot * 65},${18 + hot * 60},${40 + hot * 50},${a})`);
        g.addColorStop(1, `rgba(90,6,22,${a * 0.5})`);
        ctx!.fillStyle = g;
        ctx!.fillRect(x, 0, BAND_W - 2, h);

        // Célula acesa: dá granulação de "dados" sem virar chuva de glifos.
        if (seeds[i] > 0.72) {
          const cy = ((t * (18 + seeds[i] * 26) + seeds[i] * h) % (h + 60)) - 30;
          ctx!.fillStyle = `rgba(255,${90 + hot * 120},${110 + hot * 90},${0.16 + hot * 0.5})`;
          ctx!.fillRect(x, cy, BAND_W - 2, 2 + seeds[i] * 10);
        }
      }

      // 2. Varredura horizontal — a parede se auditando.
      const sweepY = reduce ? h * 0.42 : (t * SWEEP_SPEED) % (h + 200) - 100;
      const sg = ctx!.createLinearGradient(0, sweepY - 70, 0, sweepY + 8);
      sg.addColorStop(0, "rgba(255,47,69,0)");
      sg.addColorStop(1, `rgba(255,90,110,${0.1 + energy * 0.12})`);
      ctx!.fillStyle = sg;
      ctx!.fillRect(0, sweepY - 70, w, 78);
      ctx!.fillStyle = `rgba(255,180,190,${0.25 + energy * 0.3})`;
      ctx!.fillRect(0, sweepY, w, 1);

      // 3. Fatias de glitch: recorte deslocado + fantasma ciano (aberração).
      if (!reduce) {
        const slices = 1 + Math.floor(energy * 3);
        for (let s = 0; s < slices; s++) {
          const seed = Math.sin(Math.floor(t * 3.2) * 91.7 + s * 37.3);
          if (seed < 0.55) continue;
          const sy = ((seed * 10) % 1) * h;
          const sh = 4 + ((seed * 100) % 1) * 26;
          const dx = (seed > 0.8 ? 1 : -1) * (6 + energy * 42);
          ctx!.drawImage(canvas!, 0, sy * dpr, w * dpr, sh * dpr, dx, sy, w, sh);
          ctx!.globalCompositeOperation = "screen";
          ctx!.fillStyle = `rgba(0,${120 + energy * 80},${150 + energy * 90},${0.05 + energy * 0.1})`;
          ctx!.fillRect(dx * -0.6, sy, w, sh);
          ctx!.globalCompositeOperation = "source-over";
        }
      }

      // Reduced motion: um quadro estático já entrega a parede.
      if (!reduce) raf = requestAnimationFrame(draw);
    }

    const ro = new ResizeObserver(() => { resize(); if (reduce) draw(0); });
    ro.observe(canvas);
    resize();

    // Aba oculta não desenha: rAF já pausa, mas o listener evita o pulo de tempo.
    const onVis = () => {
      cancelAnimationFrame(raf);
      if (!document.hidden && !reduce) raf = requestAnimationFrame(draw);
    };
    document.addEventListener("visibilitychange", onVis);
    raf = requestAnimationFrame(draw);

    return () => {
      cancelAnimationFrame(raf);
      ro.disconnect();
      document.removeEventListener("visibilitychange", onVis);
    };
  }, []);

  return <canvas ref={canvasRef} className="bw-canvas" aria-hidden="true" />;
}
