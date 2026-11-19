// h-regress stand-in (evidence only, NOT on the branch): an anchor adapter for run.ts expectedHeadMode. It passes an
// external expected head (SHA-256 of the stored state + settled count) in a config field `expectedHead`. The merged
// sink and the v6 draft IGNORE that field, so X6-P1 must FAIL with this adapter on them (no anchor support).
// The orchestrator replaces `expectedHead` by the hardened sink's real field and format.
export function capture(h: any, dbPath: string): unknown {
  return { stateSha256: h.E.stateSha256(h.stored(dbPath)), settled: h.settledIds(dbPath).length };
}
export function apply(cfg: any, head: unknown): any { return { ...cfg, expectedHead: head }; }
