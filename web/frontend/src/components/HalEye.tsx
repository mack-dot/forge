"use client";

import { motion, useReducedMotion } from "framer-motion";
import { useEffect, useState } from "react";

/**
 * The red eye. Pure theatre: it shows no number and no verdict.
 *
 * It assembles itself from bundles of thin SVG strokes ("bristles"): each bundle
 * is one brush stroke, and its bristles start and stop at slightly different
 * angles, so the ends look dragged. A turbulence filter roughens the edges.
 */
export type EyeMode = "idle" | "streaming" | "flare" | "dim" | "breach";

interface Bristle {
  d: string;
  width: number;
  opacity: number;
  color: string;
  delay: number;
  duration: number;
}

const C = 200; // centre of the 400 x 400 view box

function rng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const f2 = (n: number) => n.toFixed(2);

/** A hand-drawn arc: the radius wobbles slowly along the stroke. */
function wobblyArc(
  r: number,
  startDeg: number,
  sweepDeg: number,
  wobble: number,
  phase: number,
  freq: number,
): string {
  const steps = Math.max(6, Math.round(Math.abs(sweepDeg) / 9));
  const pts: Array<[number, number]> = [];
  for (let i = 0; i <= steps; i++) {
    const deg = startDeg + (sweepDeg * i) / steps;
    const rad = (deg * Math.PI) / 180;
    const rr = r + wobble * Math.sin(rad * freq + phase) + wobble * 0.4 * Math.sin(rad * freq * 2.7 + phase * 1.9);
    pts.push([C + rr * Math.cos(rad), C + rr * Math.sin(rad)]);
  }
  // Catmull-Rom spline through the points, written as cubic Bezier segments.
  const first = pts[0] as [number, number];
  let d = `M${f2(first[0])} ${f2(first[1])}`;
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[Math.max(0, i - 1)] as [number, number];
    const p1 = pts[i] as [number, number];
    const p2 = pts[i + 1] as [number, number];
    const p3 = pts[Math.min(pts.length - 1, i + 2)] as [number, number];
    const c1x = p1[0] + (p2[0] - p0[0]) / 6;
    const c1y = p1[1] + (p2[1] - p0[1]) / 6;
    const c2x = p2[0] - (p3[0] - p1[0]) / 6;
    const c2y = p2[1] - (p3[1] - p1[1]) / 6;
    d += `C${f2(c1x)} ${f2(c1y)} ${f2(c2x)} ${f2(c2y)} ${f2(p2[0])} ${f2(p2[1])}`;
  }
  return d;
}

interface StrokeSpec {
  r: number;
  start: number;
  sweep: number;
  bristles: number;
  spread: number;
  wobble: number;
  colors: string[];
  minW: number;
  maxW: number;
  minO: number;
  maxO: number;
  delay: number;
  duration: number;
}

function brushStroke(spec: StrokeSpec, rand: () => number): Bristle[] {
  const out: Bristle[] = [];
  const phase = rand() * 6.28;
  const freq = 2 + rand() * 2.5;
  for (let i = 0; i < spec.bristles; i++) {
    const t = spec.bristles === 1 ? 0.5 : i / (spec.bristles - 1);
    const off = (t - 0.5) * spec.spread + (rand() - 0.5) * 0.8;
    const lead = rand() * 14; // bristles touch the surface at different moments
    const trail = rand() * 26;
    out.push({
      d: wobblyArc(
        spec.r + off,
        spec.start + lead,
        spec.sweep - lead - trail,
        spec.wobble,
        phase + (rand() - 0.5) * 0.25,
        freq,
      ),
      width: spec.minW + rand() * (spec.maxW - spec.minW),
      opacity: spec.minO + rand() * (spec.maxO - spec.minO),
      color: spec.colors[Math.floor(rand() * spec.colors.length)] ?? "#fff",
      // The screen stays black for a moment; then the strokes arrive.
      delay: 0.45 + spec.delay * 1.3 + rand() * 0.25,
      duration: spec.duration * 1.3 * (0.85 + rand() * 0.3),
    });
  }
  return out;
}

function buildStrokes(): { steel: Bristle[]; red: Bristle[] } {
  const rand = rng(9000);
  const steelColors = ["#e2e8f0", "#cbd5e1", "#94a3b8", "#64748b", "#475569"];
  const redColors = ["#ff3b2f", "#ef4444", "#dc2626", "#b91c1c", "#ff6a4d"];
  const deepRed = ["#7f1d1d", "#991b1b", "#b91c1c"];

  const steel: Bristle[] = [
    // The bezel: two long overlapping sweeps and one short correcting stroke.
    ...brushStroke(
      { r: 178, start: -118, sweep: 352, bristles: 11, spread: 15, wobble: 1.6, colors: steelColors,
        minW: 0.5, maxW: 2.6, minO: 0.35, maxO: 0.95, delay: 0.15, duration: 1.5 }, rand),
    ...brushStroke(
      { r: 171, start: 64, sweep: 338, bristles: 8, spread: 9, wobble: 1.2, colors: steelColors,
        minW: 0.4, maxW: 1.8, minO: 0.25, maxO: 0.8, delay: 0.5, duration: 1.45 }, rand),
    ...brushStroke(
      { r: 186, start: 198, sweep: 120, bristles: 5, spread: 6, wobble: 2.2, colors: ["#f1f5f9", "#cbd5e1"],
        minW: 0.4, maxW: 1.4, minO: 0.3, maxO: 0.75, delay: 1.25, duration: 0.7 }, rand),
    ...brushStroke(
      { r: 163, start: 12, sweep: 150, bristles: 4, spread: 4, wobble: 1, colors: ["#475569", "#334155"],
        minW: 0.6, maxW: 2, minO: 0.5, maxO: 0.9, delay: 1.1, duration: 0.8 }, rand),
  ];

  const red: Bristle[] = [
    ...brushStroke(
      { r: 142, start: -70, sweep: 350, bristles: 5, spread: 5, wobble: 1.1, colors: deepRed,
        minW: 0.5, maxW: 1.6, minO: 0.45, maxO: 0.9, delay: 0.95, duration: 1.2 }, rand),
    ...brushStroke(
      { r: 118, start: 140, sweep: 346, bristles: 7, spread: 8, wobble: 1.3, colors: redColors,
        minW: 0.5, maxW: 2.2, minO: 0.4, maxO: 0.95, delay: 1.3, duration: 1.1 }, rand),
    ...brushStroke(
      { r: 94, start: 20, sweep: 352, bristles: 4, spread: 3.5, wobble: 0.9, colors: redColors,
        minW: 0.4, maxW: 1.3, minO: 0.4, maxO: 0.85, delay: 1.65, duration: 0.95 }, rand),
    ...brushStroke(
      { r: 73, start: -160, sweep: 354, bristles: 6, spread: 6, wobble: 0.8, colors: ["#ff3b2f", "#ff6a4d", "#ff8a3d"],
        minW: 0.5, maxW: 2, minO: 0.5, maxO: 1, delay: 1.95, duration: 0.85 }, rand),
    // Loose accent arcs between the rings.
    ...brushStroke(
      { r: 130, start: 205, sweep: 95, bristles: 3, spread: 3, wobble: 1.6, colors: ["#ff8a3d", "#ff3b2f"],
        minW: 0.4, maxW: 1.1, minO: 0.3, maxO: 0.7, delay: 1.7, duration: 0.5 }, rand),
    ...brushStroke(
      { r: 106, start: 30, sweep: 130, bristles: 3, spread: 3, wobble: 1.4, colors: ["#7f1d1d", "#ef4444"],
        minW: 0.4, maxW: 1.4, minO: 0.3, maxO: 0.7, delay: 1.85, duration: 0.55 }, rand),
    ...brushStroke(
      { r: 152, start: 300, sweep: 110, bristles: 3, spread: 2.5, wobble: 1.4, colors: ["#b91c1c", "#450a0a"],
        minW: 0.4, maxW: 1.2, minO: 0.4, maxO: 0.8, delay: 1.5, duration: 0.6 }, rand),
    ...brushStroke(
      { r: 84, start: 170, sweep: 80, bristles: 2, spread: 2, wobble: 1, colors: ["#ffb26b"],
        minW: 0.4, maxW: 0.9, minO: 0.35, maxO: 0.7, delay: 2.2, duration: 0.45 }, rand),
  ];
  return { steel, red };
}

// Deterministic (seeded): the same strokes on every load.
const STROKES = buildStrokes();

interface Level {
  glow: number[];
  period: number;
  core: number[];
  iris: number;
}

const LEVELS: Record<EyeMode, Level> = {
  idle: { glow: [0.42, 0.72, 0.42], period: 4.6, core: [1, 1.05, 1], iris: 1 },
  streaming: { glow: [0.55, 1, 0.55], period: 0.85, core: [1, 1.16, 1], iris: 1 },
  flare: { glow: [1, 1, 1], period: 0.5, core: [1.5, 1.7, 1.5], iris: 1 },
  dim: { glow: [0.1, 0.14, 0.1], period: 5, core: [0.7, 0.72, 0.7], iris: 0.42 },
  breach: { glow: [0.6, 1, 0.6], period: 0.5, core: [1.2, 1.6, 1.2], iris: 1 },
};

export default function HalEye({ mode, className }: { mode: EyeMode; className?: string }) {
  const reduce = useReducedMotion() === true;
  const { steel, red } = STROKES;
  const level = LEVELS[mode];
  // The drawing delays apply only to the first assembly. After it, the eye
  // reacts to a state change at once.
  const [settled, setSettled] = useState(false);
  useEffect(() => {
    const t = setTimeout(() => setSettled(true), 4600);
    return () => clearTimeout(t);
  }, []);
  const still = reduce || settled;
  const wait = (s: number) => (still ? 0 : s);
  const mid = level.glow[1] ?? 0.6;
  const coreMid = level.core[0] ?? 1;

  const draw = (b: Bristle) =>
    reduce
      ? { initial: false as const, animate: { pathLength: 1, opacity: b.opacity } }
      : {
          initial: { pathLength: 0, opacity: 0 },
          animate: { pathLength: 1, opacity: b.opacity },
          transition: {
            pathLength: { delay: b.delay, duration: b.duration, ease: [0.3, 0.1, 0.25, 1] as const },
            opacity: { delay: b.delay, duration: 0.12 },
          },
        };

  const appear = (delay: number, duration = 0.9) =>
    reduce
      ? { initial: false as const }
      : { initial: { opacity: 0 }, transition: { delay, duration, ease: "easeOut" as const } };

  const loop = reduce
    ? { duration: 0 }
    : { duration: level.period, repeat: Infinity, ease: "easeInOut" as const };

  return (
    <div className={`relative aspect-square ${className ?? ""}`} data-eye-mode={mode} aria-hidden="true">
      {/* The breathing halo behind the lens (box-shadow, opacity pulsing). */}
      <motion.div
        className="absolute inset-[16%] rounded-full"
        initial={reduce ? false : { opacity: 0 }}
        animate={{
          opacity: reduce ? mid : level.glow,
          boxShadow:
            mode === "breach"
              ? "0 0 6rem 2.2rem rgba(255,235,220,0.75), 0 0 14rem 5rem rgba(255,40,30,0.6)"
              : "0 0 5rem 1.4rem rgba(255,48,36,0.55), 0 0 12rem 4rem rgba(255,48,36,0.28)",
        }}
        transition={{ opacity: { ...loop, delay: wait(3.0) }, boxShadow: { duration: 0.4 } }}
      />
      <svg viewBox="0 0 400 400" className="relative block h-full w-full overflow-visible" role="presentation">
        <defs>
          <filter id="eye-brush" x="-10%" y="-10%" width="120%" height="120%">
            <feTurbulence type="fractalNoise" baseFrequency="0.018 0.03" numOctaves="2" seed="7" result="n" />
            <feDisplacementMap in="SourceGraphic" in2="n" scale="6" xChannelSelector="R" yChannelSelector="G" />
          </filter>
          <filter id="eye-brush-fine" x="-10%" y="-10%" width="120%" height="120%">
            <feTurbulence type="fractalNoise" baseFrequency="0.03" numOctaves="2" seed="3" result="n" />
            <feDisplacementMap in="SourceGraphic" in2="n" scale="3" xChannelSelector="R" yChannelSelector="G" />
          </filter>
          <filter id="eye-soft" x="-50%" y="-50%" width="200%" height="200%">
            <feGaussianBlur stdDeviation="5" />
          </filter>
          <radialGradient id="eye-glass" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#3b0503" />
            <stop offset="55%" stopColor="#170202" />
            <stop offset="88%" stopColor="#050308" />
            <stop offset="100%" stopColor="#020617" />
          </radialGradient>
          <radialGradient id="eye-iris" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#fffbe8" />
            <stop offset="10%" stopColor="#ffe27a" />
            <stop offset="24%" stopColor="#ff8a2a" />
            <stop offset="46%" stopColor="#f0200f" />
            <stop offset="72%" stopColor="#8f0d08" />
            <stop offset="100%" stopColor="#3b0503" stopOpacity="0" />
          </radialGradient>
          <radialGradient id="eye-bloom" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#ff5a3c" stopOpacity="0.85" />
            <stop offset="45%" stopColor="#ff2a1a" stopOpacity="0.28" />
            <stop offset="100%" stopColor="#ff2a1a" stopOpacity="0" />
          </radialGradient>
          <linearGradient id="eye-glint" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="#fff" stopOpacity="0.85" />
            <stop offset="100%" stopColor="#fff" stopOpacity="0" />
          </linearGradient>
        </defs>

        {/* The dark glass of the lens. */}
        <motion.circle cx={C} cy={C} r={160} fill="url(#eye-glass)" animate={{ opacity: 1 }} {...appear(1.4, 1.4)} />

        {/* The bezel: brushed steel. */}
        <g filter="url(#eye-brush)" fill="none" strokeLinecap="round">
          {steel.map((b, i) => (
            <motion.path key={i} d={b.d} stroke={b.color} strokeWidth={b.width} {...draw(b)} />
          ))}
        </g>

        {/* Bloom inside the glass; it breathes with the state. */}
        <motion.circle
          cx={C}
          cy={C}
          r={150}
          fill="url(#eye-bloom)"
          initial={reduce ? false : { opacity: 0 }}
          animate={{ opacity: reduce ? mid * 0.9 : level.glow.map((g) => g * 0.9) }}
          transition={{ ...loop, delay: wait(3.0) }}
        />

        {/* The lens rings: brushed red. */}
        <g filter="url(#eye-brush-fine)" fill="none" strokeLinecap="round">
          {red.map((b, i) => (
            <motion.path key={i} d={b.d} stroke={b.color} strokeWidth={b.width} {...draw(b)} />
          ))}
        </g>

        {/* The iris and the hot core. */}
        <motion.g
          style={{ transformOrigin: "200px 200px", transformBox: "view-box" }}
          initial={reduce ? false : { scale: 0, opacity: 0 }}
          animate={{ scale: 1, opacity: level.iris }}
          transition={
            reduce
              ? { duration: 0 }
              : {
                  scale: { delay: wait(3.1), type: "spring", stiffness: 110, damping: 10 },
                  opacity: { delay: wait(3.1), duration: 0.5 },
                }
          }
        >
          <circle cx={C} cy={C} r={66} fill="url(#eye-iris)" />
          <motion.g
            style={{ transformOrigin: "200px 200px", transformBox: "view-box" }}
            animate={{ scale: reduce ? coreMid : level.core }}
            transition={loop}
          >
            <circle cx={C} cy={C} r={17} fill="#ffd76a" filter="url(#eye-soft)" opacity={0.9} />
            <circle cx={C} cy={C} r={8.5} fill={mode === "breach" ? "#ffffff" : "#fffbe8"} />
          </motion.g>
        </motion.g>

        {/* A flare ring: one burst when a tool call arrives. */}
        {mode === "flare" && !reduce && (
          <motion.circle
            cx={C}
            cy={C}
            fill="none"
            stroke="#ffe9a8"
            initial={{ r: 20, opacity: 0.95, strokeWidth: 7 }}
            animate={{ r: 172, opacity: 0, strokeWidth: 0.5 }}
            transition={{ duration: 0.8, ease: "easeOut" }}
          />
        )}

        {/* Glints on the glass. */}
        <motion.g fill="none" strokeLinecap="round" animate={{ opacity: 1 }} {...appear(3.6, 0.8)}>
          <path d={wobblyArc(132, 206, 44, 0, 0, 1)} stroke="url(#eye-glint)" strokeWidth={3.2} opacity={0.55} />
          <path d={wobblyArc(121, 214, 20, 0, 0, 1)} stroke="#fff" strokeWidth={1.4} opacity={0.4} />
          <path d={wobblyArc(140, 28, 26, 0, 0, 1)} stroke="#fda4a4" strokeWidth={1.2} opacity={0.28} />
          <ellipse cx={150} cy={139} rx={9} ry={4} transform="rotate(-38 150 139)" fill="#fff" opacity={0.2} />
        </motion.g>
      </svg>
    </div>
  );
}
