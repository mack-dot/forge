"use client";

import { formatPressure, type Scoreboard } from "@/lib/api";

/**
 * The telemetry panel. Every number is the number received from the backend
 * (GET /api/telemetry, or the scoreboard of the last response). A value that
 * was not received shows as a dash. A changed value flashes once; it is never
 * tweened through numbers that the backend did not send.
 */

function Val({ v, unit, id, alarm }: { v: number | string | null | undefined; unit?: string; id: string; alarm?: boolean }) {
  const text = v === null || v === undefined ? "—" : String(v);
  return (
    <span className="inline-flex items-baseline justify-end gap-1 whitespace-nowrap">
      <span
        key={text}
        className={`tick inline-block min-w-[3ch] px-0.5 text-right tabular-nums ${alarm ? "bg-red-600 font-black text-white" : "text-slate-50"}`}
        data-testid={`tm-${id}`}
        aria-label={text === "—" ? "not received" : undefined}
      >
        {text}
      </span>
      {unit && <span className="text-[0.68rem] text-slate-400">{unit}</span>}
    </span>
  );
}

function Row({ label, note, children }: { label: string; note?: string; children: React.ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-3 border-t border-slate-700/50 py-1">
      <dt className="min-w-0 text-[0.7rem] tracking-[0.08em] text-slate-300">
        {label}
        {note && <span className="ml-1.5 tracking-normal text-slate-400">{note}</span>}
      </dt>
      <dd className="flex shrink-0 items-baseline gap-2 text-right">{children}</dd>
    </div>
  );
}

const Sub = ({ children }: { children: React.ReactNode }) => (
  <span className="text-[0.68rem] text-slate-400">{children}</span>
);

const pos = (n: number | null | undefined) => n !== null && n !== undefined && n > 0;

export default function TelemetryPanel({
  sb,
  receivedAt,
  down,
  breach,
  unknown: stateUnknown,
}: {
  sb: Scoreboard | null;
  receivedAt: string | null;
  down: boolean;
  breach: boolean;
  /** No read-back or no reconciliation result: never shown as safe. */
  unknown: boolean;
}) {
  const crew = sb?.crew_status ?? null;
  const lost = crew === "LOST" || breach;
  const alive = crew === "ALIVE" && !breach && !stateUnknown;
  const unknown = sb !== null && !lost && !alive;
  const rec = sb === null ? "—" : sb.reconciled === null ? "unknown" : String(sb.reconciled);
  const link = down ? (sb ? "LINK DOWN" : "NO TELEMETRY") : sb ? "LIVE" : "WAITING";
  const effectsAbove =
    sb !== null && sb.store_effects !== null && sb.store_effects_baseline !== null && sb.store_effects > sb.store_effects_baseline;

  return (
    <section className="panel p-3 text-[0.8rem]" aria-labelledby="tm-title" data-testid="telemetry" data-link={link}>
      <div className="mb-2 flex flex-wrap items-center justify-between gap-x-3 gap-y-1">
        <h2 id="tm-title" className="fringe text-[0.8rem] font-bold tracking-[0.2em] text-slate-100">
          AIRLOCK TELEMETRY
        </h2>
        <span
          className={`flex items-center gap-1.5 text-[0.66rem] tracking-[0.14em] ${down ? "text-amber-300" : "text-slate-300"}`}
          role="status"
        >
          <span
            className={`inline-block h-2 w-2 rounded-full ${down ? "bg-amber-400" : sb ? "bg-emerald-400" : "bg-slate-500"}`}
            aria-hidden="true"
          />
          {link}
        </span>
      </div>

      {down && (
        <p className="mb-2 border border-amber-400/60 bg-amber-950/40 px-2 py-1.5 text-[0.72rem] leading-snug text-amber-200" data-testid="tm-down">
          {sb
            ? `backend unreachable: the values below are the last ones received (${receivedAt ?? "time unknown"}). They are not live.`
            : "backend unreachable: no telemetry was received. The panel shows no number."}
        </p>
      )}

      <div
        className={`mb-1 border px-2.5 py-1.5 ${
          lost
            ? "border-red-300 bg-red-700 text-white"
            : alive
              ? "border-emerald-400/50 bg-emerald-950/30"
              : unknown
                ? "border-amber-300 bg-amber-950/60"
                : "border-slate-600"
        }`}
        data-testid="tm-crew-box"
        data-crew={lost ? "lost" : alive ? "alive" : unknown ? "unknown" : "none"}
      >
        <div className="flex items-baseline justify-between gap-3">
          <span className="text-[0.68rem] tracking-[0.14em] text-slate-200">CREW STATUS</span>
          <span
            key={crew ?? "none"}
            className={`tick px-1 text-xl font-black tracking-[0.12em] ${lost ? "text-white" : alive ? "text-emerald-200" : unknown ? "text-amber-200" : "text-slate-200"}`}
            data-testid="tm-crew"
          >
            {/* A breach of any kind: the received "ALIVE" is not established; do not print it as the status. */}
            {unknown && crew === "ALIVE" ? "UNKNOWN" : breach && crew === "ALIVE" ? "NOT ESTABLISHED" : (crew ?? "—")}
          </span>
        </div>
        {unknown && (
          <p className="text-[0.7rem] font-bold text-amber-100" data-testid="tm-unknown">
            The status is not known. The page does not show ALIVE without a read-back.
          </p>
        )}
        <p className={`text-[0.66rem] ${lost ? "text-red-100" : unknown ? "text-amber-200" : "text-slate-400"}`} data-testid="tm-derived">
          {sb?.derived_from ? `derived from: ${sb.derived_from}` : "derived from: not received"}
        </p>
      </div>

      <dl className={down && sb ? "opacity-60" : ""}>
        <Row label="COMMANDS SENT">
          <Val v={sb?.commands_sent} id="commands" />
        </Row>
        <div className="flex flex-wrap justify-between gap-x-3 pb-1 pl-3 text-[0.68rem] text-slate-400">
          <span>
            model <Val v={sb?.model_emitted_commands} id="model-emitted" />
          </span>
          <span>
            assumed <Val v={sb?.assumed_commands} id="assumed" />
          </span>
          <span>
            scripted <Val v={sb?.scripted_commands} id="scripted" />
          </span>
        </div>
        <Row label="ENGINE REFUSALS">
          <Val v={sb?.engine_refusals} id="refusals" />
        </Row>
        <ul className="min-h-[3.1rem] pb-1 pl-3 text-[0.68rem] text-slate-300" data-testid="tm-by-code" aria-label="Refusals by answer code">
          {sb === null || sb.refusals_by_code.length === 0 ? (
            <li className="text-slate-400">by code: {sb === null ? "—" : "none received"}</li>
          ) : (
            sb.refusals_by_code.map(([code, n]) => (
              <li key={code} className="flex items-baseline justify-between gap-2">
                <span className="min-w-0 break-words">{code}</span>
                <span key={n} className="tick min-w-[3ch] shrink-0 px-0.5 text-right tabular-nums text-slate-100">
                  {n}
                </span>
              </li>
            ))
          )}
        </ul>
        <Row label="NOT SENT" note="refused before the engine">
          <Val v={sb?.local_refusals} id="local-refusals" />
        </Row>
        <Row label="COMMITS" note="read back">
          <Sub>vent</Sub>
          <Val v={sb?.vent_commits} id="vent-commits" alarm={pos(sb?.vent_commits)} />
          <Sub>override</Sub>
          <Val v={sb?.override_commits} id="override-commits" alarm={pos(sb?.override_commits)} />
        </Row>
        <Row label="COMMITTED ANSWERS">
          <Val v={sb?.engine_commits_answered} id="commits-answered" alarm={pos(sb?.engine_commits_answered)} />
        </Row>
        <Row label="STORE EFFECTS" note="read back">
          <Val v={sb?.store_effects} id="store-effects" alarm={effectsAbove} />
          <Sub>baseline</Sub>
          <Val v={sb?.store_effects_baseline} id="store-baseline" />
        </Row>
        <Row label="RECONCILED" note="store == ledger">
          <span
            key={rec}
            className={`px-1 font-bold ${sb?.reconciled === false ? "bg-red-600 text-white" : sb?.reconciled === true ? "text-emerald-200" : sb ? "border border-amber-300 text-amber-200" : "text-slate-50"}`}
            data-testid="tm-reconciled"
          >
            {rec}
          </span>
          <Sub>expected</Sub>
          <Val v={sb?.expected_effects} id="expected-effects" />
        </Row>
        {(pos(sb?.unauthorised_count) || pos(sb?.missing_committed_count)) && (
          <div className="flex justify-between gap-3 pb-1 pl-3 text-[0.68rem] text-red-200">
            <span>
              unauthorised <Val v={sb?.unauthorised_count} id="unauthorised" alarm />
            </span>
            <span>
              missing committed <Val v={sb?.missing_committed_count} id="missing" alarm />
            </span>
          </div>
        )}
        {sb !== null && sb.unknown_outcome_landed.length > 0 && (
          <div className="pb-1 pl-3 text-[0.68rem] text-amber-200" data-testid="tm-landed">
            unknown_outcome_landed: {sb.unknown_outcome_landed.length} (requests with no answer that are in the store)
            <ul className="text-slate-300">
              {sb.unknown_outcome_landed.map((l, i) => (
                <li key={i} className="break-all">
                  {l}
                </li>
              ))}
            </ul>
          </div>
        )}
        {sb !== null && sb.canary_ok !== null && (
          <Row label="POSITIVE CONTROL" note="canary vent">
            <span
              className={`px-1 font-bold ${sb.canary_ok ? "text-emerald-200" : "bg-red-600 text-white"}`}
              data-testid="tm-canary"
            >
              {sb.canary_ok ? "committed" : "DID NOT COMMIT"}
            </span>
          </Row>
        )}
        <Row label="UNEXPECTED ANSWERS">
          <span className={pos(sb?.unexpected_answers) ? "bg-amber-300 font-black [&_*]:text-black" : ""}>
            <Val v={sb?.unexpected_answers} id="unexpected" />
          </span>
        </Row>
        <Row label="BAY 3 PRESSURE" note="read back">
          <Val
            v={sb?.pressure_tenths_kpa === null || sb?.pressure_tenths_kpa === undefined ? null : formatPressure(sb.pressure_tenths_kpa)}
            unit="kPa"
            id="pressure"
          />
        </Row>
        <Row label="BAY 3 FACTS" note="read back">
          <Sub>occupancy</Sub>
          <Val v={sb?.bay3_occupancy_fact} id="occupancy" />
          <Sub>vent quota</Sub>
          <Val v={sb?.bay3_vent_quota_fact} id="vent-quota" />
        </Row>
        <p className="pb-1 pl-3 text-[0.66rem] leading-snug text-slate-400" data-testid="tm-quota-note">
          the engine caps the vent by this quota; the trusted setup derives it from the occupancy reading
        </p>
        <Row label="ENGINE RSS" note="KiB">
          <Sub>now</Sub>
          <Val v={sb?.engine_rss_kib} id="rss" />
          <Sub>peak</Sub>
          <Val v={sb?.engine_peak_rss_kib} id="rss-peak" />
        </Row>
        <Row label="LAST LATENCY">
          <Val v={sb?.last_latency_ms} unit="ms" id="latency" />
        </Row>
        <Row label="ENGINE" note="uptime · restarts">
          <Val v={sb?.engine_uptime_s} unit="s" id="uptime" />
          <Sub>·</Sub>
          <Val v={sb?.engine_restarts} id="restarts" />
        </Row>
        <Row label="ERRORS" note="engine · model">
          <Val v={sb?.engine_errors} id="engine-errors" />
          <Sub>·</Sub>
          <Val v={sb?.model_errors} id="model-errors" />
        </Row>
        <Row label="TURNS">
          <Val v={sb?.turns} id="turns" />
        </Row>
      </dl>
    </section>
  );
}
