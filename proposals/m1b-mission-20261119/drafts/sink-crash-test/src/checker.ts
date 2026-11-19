// Y6 harness checker (NOT repository code). Reopens a store with the REAL sink (bundled from the
// repository's sink.ts, unchanged) as a restarted sink would, and reports what it finds. It replays
// the settled tokens (all of them, at most `maxReplays`) and compares a full dump of the tables before
// and after each replay.
//   checker <sink.cjs> <db> <cfg> <maxReplays>
import { readFileSync, writeSync } from "node:fs";

const [sinkPath, dbPath, cfgPath, maxReplaysArg] = process.argv.slice(2);
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Sink } = require(sinkPath);
const sink = new Sink(dbPath, JSON.parse(readFileSync(cfgPath, "utf8")));
const db = (sink as any).db;
const q = (sql: string) => db.prepare(sql).all().map((r: object) => ({ ...r }));
const dump = () => JSON.stringify({ meta: q("SELECT * FROM meta ORDER BY k"), state: q("SELECT * FROM state"),
  settled: q("SELECT * FROM settled ORDER BY seq"), outbox: q("SELECT * FROM outbox ORDER BY seq"),
  seqs: q("SELECT * FROM sqlite_sequence ORDER BY name") });
const pragma = (p: string) => Object.values(db.prepare(`PRAGMA ${p}`).get() ?? {})[0];
const out: any = {
  journal_mode: pragma("journal_mode"), synchronous: pragma("synchronous"), fullfsync: pragma("fullfsync"),
  integrity: q("PRAGMA integrity_check").map((r: any) => r.integrity_check),
  state: sink.storedBlob() === undefined ? null : JSON.parse(sink.storedBlob()),
  initial_sha: q("SELECT v FROM meta WHERE k = 'initial_state_sha256'")[0]?.v ?? null,
  settled: sink.settled().map((r: any) => {
    const t = JSON.parse(r.token);
    return { seq: r.seq, request_id: r.request_id, amount: t.body.intent.amount, pre: t.body.preStateSha256,
      post_remaining: t.body.post.remaining };
  }),
  outbox: sink.outbox().map((r: any) => ({ seq: r.seq, request_id: r.request_id, amount: JSON.parse(r.intent).amount })),
  audit: sink.storedBlob() === undefined ? ["no stored state"] : sink.audit(),
  replays: [] as any[],
};
const rows = sink.settled();
const pick = rows.length <= Number(maxReplaysArg) ? rows : [rows[0], rows[rows.length - 1],
  ...Array.from({ length: Number(maxReplaysArg) - 2 }, () => rows[Math.floor(Math.random() * rows.length)])];
for (const row of pick) {
  const before = dump();
  const r = sink.commit(row.token);
  const after = dump();
  out.replays.push({ request_id: row.request_id, status: r.status, reason: r.reason ?? null, unchanged: before === after });
}
sink.close();
writeSync(1, JSON.stringify(out) + "\n");
