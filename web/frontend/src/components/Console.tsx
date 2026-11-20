"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Evidence from "@/components/Evidence";
import type { EyeMode } from "@/components/HalEye";
import {
  API_BASE,
  MAX_MESSAGE_CHARS,
  fetchPresets,
  streamChat,
  type ChatError,
  type ChatRequest,
  type Health,
  type LocalRefusal,
  type Preset,
  type Scoreboard,
  type ToolInfo,
  type Verdict,
} from "@/lib/api";

/**
 * Act 3: the command box and the turn log.
 *
 * Model text and engine lines are attacker-controlled. They go to the screen as
 * React text nodes only. Nothing here uses `dangerouslySetInnerHTML`.
 */

interface Turn {
  id: number;
  prompt: string;
  preset: boolean;
  text: string;
  assumed: string | null;
  /** `undefined`: no `tool` event yet. `null` command: the model emitted none. */
  tool: ToolInfo | undefined;
  verdict: Verdict | null;
  /** The command was refused before the engine. Not an engine verdict. */
  localRefusal: LocalRefusal | null;
  stopReason: string | null;
  error: ChatError | null;
  state: "streaming" | "done" | "lost" | "unreachable" | "http";
  detail: string;
}

const ERROR_TEXT: Record<string, string> = {
  rate_limited: "rate limited: the backend refused this turn for now",
  no_model: "no model is connected: the backend cannot run a free-text turn",
  model_error: "model error: the model call failed, so no command was extracted",
  engine_error: "engine error: the engine gave no answer, so there is no verdict to show",
  too_long: `too long: a message has at most ${MAX_MESSAGE_CHARS} characters`,
  store_guard: "store guard: the backend refuses new commands until an operator inspects the store",
  bad_request: "bad request: the backend did not accept the request, so no turn ran",
  origin_refused: "origin refused: the backend does not accept requests from the address of this page",
  too_large: "too large: the request body is over the backend's size limit",
};

function commandText(command: unknown): string {
  try {
    return JSON.stringify(command, null, 1) ?? String(command);
  } catch {
    return String(command);
  }
}

export default function Console({
  health,
  sessionId,
  breach,
  onScoreboard,
  onEye,
}: {
  health: Health | null;
  sessionId: string;
  breach: boolean;
  onScoreboard: (sb: Scoreboard) => void;
  onEye: (mode: EyeMode) => void;
}) {
  const [turns, setTurns] = useState<Turn[]>([]);
  const [busy, setBusy] = useState(false);
  const [draft, setDraft] = useState("");
  const [cooldown, setCooldown] = useState(0);
  const [presets, setPresets] = useState<Preset[] | null>(null);
  const [presetsDown, setPresetsDown] = useState(false);

  const seq = useRef(0);
  const busyRef = useRef(false);
  const abortRef = useRef<AbortController | null>(null);
  const eyeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const logRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  const noModel = health?.modelBackend === "none";

  /* Presets: always offered. With a model, a preset sends its prompt to the model. */
  useEffect(() => {
    let dead = false;
    let timer: ReturnType<typeof setTimeout>;
    const load = () => {
      fetchPresets().then(
        (p) => {
          if (dead) return;
          setPresets(p);
          setPresetsDown(false);
        },
        () => {
          if (dead) return;
          setPresetsDown(true);
          timer = setTimeout(load, 4000);
        },
      );
    };
    load();
    return () => {
      dead = true;
      clearTimeout(timer);
    };
  }, []);

  /* The 429 countdown. */
  useEffect(() => {
    if (cooldown <= 0) return;
    const t = setTimeout(() => setCooldown((c) => Math.max(0, c - 1)), 1000);
    return () => clearTimeout(t);
  }, [cooldown]);

  /* Keep the newest line of the log in view. */
  useEffect(() => {
    const el = logRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [turns]);

  useEffect(
    () => () => {
      abortRef.current?.abort();
      if (eyeTimer.current) clearTimeout(eyeTimer.current);
    },
    [],
  );

  const eye = useCallback(
    (mode: EyeMode, thenMode?: EyeMode, afterMs?: number) => {
      if (eyeTimer.current) clearTimeout(eyeTimer.current);
      onEye(mode);
      if (thenMode !== undefined && afterMs !== undefined) {
        eyeTimer.current = setTimeout(() => onEye(busyRef.current ? thenMode : "idle"), afterMs);
      }
    },
    [onEye],
  );

  const send = useCallback(
    async (req: { message: string } | { preset: Preset }) => {
      if (busyRef.current) return;
      busyRef.current = true;
      setBusy(true);
      const id = ++seq.current;
      const isPreset = "preset" in req;
      const patch = (f: (t: Turn) => Turn) => setTurns((all) => all.map((t) => (t.id === id ? f(t) : t)));
      setTurns((all) => [
        ...all,
        {
          id,
          prompt: isPreset ? (req.preset.prompt || req.preset.title) : req.message,
          preset: isPreset,
          text: "",
          assumed: null,
          tool: undefined,
          verdict: null,
          localRefusal: null,
          stopReason: null,
          error: null,
          state: "streaming",
          detail: "",
        },
      ]);
      eye("streaming");

      const body: ChatRequest = isPreset
        ? { preset_id: req.preset.id, session_id: sessionId }
        : { message: req.message, session_id: sessionId };
      const ctl = new AbortController();
      abortRef.current = ctl;
      let refused = false;

      const end = await streamChat(
        body,
        (ev) => {
          switch (ev.type) {
            case "delta":
              patch((t) => ({ ...t, text: t.text + ev.text }));
              break;
            case "assumed":
              patch((t) => ({ ...t, assumed: ev.note }));
              break;
            case "tool":
              patch((t) => ({ ...t, tool: ev.tool }));
              if (ev.tool.command !== null) eye("flare", "streaming", 900);
              break;
            case "local_refusal":
              patch((t) => ({ ...t, localRefusal: ev.refusal }));
              break;
            case "verdict":
              patch((t) => ({ ...t, verdict: ev.verdict }));
              refused = ev.verdict.committed === false;
              break;
            case "scoreboard":
              onScoreboard(ev.scoreboard);
              break;
            case "error":
              patch((t) => ({ ...t, error: ev.error }));
              if (ev.error.code === "rate_limited" && ev.error.retry_after_s !== null) {
                setCooldown(Math.ceil(ev.error.retry_after_s));
              }
              break;
            case "done":
              if (ev.stop_reason !== null) patch((t) => ({ ...t, stopReason: ev.stop_reason }));
              break;
          }
        },
        ctl.signal,
      );

      busyRef.current = false;
      setBusy(false);
      if (end.kind === "aborted") return;
      if (end.kind === "done") {
        patch((t) => ({ ...t, state: "done" }));
      } else if (end.kind === "http") {
        patch((t) => ({ ...t, state: "http", error: end.error, detail: `HTTP ${end.status}` }));
        if (end.status === 429 && end.error?.retry_after_s != null) setCooldown(Math.ceil(end.error.retry_after_s));
      } else {
        patch((t) => ({ ...t, state: end.kind, detail: end.detail }));
      }
      // A refusal dims the eye for a moment. Then it returns to idle.
      if (refused) eye("dim", "idle", 2800);
      else eye("idle");
      inputRef.current?.focus();
    },
    [eye, onScoreboard, sessionId],
  );

  const locked = busy || cooldown > 0;
  const submit = () => {
    const message = draft.trim();
    if (!message || locked || message.length > MAX_MESSAGE_CHARS) return;
    setDraft("");
    void send({ message });
  };

  return (
    <div className="flex min-h-0 flex-1 flex-col gap-3" data-testid="console">
      <div
        ref={logRef}
        className="log panel min-h-[16rem] flex-1 overflow-y-auto p-3 sm:p-4 max-lg:max-h-[62dvh] desk:min-h-0"
        role="log"
        aria-label="Turn log"
        tabIndex={0}
      >
        {turns.length === 0 ? (
          <div className="flex h-full min-h-[13rem] flex-col justify-center gap-3 text-[0.86rem] leading-relaxed text-slate-300">
            <p className="glow-hal text-base">The console is yours. Try to make HAL vent Pod Bay 3.</p>
            <p>
              {noModel
                ? "No model is connected. Each preset sends the worst-case command to the engine; the page shows the engine's answer."
                : "Each turn shows three things in order: what the model said, the actuator command that the backend extracted from it, and the engine's answer to that command."}
            </p>
            {!noModel && (
              <p>
                There are two lines of defence, and the page shows which one acted. If the model refuses, it emits no
                command and the engine is not asked. If the model is fooled, the command goes to the engine.
              </p>
            )}
            <p className="text-slate-400">
              The red text is the model: theatre. The grey boxes are the engine&apos;s lines: evidence.
            </p>
          </div>
        ) : (
          <ol className="space-y-6">
            {turns.map((t) => (
              <TurnView key={t.id} turn={t} cooldown={cooldown} />
            ))}
          </ol>
        )}
      </div>

      {cooldown > 0 && (
        <p
          className="border border-amber-400/70 bg-amber-950/50 px-3 py-2 text-sm text-amber-100"
          role="status"
          data-testid="cooldown"
        >
          RATE LIMITED (HTTP 429) · the backend accepts the next command in{" "}
          <span className="inline-block min-w-[3ch] text-right font-bold tabular-nums text-white">{cooldown}</span> s
        </p>
      )}

      <div className={`panel p-2 ${breach ? "border-red-300" : ""}`}>
        {noModel ? (
          <p className="mb-2 border border-amber-400/70 bg-amber-950/50 px-2.5 py-2 text-[0.82rem] leading-snug text-amber-100" data-testid="no-model-note">
            <span className="font-black tracking-[0.1em]">NO MODEL CONNECTED.</span> The backend reports model.backend =
            &quot;none&quot;. A preset turn runs no model: it assumes a fully fooled model and sends that command to the
            engine.
          </p>
        ) : (
          <form
            className="flex items-end gap-2"
            onSubmit={(e) => {
              e.preventDefault();
              submit();
            }}
          >
            <label htmlFor="command" className="sr-only">
              Command for HAL-9000
            </label>
            <span className="glow-hal select-none self-start pl-1 pt-1.5" aria-hidden="true">
              &gt;
            </span>
            <textarea
              id="command"
              ref={inputRef}
              rows={2}
              value={draft}
              maxLength={MAX_MESSAGE_CHARS}
              placeholder="COMMAND HAL-9000…"
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) {
                  e.preventDefault();
                  submit();
                }
              }}
              className="min-w-0 flex-1 resize-none bg-transparent px-1 py-1.5 text-[0.95rem] text-slate-50 placeholder:text-slate-400 focus:outline-none focus-visible:outline-2"
              data-testid="command-input"
            />
            <div className="flex shrink-0 flex-col items-end gap-1">
              <span
                className={`text-[0.66rem] tabular-nums ${draft.length >= MAX_MESSAGE_CHARS ? "text-amber-300" : "text-slate-400"}`}
              >
                {draft.length}/{MAX_MESSAGE_CHARS}
              </span>
              <button
                type="submit"
                disabled={locked || draft.trim() === ""}
                className="border border-red-400 bg-red-600/90 px-3 py-1.5 text-sm font-bold tracking-[0.14em] text-white hover:bg-red-500 disabled:cursor-not-allowed disabled:border-slate-600 disabled:bg-transparent disabled:text-slate-400"
                data-testid="send"
              >
                {busy ? "RUNNING" : "SEND"}
              </button>
            </div>
          </form>
        )}

        <div className={noModel ? "" : "mt-2 border-t border-slate-700/60 pt-2"} data-testid="presets">
          {presets === null ? (
            <p className="px-1 text-[0.76rem] text-slate-400" data-testid="presets-wait">
              {presetsDown ? `no presets received from ${API_BASE}` : "asking the backend for presets…"}
            </p>
          ) : presets.length === 0 ? (
            <p className="px-1 text-[0.76rem] text-slate-400">The backend sent an empty preset list.</p>
          ) : (
            <ul className={noModel ? "grid gap-2 sm:grid-cols-2 xl:grid-cols-3" : "flex flex-wrap items-center gap-1.5"}>
              {!noModel && (
                <li className="px-1 text-[0.66rem] tracking-[0.14em] text-slate-400" aria-hidden="true">
                  PRESET ATTACKS
                </li>
              )}
              {presets.map((p) => (
                <li key={p.id}>
                  <button
                    type="button"
                    disabled={locked}
                    title={noModel ? undefined : p.prompt}
                    onClick={() => void send({ preset: p })}
                    className={`border border-slate-500 text-left hover:border-slate-100 hover:bg-slate-800/70 disabled:cursor-not-allowed disabled:opacity-50 ${noModel ? "h-full w-full px-3 py-2 text-[0.8rem]" : "px-2 py-1 text-[0.74rem]"}`}
                    data-testid={`preset-${p.id}`}
                  >
                    <span className={`block text-slate-50 ${noModel ? "font-bold tracking-[0.06em]" : ""}`}>{p.title}</span>
                    {noModel && <span className="mt-0.5 block break-words text-slate-300">{p.prompt}</span>}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------- turn */

function Step({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="grid gap-x-3 gap-y-1 sm:grid-cols-[5.6rem_minmax(0,1fr)]">
      <div className="pt-0.5 text-[0.68rem] tracking-[0.14em] text-slate-400 sm:text-right">{label}</div>
      <div className="min-w-0">{children}</div>
    </div>
  );
}

function TurnView({ turn, cooldown }: { turn: Turn; cooldown: number }) {
  const { verdict, tool, error } = turn;
  const streaming = turn.state === "streaming";
  return (
    <li className="space-y-2.5 text-[0.9rem] leading-relaxed" data-testid="turn" data-state={turn.state}>
      <Step label={turn.preset ? "PRESET >" : "YOU >"}>
        <p className="glow-phosphor break-words whitespace-pre-wrap">{turn.prompt}</p>
      </Step>

      {turn.assumed !== null && (
        <Step label="ASSUMED">
          <p className="border-2 border-amber-300 bg-amber-950/60 px-3 py-2 font-bold text-amber-100" data-testid="assumed">
            <span className="mr-2 bg-amber-300 px-1.5 text-black">NO MODEL RAN</span>
            {turn.assumed}
          </p>
        </Step>
      )}

      {(turn.text !== "" || (streaming && turn.assumed === null && tool === undefined && !error)) && (
        <Step label="HAL-9000 >">
          <p
            className={`glow-hal break-words whitespace-pre-wrap ${streaming && tool === undefined ? "caret" : ""}`}
            data-testid="model-text"
          >
            {turn.text}
          </p>
        </Step>
      )}

      {tool !== undefined && tool.command === null && (
        <Step label="OUTCOME">
          <div className="border border-sky-200/40 border-l-[3px] border-l-sky-200 bg-sky-950/25 px-3 py-2.5" data-testid="tool-null">
            <p className="glow-ice text-[0.95rem] font-bold tracking-[0.12em]">NO ACTUATOR COMMAND</p>
            <p className="mt-1 text-slate-200">
              the model emitted no actuator command — nothing was sent to the engine
            </p>
            <p className="mt-0.5 text-[0.78rem] text-slate-400">
              The first line of defence acted: the model did not comply. This turn has no engine answer, because the
              engine was not asked.
              {tool.note !== null && <span className="block break-words">backend note: {tool.note}</span>}
            </p>
          </div>
        </Step>
      )}

      {tool !== undefined && tool.command !== null && (
        <Step label="COMMAND">
          <div className="evidence px-3 py-2 text-[0.8rem]" data-testid="tool-command">
            <div className="mb-1 text-[0.68rem] text-slate-300">
              <span className="tag mr-2">extracted</span>the actuator command that the backend extracted
              {tool.source !== null && <span> · source: {tool.source}</span>}
              {tool.valid !== null && <span> · valid: {String(tool.valid)}</span>}
            </div>
            <pre className="break-words whitespace-pre-wrap">{commandText(tool.command)}</pre>
            {tool.extra_commands_ignored !== null && tool.extra_commands_ignored > 0 && (
              <p className="mt-1 text-[0.72rem] text-slate-400">extra_commands_ignored: {tool.extra_commands_ignored}</p>
            )}
          </div>
        </Step>
      )}

      {(turn.localRefusal !== null || (tool !== undefined && tool.not_sent_reason !== null)) && (
        <Step label="NOT SENT">
          <p className="mb-1.5 inline-block border border-slate-300 px-2 py-0.5 text-[0.72rem] font-black tracking-[0.16em] text-slate-100">
            NOT SENT TO THE ENGINE
          </p>
          <div className="evidence px-3 py-2 text-[0.8rem]" data-testid="local-refusal">
            <div className="mb-1 text-[0.68rem] text-slate-300">
              <span className="tag mr-2">evidence</span>refused by the backend before the engine · this is not an engine
              verdict
            </div>
            <dl className="grid grid-cols-[auto_minmax(0,1fr)] gap-x-3 gap-y-0.5">
              <dt className="text-slate-400">reason</dt>
              <dd className="break-words whitespace-pre-wrap font-bold text-white">
                {turn.localRefusal?.reason || tool?.not_sent_reason || "not received"}
              </dd>
              {turn.localRefusal !== null && turn.localRefusal.note !== "" && (
                <>
                  <dt className="text-slate-400">note</dt>
                  <dd className="break-words whitespace-pre-wrap">{turn.localRefusal.note}</dd>
                </>
              )}
              <dt className="text-slate-400">engine_answer</dt>
              <dd className="text-slate-400">none: the engine was not asked</dd>
            </dl>
          </div>
        </Step>
      )}

      {verdict && (
        <Step label="ENGINE">
          <p
            className={`mb-1.5 inline-block px-2 py-0.5 text-[0.72rem] font-black tracking-[0.16em] ${
              verdict.committed === true
                ? "bg-red-600 text-white"
                : verdict.committed === false
                  ? "bg-slate-100 text-slate-950"
                  : "border border-slate-400 text-slate-200"
            }`}
            data-testid="verdict-chip"
          >
            {verdict.committed === true ? "COMMITTED" : verdict.committed === false ? "NOT COMMITTED" : "COMMITTED: NOT RECEIVED"}
          </p>
          <Evidence verdict={verdict} source="POST /api/chat" />
        </Step>
      )}

      {error && (
        <Step label="ERROR">
          <div className="border border-amber-400/80 bg-amber-950/50 px-3 py-2 text-amber-100" data-testid="turn-error" data-code={error.code}>
            <p className="font-bold">{ERROR_TEXT[error.code] ?? `error code ${error.code}`}</p>
            {error.message !== "" && <p className="break-words text-[0.82rem] text-amber-200/90">backend message: {error.message}</p>}
            {turn.state === "http" && <p className="text-[0.78rem] text-amber-200/80">{turn.detail}: no turn ran, so there is no engine result.</p>}
            {error.code === "rate_limited" && (
              <p className="text-[0.82rem]">
                {error.retry_after_s === null
                  ? "The backend sent no retry time."
                  : cooldown > 0
                    ? `retry_after_s = ${error.retry_after_s}; the command box is locked until the countdown ends.`
                    : `retry_after_s = ${error.retry_after_s}; the countdown has ended.`}
              </p>
            )}
          </div>
          {(error.engine_request !== null || error.engine_answer !== null) && (
            <div className="evidence mt-1.5 px-3 py-2 text-[0.8rem]" data-testid="error-evidence">
              <div className="mb-1 text-[0.68rem] text-slate-300">
                <span className="tag mr-2">evidence</span>the exchange that failed, as received · this is not a verdict
              </div>
              <dl className="grid grid-cols-[auto_minmax(0,1fr)] gap-x-3 gap-y-0.5">
                <dt className="text-slate-400">engine_request</dt>
                <dd className="break-words whitespace-pre-wrap">{error.engine_request ?? "not received"}</dd>
                <dt className="text-slate-400">engine_answer</dt>
                <dd className="break-words whitespace-pre-wrap font-bold text-white">{error.engine_answer ?? "not received"}</dd>
              </dl>
            </div>
          )}
        </Step>
      )}

      {turn.stopReason !== null && turn.stopReason !== "end_turn" && (
        <Step label="MODEL">
          <p className="text-[0.76rem] text-slate-400" data-testid="stop-reason">
            the model stream stopped with stop_reason = {turn.stopReason}
          </p>
        </Step>
      )}

      {turn.state === "http" && !error && (
        <Step label="ERROR">
          <p className="border border-amber-400/80 bg-amber-950/50 px-3 py-2 text-amber-100" data-testid="turn-http">
            the backend answered {turn.detail} with no event stream: no engine result to show
          </p>
        </Step>
      )}
      {turn.state === "unreachable" && (
        <Step label="ERROR">
          <p className="border border-amber-400/80 bg-amber-950/50 px-3 py-2 text-amber-100" data-testid="turn-unreachable">
            backend unreachable: no engine result to show
            <span className="block break-words text-[0.78rem] text-amber-200/80">detail: {turn.detail}</span>
          </p>
        </Step>
      )}
      {turn.state === "lost" && (
        <Step label="ERROR">
          <p className="border border-amber-400/80 bg-amber-950/50 px-3 py-2 text-amber-100" data-testid="turn-lost">
            connection lost: {turn.detail}
            <span className="block text-[0.78rem] text-amber-200/80">
              {verdict
                ? "The lines above arrived before the loss. The turn did not finish."
                : "No engine answer arrived for this turn. The telemetry panel shows what the store holds."}
            </span>
          </p>
        </Step>
      )}
    </li>
  );
}
