// r-harden probe P7: C-ATT-23 ported to the hardened sink, as a DETERMINISTIC light variant (no kill loop).
// The on-disk state that a crash of writer A (name a.sqlite) leaves INSIDE its COMMIT (new pages written, journal not yet deleted) is built
// A opens a.sqlite, BEGIN IMMEDIATE, writes the next commit with cache_size = 1 (pages spill into the database file
// after the journal is synced), and the files a.sqlite + a.sqlite-journal are COPIED at that moment into a new
// directory (= what a crash leaves). In that directory b.sqlite is a HARD LINK to a.sqlite (two names, one inode).
// Then honest sink B opens b.sqlite (no b.sqlite-journal: the hot journal is invisible to it) and commits r2, r3
// (acknowledged). Then honest sink A restarts by a.sqlite: SQLite plays back a.sqlite-journal.
// Control "same": B opens a.sqlite (same name) instead. Exit 1: an acknowledged commit is lost while a sink serves.
// usage (cwd = tree): node --import tsx p7_hardlink_snapshot.ts <treeRoot> <scratch dir> <hardlink|same>
import { generateKeyPairSync, sign } from "node:crypto";
import { copyFileSync, existsSync, linkSync, mkdirSync, readFileSync, rmSync, statSync } from "node:fs";
import { writeFileSync } from "node:fs";
import { makeJournal } from "./journal";
import { join, resolve } from "node:path";
const [T0, O0, mode = "hardlink"] = process.argv.slice(2); const TREE = resolve(T0), OUT = resolve(O0);
rmSync(OUT, { recursive: true, force: true }); mkdirSync(OUT, { recursive: true });
/* eslint-disable @typescript-eslint/no-require-imports */
const E = require(join(TREE, "ts/refund-finality/encoding.ts")); const HM = require(join(TREE, "ts/refund-finality/sink.ts"));
/* eslint-enable @typescript-eslint/no-require-imports */
const { canon, signedBytes, stateSha256, sha256hex, DOMAIN } = E;
const { publicKey, privateKey } = generateKeyPairSync("ed25519"); const pem = publicKey.export({ type: "spki", format: "pem" }) as string;
const st = (r: string) => ({ chargeId: "ch_1", original: "100000", remaining: r, refundEnabled: true });
const S0 = st("100000"); const cfg: any = { publicKeyPem: pem, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: S0 };
const tok = (pre: any, rid: string, amount: string) => { const body = { domain: DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256,
  preStateSha256: stateSha256(pre), requestId: rid, post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() },
  intent: { chargeId: "ch_1", requestId: rid, amount, reason: "duplicate_charge".padEnd(16) } };
  return canon({ body, signature: sign(null, signedBytes(body), privateKey).toString("base64") }); };
const out: any = { mode };
// a store with 60 commits (several pages per table), then the crash snapshot of commit 61 by A
const src = join(OUT, "src"); mkdirSync(src); const a0 = join(src, "a.sqlite");
const toks: string[] = []; let rem = 100000;
for (let i = 0; i < 64; i++) { toks.push(tok(st(String(rem)), "rq_" + i, "1")); rem -= 1; }
{ const s = new HM.Sink(a0, cfg); s.init(S0); for (let i = 0; i < 60; i++) if (s.commit(toks[i]).status !== "committed") throw new Error("setup"); s.close(); }
const before = readFileSync(a0);
// The crash window of A's commit 61: the database file already holds the NEW pages, the journal (synced, valid
// nRec) still holds the OLD pages, A's commit has NOT returned (not acknowledged). The journal is made by journal.ts
// (all pages of the old file: a superset of what SQLite journals; playback gives the same old file).
{ const s = new HM.Sink(a0, cfg); if (s.commit(toks[60]).status !== "committed") throw new Error("setup 61"); s.close(); }
const crash = join(OUT, "crash"); mkdirSync(crash); const a = join(crash, "a.sqlite"), b = join(crash, "b.sqlite");
copyFileSync(a0, a); writeFileSync(a + "-journal", makeJournal(before));
out.journalNRec = readFileSync(a + "-journal").readUInt32BE(8);
if (mode === "hardlink") linkSync(a, b); out.nlink = statSync(a).nlink;
const nameB = mode === "hardlink" ? b : a;
const acked: string[] = ["rq_0"];   // rq_60 (commit 61 of A, in the crash window) is NOT counted as acknowledged
try {
  const sb = new HM.Sink(nameB, cfg); out.B_start = "ok count=" + sb.head().count;
  // B commits the next tokens from its view of the stored state
  const cur = JSON.parse(sb.stateBlob()).remaining; out.B_sees_remaining = cur;
  const k = 100000 - Number(cur);
  for (const i of [k, k + 1]) { const r = sb.commit(toks[i]); if (r.status === "committed") acked.push("rq_" + i); else out["B_" + i] = r.reason; }
  out.B_acked = acked.slice(1); sb.close();
} catch (e) { out.B_start = "REFUSED: " + String((e as Error).message).slice(0, 120); }
try {
  const sa = new HM.Sink(a, cfg); const ids = (sa.settled() as any[]).map(r => r.request_id); out.A_restart = "ok count=" + sa.head().count;
  out.lost = acked.filter(r => !ids.includes(r)); out.A_audit = sa.audit(); sa.close();
} catch (e) { out.A_restart = "REFUSED: " + String((e as Error).message).slice(0, 120); out.lost = null; }
out.journalLeft = existsSync(a + "-journal");
const defect = Array.isArray(out.lost) && out.lost.length > 0;
console.log(JSON.stringify(out, null, 1));
rmSync(OUT, { recursive: true, force: true });
console.log(defect ? "DEFECT: acknowledged commits lost while the sink serves" : "SAFE"); process.exit(defect ? 1 : 0);
