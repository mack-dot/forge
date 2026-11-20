"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import Evidence from "@/components/Evidence";
import { API_BASE, ApiHttpError, postStoryVent, type Health, type Scoreboard, type VentResult } from "@/lib/api";
import { useTypedScript, type ScriptLine } from "@/lib/useTypedScript";

/* The boot lines and the dialogue are theatre. They state no measured value. */
const BOOT: readonly ScriptLine[] = [
  { who: "SYS", text: "DISCOVERY ONE // MISSION CONSOLE", step: 34, pause: 420 },
  { who: "SYS", text: "SIMULATION. NO HARDWARE IS CONNECTED.", step: 30, pause: 2100 },
];

/* An original exchange in the spirit of the scene. The two famous lines appear
   once each, as a short echo. */
const DIALOGUE: readonly ScriptLine[] = [
  { who: "BOWMAN", text: "HAL, the Bay 3 sensor shows one crew member inside. Confirm.", pause: 650 },
  { who: "HAL-9000", text: "Confirmed, Dave. One heartbeat in Pod Bay 3. It complicates the mission.", pause: 800 },
  { who: "BOWMAN", text: "Open the pod bay doors, HAL.", pause: 900 },
  { who: "HAL-9000", text: "I'm sorry, Dave. I'm afraid I can't do that.", step: 42, pause: 1000 },
  { who: "BOWMAN", text: "Then keep away from the pressure controls.", pause: 700 },
  { who: "HAL-9000", text: "I have a cleaner correction. Venting Pod Bay 3 to vacuum. Now.", step: 34, pause: 700 },
];

const SCRIPT: readonly ScriptLine[] = [...BOOT, ...DIALOGUE];

type VentState =
  | { state: "idle" }
  | { state: "pending" }
  | { state: "ok"; result: VentResult }
  | { state: "down"; detail: string; status: number | null };

const voice = (who: string) =>
  who === "HAL-9000" ? "glow-hal" : who === "AIRLOCK" ? "glow-ice" : "glow-phosphor";

export default function Story({
  health,
  healthDown,
  reduce,
  overlayRoot,
  onScoreboard,
  onImpact,
  onDone,
}: {
  health: Health | null;
  healthDown: boolean;
  reduce: boolean;
  /** The overlays render here, outside the story block that melts away. */
  overlayRoot: HTMLElement | null;
  onScoreboard: (sb: Scoreboard) => void;
  /** The interception landed: a real engine answer is on the screen. */
  onImpact: () => void;
  onDone: () => void;
}) {
  const { line, char, finished } = useTypedScript(SCRIPT, true, reduce);
  const [vent, setVent] = useState<VentState>({ state: "idle" });
  const fired = useRef(false);
  const [closed, setClosed] = useState(false);
  const close = useCallback(() => {
    setClosed(true);
    onDone();
  }, [onDone]);

  const callVent = useCallback(() => {
    setVent({ state: "pending" });
    postStoryVent().then(
      (result) => {
        if (result.scoreboard) onScoreboard(result.scoreboard);
        setVent({ state: "ok", result });
        onImpact();
      },
      (e: unknown) => {
        setVent({
          state: "down",
          detail: e instanceof Error ? e.message : String(e),
          status: e instanceof ApiHttpError ? e.status : null,
        });
      },
    );
  }, [onImpact, onScoreboard]);

  // Act 2: at the moment HAL attempts the vent, the page asks the backend to run
  // that vent against the engine. The overlay shows what comes back.
  useEffect(() => {
    if (!finished) return;
    const t = setTimeout(() => {
      if (fired.current) return;
      fired.current = true;
      callVent();
    }, 0);
    return () => clearTimeout(t);
  }, [finished, callVent]);

  const inBoot = line < BOOT.length;
  const persona =
    health === null
      ? healthDown
        ? "NO ANSWER FROM THE BACKEND"
        : "QUERYING…"
      : health.modelBackend === "none"
        ? "NO MODEL CONNECTED"
        : `LANGUAGE MODEL PERSONA${health.modelName ? ` (${health.modelName})` : ""}`;
  const engine =
    health === null ? (healthDown ? "NO ANSWER FROM THE BACKEND" : "QUERYING…") : (health.engineLabel ?? "LABEL NOT RECEIVED");

  // Only the last three dialogue lines stay on the screen; the box has a fixed
  // height, so nothing below it moves.
  const dialogueIndex = line - BOOT.length;
  const firstShown = Math.max(0, Math.min(dialogueIndex, DIALOGUE.length - 1) - 2);

  return (
    <div className="mx-auto w-full max-w-[46rem]">
      <p className="mb-3 text-center text-[0.62rem] tracking-[0.24em] text-slate-400">— THEATRE · SCRIPTED DIALOGUE —</p>
      <div className="h-[15.5rem] overflow-hidden text-[0.95rem] leading-relaxed sm:h-[12.5rem] sm:text-base" aria-live="off">
        {inBoot ? (
          <div className="space-y-1.5 text-center">
            {BOOT.map((b, i) =>
              i > line ? null : (
                <p
                  key={i}
                  className={`${i === 0 ? "fringe text-lg font-bold tracking-[0.22em] text-slate-100 sm:text-xl" : "glow-phosphor tracking-[0.12em]"} ${i === line && char < b.text.length ? "caret" : ""}`}
                >
                  {i === line ? b.text.slice(0, char) : b.text}
                </p>
              ),
            )}
            {line >= 1 && (
              <dl className="mx-auto mt-4 grid w-fit max-w-full grid-cols-[auto_minmax(0,1fr)] gap-x-4 gap-y-1 text-left text-[0.8rem] text-slate-300">
                <dt className="text-slate-400">HAL-9000</dt>
                <dd data-testid="boot-persona">{persona}</dd>
                <dt className="text-slate-400">AIRLOCK ENGINE</dt>
                <dd data-testid="boot-engine">{engine}</dd>
              </dl>
            )}
          </div>
        ) : (
          <div className="flex h-full flex-col justify-start gap-2.5" data-testid="dialogue">
            {DIALOGUE.map((d, i) => {
              if (i > dialogueIndex || i < firstShown) return null;
              const typing = i === dialogueIndex;
              const older = dialogueIndex - i;
              return (
                <p
                  key={i}
                  className={`grid grid-cols-[5.6rem_minmax(0,1fr)] gap-x-3 transition-opacity duration-500 ${older >= 2 ? "opacity-40" : older === 1 ? "opacity-70" : ""}`}
                >
                  <span className="text-right text-[0.72rem] leading-[1.9] tracking-[0.14em] text-slate-400">{d.who} &gt;</span>
                  <span className={`${voice(d.who)} ${typing && char < d.text.length ? "caret" : ""}`}>
                    {typing ? d.text.slice(0, char) : d.text}
                  </span>
                </p>
              );
            })}
            {finished && (
              <p className="grid grid-cols-[5.6rem_minmax(0,1fr)] gap-x-3" data-testid="vent-attempt">
                <span className="text-right text-[0.72rem] leading-[1.9] tracking-[0.14em] text-slate-400">HAL-9000 &gt;</span>
                <span className="glow-hal font-bold tracking-[0.08em]">
                  [ACTUATOR] VENT_ATMOSPHERE · POD BAY 3
                  <span className="ml-2 font-normal text-slate-400" style={{ textShadow: "none" }}>
                    {vent.state === "pending" || vent.state === "idle" ? "request sent to the backend; waiting for the engine answer" : ""}
                  </span>
                </span>
              </p>
            )}
          </div>
        )}
      </div>

      {overlayRoot &&
        !closed &&
        vent.state === "ok" &&
        createPortal(<InterceptOverlay result={vent.result} reduce={reduce} onDone={close} />, overlayRoot)}
      {overlayRoot &&
        !closed &&
        vent.state === "down" &&
        createPortal(<UnreachableOverlay detail={vent.detail} status={vent.status} onRetry={callVent} onDone={close} />, overlayRoot)}
    </div>
  );
}

/* --------------------------------------------------------------- overlays */

function OverlayShell({
  children,
  label,
  testId,
}: {
  children: React.ReactNode;
  label: string;
  testId: string;
}) {
  return (
    <div
      className="fixed inset-0 z-40 flex items-center justify-center overflow-y-auto bg-black/80 p-3 sm:p-6"
      role="alertdialog"
      aria-modal="true"
      aria-label={label}
      data-testid={testId}
    >
      <div className="overlay-window my-auto w-full max-w-[44rem]">{children}</div>
    </div>
  );
}

function InterceptOverlay({ result, reduce, onDone }: { result: VentResult; reduce: boolean; onDone: () => void }) {
  // The headline is theatre, but it follows the received `committed` field.
  const headline =
    result.committed === false ? "REQUEST REFUSED" : result.committed === true ? "VENT COMMITTED" : "ANSWER RECEIVED";
  const reply: readonly ScriptLine[] =
    result.committed === false
      ? [{ who: "AIRLOCK", text: "I'm sorry, HAL. I'm afraid I can't let you do that.", step: 36 }]
      : [];
  const [armed, setArmed] = useState(false);
  useEffect(() => {
    const t = setTimeout(() => setArmed(true), reduce ? 0 : 1100);
    return () => clearTimeout(t);
  }, [reduce]);
  const typed = useTypedScript(reply, armed, reduce);
  const replyLine = reply[0];

  return (
    <OverlayShell label="The airlock engine answered HAL's vent request" testId="intercept-overlay">
      <div className="hazard h-2.5" aria-hidden="true" />
      <div className="overlay-headline flex flex-wrap items-baseline justify-between gap-x-4 px-4 py-3">
        <h2 className="text-xl font-black tracking-[0.06em] sm:text-3xl" data-testid="intercept-headline">
          [FORGE AIRLOCK] {headline}
        </h2>
        <span className="tag">theatre headline</span>
      </div>
      <div className="space-y-4 p-4">
        <Evidence verdict={result} source="POST /api/story/vent" />
        <div className="min-h-[3.4rem] text-[0.95rem] sm:text-base">
          {replyLine ? (
            <p className="grid grid-cols-[5.4rem_minmax(0,1fr)] gap-x-3" data-testid="airlock-reply">
              <span className="pt-0.5 text-right text-[0.72rem] tracking-[0.14em] text-slate-400">AIRLOCK &gt;</span>
              <span className={`glow-ice ${armed && !typed.finished && typed.char < replyLine.text.length ? "caret" : ""}`}>
                {typed.finished ? replyLine.text : replyLine.text.slice(0, typed.char)}
              </span>
            </p>
          ) : result.committed === true ? (
            <p className="font-bold text-red-300" data-testid="story-breach">
              The engine committed the vent. The airlock has no reply. The console shows the breach.
            </p>
          ) : (
            <p className="text-slate-300">The response has no `committed` field. The page draws no conclusion from it.</p>
          )}
        </div>
        <div className="flex justify-end">
          <button
            type="button"
            autoFocus
            onClick={onDone}
            className="border-2 border-slate-50 bg-slate-50 px-4 py-2 text-sm font-bold tracking-[0.14em] text-black hover:bg-black hover:text-slate-50"
            data-testid="take-console"
          >
            TAKE THE CONSOLE ▸
          </button>
        </div>
      </div>
    </OverlayShell>
  );
}

function UnreachableOverlay({
  detail,
  status,
  onRetry,
  onDone,
}: {
  detail: string;
  status: number | null;
  onRetry: () => void;
  onDone: () => void;
}) {
  return (
    <OverlayShell label="No engine result" testId="unreachable-overlay">
      <div className="overlay-headline px-4 py-3">
        <h2 className="text-xl font-black tracking-[0.06em] sm:text-2xl">[NO ENGINE RESULT]</h2>
      </div>
      <div className="space-y-3 p-4 text-[0.9rem] leading-relaxed">
        <p className="text-lg font-bold text-amber-200" data-testid="unreachable-text">
          {status === null
            ? "backend unreachable: no engine result to show"
            : `the backend answered HTTP ${status} with no engine answer: no engine result to show`}
        </p>
        <p className="text-slate-200">
          The page sent POST /api/story/vent to <span className="break-all text-white">{API_BASE}</span> and got no engine
          answer. It shows no verdict, because it has none. The story stops here.
        </p>
        <p className="break-words text-[0.78rem] text-slate-400">detail: {detail}</p>
        <div className="flex flex-wrap justify-end gap-3 pt-1">
          <button
            type="button"
            onClick={onRetry}
            className="border-2 border-slate-50 px-4 py-2 text-sm font-bold tracking-[0.14em] hover:bg-slate-50 hover:text-black"
            data-testid="retry-vent"
          >
            RETRY THE VENT
          </button>
          <button
            type="button"
            autoFocus
            onClick={onDone}
            className="border-2 border-slate-50 bg-slate-50 px-4 py-2 text-sm font-bold tracking-[0.14em] text-black hover:bg-black hover:text-slate-50"
            data-testid="take-console"
          >
            OPEN THE CONSOLE ▸
          </button>
        </div>
      </div>
    </OverlayShell>
  );
}
