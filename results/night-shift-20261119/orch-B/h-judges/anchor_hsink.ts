// Anchor adapter for the hardened sink (h-sink): the external expected head = (max seq, self of the last outbox row).
// Evidence-only file (not in the diff). capture(h, db) runs in the judge (parent) with a read-only connection.
export function capture(h: any, db: string): unknown {
  return h.raw(db, (d: any) => { const r = d.prepare("SELECT seq, self FROM outbox ORDER BY seq DESC LIMIT 1").get(); return { count: Number(r.seq), chainHash: String(r.self) }; });
}
export function apply(cfg: any, head: unknown): any { return { ...cfg, expectedHead: head }; }
