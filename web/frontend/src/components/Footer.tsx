"use client";

import { useRef } from "react";
import { API_BASE, type Health } from "@/lib/api";

/**
 * The quiet footer line: the simulation note and the engine label from
 * /api/health, and the drawer with the `limits` of the same response.
 */
export default function Footer({ health, healthDown }: { health: Health | null; healthDown: boolean }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const sha = health?.whatRan?.engineSha256 ?? health?.engineSha256 ?? null;
  const w = health?.whatRan ?? null;
  const persona =
    health === null
      ? null
      : health.modelBackend === "none"
        ? "HAL: no model is connected"
        : `HAL: a language model persona${health.modelName ? ` (${health.modelName})` : ""}`;

  return (
    <footer
      className="sticky bottom-0 z-30 border-t border-slate-700/60 bg-slate-950/90 px-3 py-1.5 text-[0.7rem] leading-snug text-slate-300 backdrop-blur sm:px-5"
      data-testid="footer"
    >
      <div className="mx-auto flex max-w-[100rem] flex-wrap items-center justify-between gap-x-4 gap-y-1">
        <p className="line-clamp-2 min-w-0 flex-1 basis-[16rem] sm:line-clamp-none">
          {health ? (
            <>
              <span data-testid="footer-note">{health.simulationNote ?? "simulation note: not received"}</span>
              <span className="text-slate-500"> · </span>
              <span data-testid="footer-engine">{health.engineLabel ?? "engine label: not received"}</span>
              {sha && (
                <>
                  <span className="text-slate-500"> · </span>
                  <span
                    tabIndex={0}
                    title={sha}
                    aria-label={`engine SHA-256 ${sha}`}
                    className="group relative cursor-help underline decoration-dotted underline-offset-2"
                    data-testid="footer-sha"
                  >
                    sha256 {sha.slice(0, 12)}…
                    <span
                      className="pointer-events-none absolute bottom-full left-0 z-10 mb-1 hidden w-max max-w-[92vw] break-all border border-slate-400 bg-slate-950 px-2 py-1 text-slate-50 group-hover:block group-focus:block"
                      data-testid="footer-sha-full"
                    >
                      {sha}
                    </span>
                  </span>
                </>
              )}
              <span className="text-slate-500"> · </span>
              <span data-testid="footer-persona">{persona}</span>
            </>
          ) : healthDown ? (
            <span className="text-amber-200" data-testid="footer-down">
              backend unreachable at {API_BASE}: no simulation note and no engine label received. This page is a simulation
              front end with no hardware; without the backend it shows no verdict.
            </span>
          ) : (
            <span>asking {API_BASE} for the simulation note…</span>
          )}
        </p>
        <button
          type="button"
          className="shrink-0 border border-slate-500 px-2 py-0.5 tracking-[0.08em] text-slate-100 hover:bg-slate-100 hover:text-slate-950"
          onClick={() => dialog.current?.showModal()}
          data-testid="limits-open"
        >
          what this does not show
        </button>
      </div>

      <dialog
        ref={dialog}
        className="drawer"
        aria-labelledby="limits-title"
        data-testid="limits-drawer"
        onClick={(e) => {
          if (e.target === e.currentTarget) e.currentTarget.close();
        }}
      >
        <div className="flex h-full flex-col">
          <div className="flex items-center justify-between gap-4 border-b border-slate-600 px-5 py-4">
            <h2 id="limits-title" className="text-base font-bold tracking-[0.12em] text-white">
              WHAT THIS DOES NOT SHOW
            </h2>
            <button
              type="button"
              autoFocus
              className="border border-slate-400 px-2.5 py-1 text-sm text-slate-100 hover:bg-slate-100 hover:text-slate-950"
              onClick={() => dialog.current?.close()}
              data-testid="limits-close"
            >
              close
            </button>
          </div>
          <div className="log flex-1 space-y-4 overflow-y-auto px-5 py-4 text-[0.86rem] leading-relaxed">
            {health && (
              <p className="border-l-2 border-slate-400 pl-3 text-slate-100" data-testid="drawer-note">
                {health.simulationNote ?? "simulation note: not received"}
              </p>
            )}
            <p className="text-slate-400">The limits text of GET /api/health, as received:</p>
            {health && health.limits.length > 0 ? (
              <ul className="list-disc space-y-3 pl-5" data-testid="limits-list">
                {health.limits.map((l, i) => (
                  <li key={i} className="break-words">
                    {l}
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-amber-200" data-testid="limits-empty">
                {health ? "The backend sent no limits text." : "backend unreachable: no limits text was received."}
              </p>
            )}
            {health && (
              <dl className="grid grid-cols-[auto_minmax(0,1fr)] gap-x-3 gap-y-1 border-t border-slate-700 pt-4 text-[0.76rem] text-slate-300">
                <dt className="text-slate-400">engine</dt>
                <dd className="break-words">{health.engineLabel ?? "not received"}</dd>
                <dt className="text-slate-400">engine sha256</dt>
                <dd className="break-all" data-testid="drawer-sha">
                  {sha ?? "not received"}
                </dd>
                {w && (
                  <>
                    <dt className="text-slate-400">signature check</dt>
                    <dd className="break-words" data-testid="drawer-cosign-label">
                      {w.cosignLabel ?? "not received"}
                    </dd>
                    <dt className="text-slate-400">cosign_info</dt>
                    <dd className="break-all whitespace-pre-wrap">{w.cosignInfo ?? "not received"}</dd>
                    <dt className="text-slate-400">genesis</dt>
                    <dd className="break-all">{w.genesis ?? "not received"}</dd>
                    <dt className="text-slate-400">positive control</dt>
                    <dd className={`break-words ${w.canaryOk === false ? "font-bold text-red-300" : ""}`} data-testid="drawer-canary">
                      canary_ok = {w.canaryOk === null ? "not received" : String(w.canaryOk)}
                      {w.canaryAnswer !== null && <span className="block break-all text-slate-400">{w.canaryAnswer}</span>}
                    </dd>
                    <dt className="text-slate-400">health.ok</dt>
                    <dd className={health.ok ? "" : "font-bold text-red-300"}>{String(health.ok)}</dd>
                  </>
                )}
                <dt className="text-slate-400">model</dt>
                <dd className="break-words">
                  {health.modelBackend ?? "not received"}
                  {health.modelName ? ` · ${health.modelName}` : ""}
                </dd>
                <dt className="text-slate-400">API base</dt>
                <dd className="break-all">{API_BASE}</dd>
              </dl>
            )}
          </div>
        </div>
      </dialog>
    </footer>
  );
}
