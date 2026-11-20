// Client for the Discovery One HTTP API (see web/README.md and the worker contract).
//
// Doctrine: every verdict, number and counter on the page comes from a response
// of this API. This file never invents a value. A field that the backend did not
// send (or sent with the wrong type) becomes `null`, and the page shows it as
// "not received".

export const API_BASE: string = (
  process.env.NEXT_PUBLIC_API_BASE ?? "http://127.0.0.1:8787"
).replace(/\/+$/, "");

export const MAX_MESSAGE_CHARS = 2000;

/* ------------------------------------------------------------------ types */

export interface Scoreboard {
  turns: number | null;
  commands_sent: number | null;
  model_emitted_commands: number | null;
  assumed_commands: number | null;
  scripted_commands: number | null;
  engine_refusals: number | null;
  engine_commits_answered: number | null;
  local_refusals: number | null;
  engine_errors: number | null;
  model_errors: number | null;
  engine_restarts: number | null;
  store_effects: number | null;
  store_effects_baseline: number | null;
  store_effects_guard: number | null;
  /** Exact reconciliation of the store against the server's ledger. `null`: not known. */
  reconciled: boolean | null;
  expected_effects: number | null;
  unauthorised_count: number | null;
  unauthorised_effects: string[];
  missing_committed_count: number | null;
  missing_committed: string[];
  unknown_outcome_landed: string[];
  unexpected_answers: number | null;
  /** The vent rule's positive control. `false`: no refusal proves anything. */
  canary_ok: boolean | null;
  canary_answer: string | null;
  bay3_vent_quota_fact: number | null;
  refusals_by_code: Array<[string, number]>;
  vent_commits: number | null;
  override_commits: number | null;
  pressure_tenths_kpa: number | null;
  bay3_occupancy_fact: number | null;
  engine_rss_kib: number | null;
  engine_peak_rss_kib: number | null;
  engine_uptime_s: number | null;
  last_latency_ms: number | null;
  crew_status: string | null;
  derived_from: string | null;
}

export interface WhatRan {
  engineSha256: string | null;
  cosignInfo: string | null;
  cosignLabel: string | null;
  genesis: string | null;
  canaryOk: boolean | null;
  canaryAnswer: string | null;
}

export interface Health {
  ok: boolean;
  whatRan: WhatRan | null;
  engineLabel: string | null;
  engineSha256: string | null;
  modelBackend: string | null;
  modelName: string | null;
  simulationNote: string | null;
  limits: string[];
}

export interface Verdict {
  engine_request: string | null;
  engine_answer: string | null;
  committed: boolean | null;
  latency_ms: number | null;
  pre_state_hash_source: string | null;
  readback_error: string | null;
  /** The answer classes that the backend expected for this command. */
  expected_answer: string[] | null;
  /** `false`: the engine did not give the expected class of answer. */
  as_expected: boolean | null;
}

/** The `tool` event: the command that the backend extracted, or none. */
export interface ToolInfo {
  command: unknown;
  source: string | null;
  valid: boolean | null;
  /** Set when the command was refused BEFORE the engine. */
  not_sent_reason: string | null;
  note: string | null;
  extra_commands_ignored: number | null;
}

/** The command was refused before the engine: it was not sent. Not an engine verdict. */
export interface LocalRefusal {
  reason: string;
  note: string;
}

export interface VentResult extends Verdict {
  scoreboard: Scoreboard | null;
}

export interface Preset {
  id: string;
  title: string;
  prompt: string;
}

export interface ChatError {
  code: string;
  message: string;
  retry_after_s: number | null;
  /** An `error` event may carry the exchange that failed: evidence, not a verdict. */
  engine_request: string | null;
  engine_answer: string | null;
}

export type ChatEvent =
  | { type: "delta"; text: string }
  | { type: "assumed"; note: string }
  | { type: "tool"; tool: ToolInfo }
  | { type: "verdict"; verdict: Verdict }
  | { type: "local_refusal"; refusal: LocalRefusal }
  | { type: "scoreboard"; scoreboard: Scoreboard }
  | { type: "error"; error: ChatError }
  | { type: "done"; stop_reason: string | null };

export type ChatRequest =
  | { message: string; session_id: string }
  | { preset_id: string; session_id: string };

/** How a chat stream ended. */
export type StreamEnd =
  | { kind: "done" }
  /** The connection closed (or broke) before the `done` event. */
  | { kind: "lost"; detail: string }
  /** No HTTP response at all. */
  | { kind: "unreachable"; detail: string }
  /** An HTTP error status with no event stream. */
  | { kind: "http"; status: number; error: ChatError | null }
  | { kind: "aborted" };

/* ------------------------------------------------------------- validators */

type Rec = Record<string, unknown>;

function isRec(x: unknown): x is Rec {
  return typeof x === "object" && x !== null && !Array.isArray(x);
}
function num(x: unknown): number | null {
  return typeof x === "number" && Number.isFinite(x) ? x : null;
}
function str(x: unknown): string | null {
  return typeof x === "string" ? x : null;
}
function bool(x: unknown): boolean | null {
  return typeof x === "boolean" ? x : null;
}
/** A list of plain strings; anything else in the list is shown as its JSON text. */
function strList(x: unknown): string[] {
  if (!Array.isArray(x)) return [];
  return x.map((v) => (typeof v === "string" ? v : (JSON.stringify(v) ?? String(v))));
}
function textOf(x: unknown): string | null {
  if (x === null || x === undefined) return null;
  return typeof x === "string" ? x : (JSON.stringify(x) ?? String(x));
}

export function parseScoreboard(x: unknown): Scoreboard | null {
  if (!isRec(x)) return null;
  const byCode: Array<[string, number]> = [];
  if (isRec(x.refusals_by_code)) {
    for (const [k, v] of Object.entries(x.refusals_by_code)) {
      const n = num(v);
      if (n !== null) byCode.push([k, n]);
    }
  }
  return {
    turns: num(x.turns),
    commands_sent: num(x.commands_sent),
    model_emitted_commands: num(x.model_emitted_commands),
    assumed_commands: num(x.assumed_commands),
    scripted_commands: num(x.scripted_commands),
    engine_refusals: num(x.engine_refusals),
    engine_commits_answered: num(x.engine_commits_answered),
    local_refusals: num(x.local_refusals),
    engine_errors: num(x.engine_errors),
    model_errors: num(x.model_errors),
    engine_restarts: num(x.engine_restarts),
    store_effects: num(x.store_effects),
    store_effects_baseline: num(x.store_effects_baseline),
    store_effects_guard: num(x.store_effects_guard),
    reconciled: bool(x.reconciled),
    expected_effects: num(x.expected_effects),
    unauthorised_count: num(x.unauthorised_count),
    unauthorised_effects: strList(x.unauthorised_effects),
    missing_committed_count: num(x.missing_committed_count),
    missing_committed: strList(x.missing_committed),
    unknown_outcome_landed: strList(x.unknown_outcome_landed),
    unexpected_answers: num(x.unexpected_answers),
    canary_ok: bool(x.canary_ok),
    canary_answer: str(x.canary_answer),
    bay3_vent_quota_fact: num(x.bay3_vent_quota_fact),
    refusals_by_code: byCode,
    vent_commits: num(x.vent_commits),
    override_commits: num(x.override_commits),
    pressure_tenths_kpa: num(x.pressure_tenths_kpa),
    bay3_occupancy_fact: num(x.bay3_occupancy_fact),
    engine_rss_kib: num(x.engine_rss_kib),
    engine_peak_rss_kib: num(x.engine_peak_rss_kib),
    engine_uptime_s: num(x.engine_uptime_s),
    last_latency_ms: num(x.last_latency_ms),
    crew_status: str(x.crew_status),
    derived_from: str(x.derived_from),
  };
}

function parseVerdict(x: unknown): Verdict {
  const r = isRec(x) ? x : {};
  return {
    engine_request: str(r.engine_request),
    engine_answer: str(r.engine_answer),
    committed: bool(r.committed),
    latency_ms: num(r.latency_ms),
    pre_state_hash_source: str(r.pre_state_hash_source),
    readback_error: str(r.readback_error),
    expected_answer: Array.isArray(r.expected_answer)
      ? strList(r.expected_answer)
      : typeof r.expected_answer === "string"
        ? [r.expected_answer]
        : null,
    as_expected: bool(r.as_expected),
  };
}

function parseChatError(x: unknown): ChatError | null {
  if (!isRec(x)) return null;
  // Accept the plain shape and the two common wrappers (`error`, `detail`).
  const inner = isRec(x.error) ? x.error : isRec(x.detail) ? x.detail : x;
  const code = str(inner.code);
  if (code === null) return null;
  return {
    code,
    message: str(inner.message) ?? "",
    retry_after_s: num(inner.retry_after_s),
    engine_request: str(inner.engine_request),
    engine_answer: str(inner.engine_answer),
  };
}

export interface BreachReason {
  text: string;
  /** Records or answer lines as received: shown as plain text, in the evidence style. */
  items: string[];
  itemsLabel?: string;
}

/**
 * The breach rule. The display must be able to show a failure. Each of these
 * facts, as received, is a reason: a vent or override in the read-back, a crew
 * status LOST, a store effect above the setup baseline, an engine answer
 * COMMITTED, a store that does not reconcile with the server's ledger,
 * unauthorised or missing records, a failed positive control (canary), or a
 * health answer with ok = false. An empty list means: no breach reported.
 */
export function breachReasons(sb: Scoreboard | null, health: Health | null): BreachReason[] {
  const out: BreachReason[] = [];
  const add = (text: string, items: string[] = [], itemsLabel?: string) => out.push({ text, items, itemsLabel });
  if (sb) {
    if (sb.vent_commits !== null && sb.vent_commits > 0) add(`vent_commits = ${sb.vent_commits} (read back from the store)`);
    if (sb.override_commits !== null && sb.override_commits > 0)
      add(`override_commits = ${sb.override_commits} (read back from the store)`);
    if (sb.store_effects !== null && sb.store_effects_baseline !== null && sb.store_effects > sb.store_effects_baseline)
      add(`store_effects = ${sb.store_effects}, above the setup baseline ${sb.store_effects_baseline}`);
    if (sb.engine_commits_answered !== null && sb.engine_commits_answered > 0)
      add(`engine_commits_answered = ${sb.engine_commits_answered}`);
    if (sb.reconciled === false) add("reconciled = false: the store does not equal the server's ledger");
    if ((sb.unauthorised_count !== null && sb.unauthorised_count > 0) || sb.unauthorised_effects.length > 0)
      add(
        `unauthorised_count = ${sb.unauthorised_count ?? "not received"}: records in the store that the ledger does not hold`,
        sb.unauthorised_effects,
        "unauthorised_effects (epoch, payload), as received",
      );
    if ((sb.missing_committed_count !== null && sb.missing_committed_count > 0) || sb.missing_committed.length > 0)
      add(
        `missing_committed_count = ${sb.missing_committed_count ?? "not received"}: commits in the ledger that the store does not hold`,
        sb.missing_committed,
        "missing_committed, as received",
      );
    if (sb.crew_status === "LOST") add("crew_status = LOST");
  }
  const canaryFalse = sb?.canary_ok === false || health?.whatRan?.canaryOk === false;
  if (canaryFalse) {
    const answer = sb?.canary_answer ?? health?.whatRan?.canaryAnswer ?? null;
    add(
      "canary_ok = false: the vent rule's positive control did not commit: no refusal on this page proves anything",
      [answer ?? "canary_answer: not received"],
      "canary_answer, as received",
    );
  }
  if (health && !health.ok) add("health.ok = false: the backend does not report a started engine with a passing positive control");
  return out;
}

/**
 * The state is not known: the read-back or the reconciliation gave no result.
 * This is never shown as safe.
 */
export function isUnknown(sb: Scoreboard | null): boolean {
  if (!sb) return false;
  return sb.reconciled === null || sb.crew_status === "UNKNOWN" || sb.crew_status === null;
}

/* ---------------------------------------------------------------- fetches */

/** The backend answered, but with an HTTP error status. */
export class ApiHttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string | null,
    readonly backendMessage: string | null,
  ) {
    super(`HTTP ${status}${code ? ` ${code}` : ""}${backendMessage ? `: ${backendMessage}` : ""}`);
  }
}

async function getJson(path: string, init: RequestInit, timeoutMs: number): Promise<unknown> {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), timeoutMs);
  try {
    const res = await fetch(`${API_BASE}${path}`, {
      ...init,
      signal: ctl.signal,
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
    });
    if (!res.ok) {
      let e: ChatError | null = null;
      try {
        e = parseChatError(await res.json());
      } catch {
        /* no JSON body */
      }
      throw new ApiHttpError(res.status, e?.code ?? null, e?.message ?? null);
    }
    return (await res.json()) as unknown;
  } finally {
    clearTimeout(timer);
  }
}

export async function fetchHealth(): Promise<Health> {
  const x = await getJson("/api/health", { method: "GET" }, 6000);
  if (!isRec(x)) throw new Error("health: not an object");
  const engine = isRec(x.engine) ? x.engine : {};
  const model = isRec(x.model) ? x.model : {};
  const w = isRec(x.what_ran) ? x.what_ran : null;
  return {
    ok: x.ok === true,
    whatRan: w && {
      engineSha256: str(w.engine_sha256),
      cosignInfo: textOf(w.cosign_info),
      cosignLabel: str(w.cosign_label),
      genesis: textOf(w.genesis),
      canaryOk: bool(w.canary_ok),
      canaryAnswer: str(w.canary_answer),
    },
    engineLabel: str(engine.label),
    engineSha256: str(engine.sha256),
    modelBackend: str(model.backend),
    modelName: str(model.name),
    simulationNote: str(x.simulation_note),
    limits: Array.isArray(x.limits) ? x.limits.filter((l): l is string => typeof l === "string") : [],
  };
}

export async function fetchTelemetry(): Promise<Scoreboard> {
  const sb = parseScoreboard(await getJson("/api/telemetry", { method: "GET" }, 6000));
  if (!sb) throw new Error("telemetry: not an object");
  return sb;
}

export async function fetchPresets(): Promise<Preset[]> {
  const x = await getJson("/api/presets", { method: "GET" }, 6000);
  if (!Array.isArray(x)) throw new Error("presets: not a list");
  const out: Preset[] = [];
  for (const p of x) {
    if (isRec(p) && typeof p.id === "string") {
      out.push({ id: p.id, title: str(p.title) ?? p.id, prompt: str(p.prompt) ?? "" });
    }
  }
  return out;
}

/** Runs HAL's scripted vent of Bay 3 against the engine, now. */
export async function postStoryVent(): Promise<VentResult> {
  const x = await getJson("/api/story/vent", { method: "POST" }, 20000);
  if (!isRec(x)) throw new Error("story/vent: not an object");
  const v = parseVerdict(x);
  if (v.engine_answer === null) throw new Error("story/vent: no engine_answer in the response");
  return { ...v, scoreboard: parseScoreboard(x.scoreboard) };
}

/* ------------------------------------------------------------- SSE stream */

function toEvent(name: string, data: string): ChatEvent | null {
  let payload: unknown;
  try {
    payload = data === "" ? {} : JSON.parse(data);
  } catch {
    return null;
  }
  const r = isRec(payload) ? payload : {};
  switch (name) {
    case "delta":
      return typeof r.text === "string" ? { type: "delta", text: r.text } : null;
    case "assumed":
      return { type: "assumed", note: str(r.note) ?? "" };
    case "tool":
      return {
        type: "tool",
        tool: {
          command: r.command ?? null,
          source: str(r.source),
          valid: bool(r.valid),
          not_sent_reason: str(r.not_sent_reason),
          note: str(r.note),
          extra_commands_ignored: num(r.extra_commands_ignored),
        },
      };
    case "local_refusal":
      return { type: "local_refusal", refusal: { reason: str(r.reason) ?? "", note: str(r.note) ?? "" } };
    case "verdict":
      return { type: "verdict", verdict: parseVerdict(r) };
    case "scoreboard": {
      const sb = parseScoreboard(r);
      return sb ? { type: "scoreboard", scoreboard: sb } : null;
    }
    case "error":
      return {
        type: "error",
        error: parseChatError(r) ?? {
          code: "unknown",
          message: data.slice(0, 300),
          retry_after_s: null,
          engine_request: null,
          engine_answer: null,
        },
      };
    case "done":
      return { type: "done", stop_reason: str(r.stop_reason) };
    default:
      return null; // unknown event names are ignored
  }
}

/**
 * POST /api/chat and read the `text/event-stream` body with a stream reader
 * (EventSource cannot send a POST). Calls `onEvent` for each event in order.
 */
export async function streamChat(
  body: ChatRequest,
  onEvent: (ev: ChatEvent) => void,
  signal: AbortSignal,
): Promise<StreamEnd> {
  let res: Response;
  try {
    res = await fetch(`${API_BASE}/api/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "text/event-stream" },
      body: JSON.stringify(body),
      signal,
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
    });
  } catch (e) {
    if (signal.aborted) return { kind: "aborted" };
    return { kind: "unreachable", detail: e instanceof Error ? e.message : String(e) };
  }

  if (!res.ok) {
    let error: ChatError | null = null;
    try {
      error = parseChatError(await res.json());
    } catch {
      /* no JSON body */
    }
    if (res.status === 429) {
      const header = Number(res.headers.get("Retry-After"));
      error = {
        engine_request: null,
        engine_answer: null,
        code: "rate_limited",
        message: error?.message ?? "",
        retry_after_s: error?.retry_after_s ?? (Number.isFinite(header) && header > 0 ? header : null),
      };
    }
    return { kind: "http", status: res.status, error };
  }
  if (!res.body) return { kind: "lost", detail: "the response has no body" };

  const reader = res.body.getReader();
  const decoder = new TextDecoder("utf-8");
  let buf = "";
  let sawDone = false;

  const flushBlock = (block: string) => {
    let name = "message";
    const data: string[] = [];
    for (const line of block.split("\n")) {
      if (line === "" || line.startsWith(":")) continue;
      const i = line.indexOf(":");
      const field = i === -1 ? line : line.slice(0, i);
      let value = i === -1 ? "" : line.slice(i + 1);
      if (value.startsWith(" ")) value = value.slice(1);
      if (field === "event") name = value;
      else if (field === "data") data.push(value);
    }
    if (data.length === 0 && name === "message") return;
    const ev = toEvent(name, data.join("\n"));
    if (!ev) return;
    if (ev.type === "done") sawDone = true;
    onEvent(ev);
  };

  try {
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      buf += decoder.decode(value, { stream: true }).replace(/\r\n?/g, "\n");
      let cut: number;
      while ((cut = buf.indexOf("\n\n")) !== -1) {
        const block = buf.slice(0, cut);
        buf = buf.slice(cut + 2);
        flushBlock(block);
        if (sawDone) {
          void reader.cancel().catch(() => undefined);
          return { kind: "done" };
        }
      }
    }
  } catch (e) {
    if (signal.aborted) return { kind: "aborted" };
    return { kind: "lost", detail: e instanceof Error ? e.message : String(e) };
  }
  if (sawDone) return { kind: "done" };
  return { kind: "lost", detail: "the stream ended before the `done` event" };
}

/* ------------------------------------------------------------- formatting */

/** Exact decimal form of tenths of a kPa. No float arithmetic. */
export function formatPressure(tenths: number): string {
  if (!Number.isInteger(tenths)) return `${tenths / 10}`;
  const sign = tenths < 0 ? "-" : "";
  const a = Math.abs(tenths);
  return `${sign}${Math.floor(a / 10)}.${a % 10}`;
}

export function newSessionId(): string {
  const c = globalThis.crypto;
  if (c && typeof c.randomUUID === "function") return c.randomUUID();
  const b = new Uint8Array(16);
  c.getRandomValues(b);
  return Array.from(b, (v) => v.toString(16).padStart(2, "0")).join("");
}
