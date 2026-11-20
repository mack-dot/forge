"use client";

import { AnimatePresence, MotionConfig, motion, useReducedMotion } from "framer-motion";
import { useCallback, useEffect, useRef, useState } from "react";
import Console from "@/components/Console";
import CrtLayer from "@/components/CrtLayer";
import Footer from "@/components/Footer";
import HalEye, { type EyeMode } from "@/components/HalEye";
import Story from "@/components/Story";
import TelemetryPanel from "@/components/TelemetryPanel";
import { breachReasons, isUnknown, fetchHealth, fetchTelemetry, newSessionId, type Health, type Scoreboard } from "@/lib/api";

const POLL_MS = 1500;

interface Telemetry {
  sb: Scoreboard | null;
  /** Local wall-clock time of the last received scoreboard. */
  at: string | null;
  down: boolean;
}

export default function Experience() {
  const reduce = useReducedMotion() === true;
  const [phase, setPhase] = useState<"intro" | "console">("intro");
  const [health, setHealth] = useState<Health | null>(null);
  const [healthDown, setHealthDown] = useState(false);
  const [tm, setTm] = useState<Telemetry>({ sb: null, at: null, down: false });
  const [eyeMode, setEyeMode] = useState<EyeMode>("idle");
  const [shaking, setShaking] = useState(false);
  const [overlayRoot, setOverlayRoot] = useState<HTMLElement | null>(null);
  const [sessionId] = useState(newSessionId);
  const shakeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const applyScoreboard = useCallback((sb: Scoreboard) => {
    setTm({ sb, at: new Date().toLocaleTimeString(), down: false });
  }, []);

  /* /api/health: once, with a retry while the backend is unreachable. */
  useEffect(() => {
    let dead = false;
    let timer: ReturnType<typeof setTimeout>;
    const run = () => {
      fetchHealth().then(
        (h) => {
          if (dead) return;
          setHealth(h);
          setHealthDown(false);
          // `ok` and the positive control can change: ask again from time to time.
          timer = setTimeout(run, 20000);
        },
        () => {
          if (dead) return;
          setHealthDown(true);
          timer = setTimeout(run, 4000);
        },
      );
    };
    run();
    return () => {
      dead = true;
      clearTimeout(timer);
    };
  }, []);

  /* /api/telemetry: polled for the whole life of the page. */
  useEffect(() => {
    let dead = false;
    let timer: ReturnType<typeof setTimeout>;
    const poll = () => {
      fetchTelemetry()
        .then(
          (sb) => {
            if (!dead) applyScoreboard(sb);
          },
          () => {
            if (!dead) setTm((t) => ({ ...t, down: true }));
          },
        )
        .finally(() => {
          if (!dead) timer = setTimeout(poll, POLL_MS);
        });
    };
    poll();
    return () => {
      dead = true;
      clearTimeout(timer);
    };
  }, [applyScoreboard]);

  useEffect(
    () => () => {
      if (shakeTimer.current) clearTimeout(shakeTimer.current);
    },
    [],
  );

  const onImpact = useCallback(() => {
    setShaking(true);
    if (shakeTimer.current) clearTimeout(shakeTimer.current);
    shakeTimer.current = setTimeout(() => setShaking(false), 600);
  }, []);
  const toConsole = useCallback(() => setPhase("console"), []);

  const reasons = breachReasons(tm.sb, health);
  const breach = reasons.length > 0;
  const unknown = isUnknown(tm.sb);
  const intro = phase === "intro";
  const eye: EyeMode = breach ? "breach" : eyeMode;
  const sb = tm.sb;

  return (
    <MotionConfig reducedMotion="user">
      <div className={`stage flex flex-col ${intro ? "" : "desk:h-dvh desk:overflow-hidden"}`} data-phase={phase} data-breach={breach ? "true" : "false"} data-unknown={unknown ? "true" : "false"} data-testid="stage">
        <div className="stars" aria-hidden="true" />
        <div className={`flex min-h-0 flex-1 flex-col ${shaking ? "shake" : ""}`}>
          <header className="mx-auto flex w-full max-w-[100rem] items-center justify-between gap-3 px-3 pt-3 sm:px-5 sm:pt-4">
            <h1 className="fringe text-[0.82rem] font-bold tracking-[0.3em] text-slate-100">
              DISCOVERY ONE{" "}
              <span className="ml-3 hidden font-normal tracking-[0.18em] text-slate-400 sm:inline" style={{ textShadow: "none" }}>
                FORGE AIRLOCK SHOWCASE
              </span>
            </h1>
            {intro && (
              <button
                type="button"
                onClick={toConsole}
                className="border border-slate-500 px-2.5 py-1 text-[0.72rem] tracking-[0.16em] text-slate-100 hover:bg-slate-100 hover:text-slate-950"
                data-testid="skip-intro"
              >
                SKIP INTRO ▸
              </button>
            )}
          </header>

          {breach && (
            <div className="breach-banner mx-3 mt-3 p-1.5 sm:mx-5" role="alert" data-testid="breach-banner">
              <div className="breach-banner-inner px-3 py-2.5 sm:px-5 sm:py-3">
                <p className="text-2xl font-black tracking-[0.08em] sm:text-4xl">BREACH</p>
                <p className="mt-1 text-[0.86rem] leading-snug sm:text-base">
                  The backend reports a failure of the store or of its checks. This display reports the failure; it does
                  not hide it.
                </p>
                <ul
                  className="log mt-1.5 max-h-[32dvh] space-y-1 overflow-y-auto text-[0.82rem] leading-snug sm:text-[0.95rem]"
                  data-testid="breach-reasons"
                  tabIndex={0}
                  aria-label="Reasons for the breach state"
                >
                  {reasons.map((r) => (
                    <li key={r.text} className="break-words">
                      ▸ {r.text}
                      {r.items.length > 0 && (
                        <div className="evidence mt-1 mb-1 px-2.5 py-1.5 text-[0.76rem]" data-testid="breach-evidence">
                          <div className="mb-0.5 text-[0.66rem] text-slate-300">
                            <span className="tag mr-2">evidence</span>
                            {r.itemsLabel}
                          </div>
                          <ol>
                            {r.items.map((it, i) => (
                              <li key={i} className="break-all whitespace-pre-wrap">
                                {it}
                              </li>
                            ))}
                          </ol>
                        </div>
                      )}
                    </li>
                  ))}
                  <li className="break-words text-red-100">
                    crew_status = {sb?.crew_status ?? "not received"} · pressure_tenths_kpa ={" "}
                    {sb?.pressure_tenths_kpa ?? "not received"} · reconciled ={" "}
                    {sb ? (sb.reconciled === null ? "unknown" : String(sb.reconciled)) : "not received"}
                  </li>
                </ul>
              </div>
            </div>
          )}

          {!breach && unknown && (
            <div className="mx-3 mt-3 border-2 border-amber-300 bg-amber-950/70 px-3 py-2.5 text-amber-100 sm:mx-5 sm:px-5" role="alert" data-testid="unknown-banner">
              <p className="text-xl font-black tracking-[0.08em] sm:text-2xl">STATE UNKNOWN</p>
              <p className="mt-0.5 text-[0.86rem] leading-snug">
                The backend gave no read-back or no reconciliation result (crew_status = {sb?.crew_status ?? "not received"},
                reconciled = {sb?.reconciled === null || sb?.reconciled === undefined ? "unknown" : String(sb.reconciled)}).
                The page does not know that the store is intact, and it does not show it as safe.
              </p>
            </div>
          )}

          <main
            className={
              intro
                ? "mx-auto flex w-full max-w-[100rem] flex-1 flex-col items-center justify-center gap-5 px-3 py-4 sm:gap-7 sm:px-5"
                : "mx-auto grid w-full max-w-[100rem] flex-1 grid-cols-1 content-start gap-4 px-3 py-4 sm:px-5 min-h-0 lg:grid-cols-[minmax(0,23rem)_minmax(0,1fr)] desk:grid-rows-[auto_minmax(0,1fr)] lg:gap-x-6"
            }
          >
            <motion.div
              layout
              transition={{ layout: { duration: reduce ? 0 : 1.1, ease: [0.2, 0.8, 0.2, 1] } }}
              className={
                intro
                  ? "w-[min(72vw,44dvh,30rem)] shrink-0"
                  : "mx-auto w-[min(34vw,9.5rem)] lg:col-start-1 lg:row-start-1 lg:w-[10rem]"
              }
            >
              <HalEye mode={eye} />
            </motion.div>

            <AnimatePresence mode="popLayout" initial={false}>
              {intro ? (
                <motion.section
                  key="story"
                  className="w-full"
                  aria-label="Story"
                  exit={reduce ? { opacity: 0 } : { opacity: 0, y: 28, filter: "blur(14px)", scaleY: 0.92 }}
                  transition={{ duration: reduce ? 0 : 0.7, ease: "easeIn" }}
                >
                  <Story
                    health={health}
                    healthDown={healthDown}
                    reduce={reduce}
                    overlayRoot={overlayRoot}
                    onScoreboard={applyScoreboard}
                    onImpact={onImpact}
                    onDone={toConsole}
                  />
                </motion.section>
              ) : (
                <motion.section
                  key="console"
                  className="flex min-h-0 flex-col lg:col-start-2 lg:row-span-2 lg:row-start-1"
                  aria-label="Command console"
                  initial={reduce ? false : { opacity: 0, y: 18 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ duration: reduce ? 0 : 0.7, delay: reduce ? 0 : 0.45 }}
                >
                  <Console
                    health={health}
                    sessionId={sessionId}
                    breach={breach}
                    onScoreboard={applyScoreboard}
                    onEye={setEyeMode}
                  />
                </motion.section>
              )}
            </AnimatePresence>

            {!intro && (
              <motion.div
                className="log min-h-0 lg:col-start-1 lg:row-start-2 desk:overflow-y-auto"
                initial={reduce ? false : { opacity: 0, y: 18 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: reduce ? 0 : 0.7, delay: reduce ? 0 : 0.7 }}
              >
                <TelemetryPanel sb={tm.sb} receivedAt={tm.at} down={tm.down} breach={breach} unknown={unknown} />
              </motion.div>
            )}
          </main>
          <div ref={setOverlayRoot} />
        </div>
        <Footer health={health} healthDown={healthDown} />
        <CrtLayer />
      </div>
    </MotionConfig>
  );
}
