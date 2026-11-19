// Spec-conformance DRIVER (task h-specdiff). TESTED-UNPROVED new code.
// Run: node --import tsx tests/refund-finality/spec-conformance/run.ts <sinkModulePath> <mode> <count> <seed> <compiledCoreModule> [workDir]
//   sinkModulePath: a module that exports class Sink(path, cfg) with init(state), commit(text), close()
//   mode: seq | fault | interleave
//     seq: one sink instance, one delivery after another
//     fault: as seq, and a storage fault is injected (an exception) at a random write of some commits
//     interleave: two sink instances on the same database file; each delivery goes to one of them at random
//   compiledCoreModule: the compiled Slice 1 core (model.cjs); the oracle uses only its Refund.Assess.
// It generates delivery sequences with its own seeded generator, delivers them, reads the durable state through
// its OWN read-only SQLite connection (tables state, settled, outbox), and calls the oracle (oracle.ts).
// Output: one JSON line. Exit 0 when it ran (violations are DATA, not an exit code); exit 2 on a usage error.
import { generateKeyPairSync, sign, KeyObject } from "node:crypto";
import { mkdtempSync, rmSync, readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import * as sqlite from "node:sqlite";
import { ChargeState, DOMAIN, TokenBody, canon, sha256hex, signedBytes } from "../../../ts/refund-finality/encoding";
import { Delivery, History, Oracle, Prop, Snapshot } from "./oracle";

const MAX = 9223372036854775807n;
// ---- seeded generator (mulberry32)
function rng(seed: number) {
  let a = seed >>> 0;
  const next = () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  const int = (n: number) => Math.floor(next() * n);
  const big = (hi: bigint): bigint => {           // uniform-ish in [0, hi], with the edges often
    const r = next(); if (hi <= 0n) return 0n; if (r < 0.15) return 0n; if (r < 0.3) return hi;
    let x = 0n; for (let k = 0; k < 4; k++) x = (x << 32n) | BigInt(Math.floor(next() * 4294967296)); return x % (hi + 1n);
  };
  return { next, int, big, pick: <T>(xs: T[]): T => xs[int(xs.length)] };
}
export type Kind = "honest" | "zero" | "full" | "replay" | "stale" | "bad-sig" | "bad-pin" | "reuse-id" |
  "f-reqid" | "f-foreign-intent" | "f-foreign-post" | "f-over-zero-post" | "f-over-unchanged" | "f-reason" |
  "f-over-bound" | "f-disabled" | "probe-long-id" | "probe-nul-id";
const KINDS: [Kind, number][] = [["honest", 22], ["zero", 8], ["full", 6], ["replay", 8], ["stale", 6], ["bad-sig", 4],
  ["bad-pin", 4], ["reuse-id", 4], ["f-reqid", 4], ["f-foreign-intent", 4], ["f-foreign-post", 3], ["f-over-zero-post", 3],
  ["f-over-unchanged", 4], ["f-reason", 4], ["f-over-bound", 3], ["probe-long-id", 3], ["probe-nul-id", 2]];
const REASONS = ["duplicate_charge", "service_not_delivered", "returned_item"];

type Keys = { pub: string; priv: KeyObject; otherPriv: KeyObject };
const st = (s: { chargeId: string; original: bigint; remaining: bigint; refundEnabled: boolean }): ChargeState =>
  ({ chargeId: s.chargeId, original: s.original.toString(), remaining: s.remaining.toString(), refundEnabled: s.refundEnabled });
const pstate = (t: string) => { const v = JSON.parse(t); return { chargeId: v.chargeId as string, original: BigInt(v.original),
  remaining: BigInt(v.remaining), refundEnabled: v.refundEnabled as boolean }; };

function readSnap(path: string): Snapshot {
  const db = new sqlite.DatabaseSync(path, { readOnly: true });
  try {
    const s = db.prepare("SELECT blob FROM state WHERE id = 1").get() as { blob: string } | undefined;
    const settled = (db.prepare("SELECT request_id FROM settled ORDER BY seq").all() as any[]).map(r => String(r.request_id));
    const outbox = (db.prepare("SELECT request_id, intent FROM outbox ORDER BY seq").all() as any[])
      .map(r => ({ request_id: String(r.request_id), intent: String(r.intent) }));
    return { state: s === undefined ? null : s.blob, settled, outbox };
  } finally { db.close(); }
}

// ---- fault injection: an armed write throws before it runs (inside the sink's transaction).
let faultArmed = -1, writeCount = 0, faultHit = false;
const SP: any = (sqlite as any).StatementSync.prototype, origRun = SP.run;
SP.run = function (...args: unknown[]) {
  const sql = String(this.sourceSQL ?? "");
  if (/^\s*(INSERT|UPDATE)/i.test(sql) && faultArmed >= 0) {
    if (writeCount++ === faultArmed) { faultHit = true; throw new Error("injected storage fault"); }
  }
  return origRun.apply(this, args);
};

function main(): void {
  const [sinkPath, mode, countArg, seedArg, corePath, workArg] = process.argv.slice(2);
  if (!sinkPath || !["seq", "fault", "interleave"].includes(mode) || !corePath || !/^\d+$/.test(countArg ?? "") || !/^\d+$/.test(seedArg ?? "")) {
    process.stderr.write("usage: run.ts <sinkModulePath> <seq|fault|interleave> <count> <seed> <compiledCoreModule> [workDir]\n");
    process.exit(2);
  }
  const count = Number(countArg), seed = Number(seedArg);
  const SinkClass = createRequire(__filename)(resolve(sinkPath)).Sink;
  const oracle = new Oracle(corePath);
  const work = mkdtempSync(join(workArg ? resolve(workArg) : tmpdir(), "specdiff-"));
  const R = rng(seed);
  const k1 = generateKeyPairSync("ed25519"), k2 = generateKeyPairSync("ed25519");
  const keys: Keys = { pub: k1.publicKey.export({ type: "spki", format: "pem" }) as string, priv: k1.privateKey, otherPriv: k2.privateKey };
  const specLockSha256 = sha256hex("spec-lock-test"), checkerSha256 = sha256hex("checker-test");
  const perProp: Record<string, number> = {}; const smallest: Record<string, unknown> = {};
  const outcomes: Record<string, number> = {}; const kindViolation: Record<string, Record<string, number>> = {}; const kindOutcome: Record<string, Record<string, number>> = {};
  let deliveriesTotal = 0, faultsHit = 0, sinkErrors = 0;
  const t0 = Date.now();
  for (let n = 0; n < count; n++) {
    const dbPath = join(work, `s${n}.sqlite`);
    const orig = R.pick([0n, 1n, 100n, 1000n, MAX, R.big(MAX)]);
    const c0 = st({ chargeId: `ch_${seed}_${n}`, original: orig, remaining: R.big(orig), refundEnabled: R.next() >= 0.15 });
    const cfg = { publicKeyPem: keys.pub, specLockSha256, checkerSha256, initialState: c0 };
    const sinks: any[] = [];
    const history: History = { initial: c0, publicKeyPem: keys.pub, specLockSha256, checkerSha256, start: { state: null, settled: [], outbox: [] }, deliveries: [] };
    const trace: { kind: Kind; outcome: string; reason?: string; fault?: boolean }[] = [];
    try {
      sinks.push(new SinkClass(dbPath, cfg)); sinks[0].init(c0);
      if (mode === "interleave") sinks.push(new SinkClass(dbPath, cfg));
      history.start = readSnap(dbPath);
      const sent: string[] = [], states: string[] = [history.start.state ?? canon(c0)];
      const len = 1 + R.int(10);
      let ridN = 0;
      const fresh = () => `rq_${n}_${ridN++}`;
      for (let d = 0; d < len; d++) {
        const before = readSnap(dbPath);
        const preText = before.state ?? canon(c0), pre = pstate(preText);
        let kind = weighted(R);
        if (kind === "replay" && sent.length === 0) kind = "honest";
        if (kind === "reuse-id" && before.settled.length === 0) kind = "honest";
        // An honest-shaped refund on a charge with refundEnabled false is a FAULTY-SIGNER token.
        if ((kind === "honest" || kind === "zero" || kind === "full") && !pre.refundEnabled) kind = "f-disabled";
        let text: string;
        if (kind === "replay") text = R.pick(sent);
        else {
          const body = buildBody(kind, R, pre, preText, states, before, fresh, specLockSha256, checkerSha256);
          const signer = kind === "bad-sig" ? keys.otherPriv : keys.priv;
          text = canon({ body, signature: sign(null, signedBytes(body as TokenBody), signer).toString("base64") });
        }
        sent.push(text);
        const target = sinks[mode === "interleave" ? R.int(2) : 0];
        faultArmed = mode === "fault" && R.next() < 0.3 ? R.int(3) : -1; writeCount = 0; faultHit = false;
        let res: { status: string; reason?: string };
        try { res = target.commit(text); } catch (e) { sinkErrors++; res = { status: "rejected", reason: "sink threw: " + String((e as Error).message) }; }
        const hit = faultHit; faultArmed = -1; if (hit) faultsHit++;
        const after = readSnap(dbPath);
        if (after.state !== null && after.state !== preText) states.push(after.state);
        const outcome = (["committed", "replayed", "rejected"].includes(res.status) ? res.status : "rejected") as Delivery["outcome"];
        history.deliveries.push({ text, outcome, reason: res.reason, faultInjected: hit, after });
        trace.push({ kind, outcome, reason: res.reason, ...(hit ? { fault: true } : {}) });
        outcomes[outcome] = (outcomes[outcome] ?? 0) + 1;
        (kindOutcome[kind] ??= {})[outcome] = ((kindOutcome[kind] ?? {})[outcome] ?? 0) + 1;
        deliveriesTotal++;
      }
    } catch (e) {
      sinkErrors++; trace.push({ kind: "honest", outcome: "sink setup failed", reason: String((e as Error).message) });
    } finally {
      for (const s of sinks) { try { s.close(); } catch { /* closed */ } }
      for (const f of [dbPath, dbPath + "-wal", dbPath + "-shm", dbPath + "-journal"]) rmSync(f, { force: true });
    }
    const v = oracle.check(history);
    const seen = new Set<Prop>();
    for (const x of v.violations) {
      const kk = x.index >= 0 && trace[x.index] ? trace[x.index].kind : "init";
      (kindViolation[kk] ??= {})[x.property] = ((kindViolation[kk] ?? {})[x.property] ?? 0) + 1;
      if (seen.has(x.property)) continue; seen.add(x.property);
      perProp[x.property] = (perProp[x.property] ?? 0) + 1;
      const cut = trace.slice(0, x.index + 1), cur = smallest[x.property] as { length: number } | undefined;
      if (cur === undefined || cut.length < cur.length)
        smallest[x.property] = { length: cut.length, sequence: n, initial: c0, at: x.index, detail: x.detail.slice(0, 300), trace: cut };
    }
  }
  rmSync(work, { recursive: true, force: true });
  process.stdout.write(JSON.stringify({
    tool: "spec-conformance/run.ts", sink: resolve(sinkPath), sinkSha256: sha256hex(readFileSync(resolve(sinkPath))),
    core: oracle.coreModule, coreSha256: sha256hex(readFileSync(oracle.coreModule)), mode, count, seed,
    deliveries: deliveriesTotal, outcomes, faultsInjected: faultsHit, sinkErrors, ms: Date.now() - t0,
    sequencesWithViolation: perProp, kindOutcome, violationsByKind: kindViolation, smallest,
  }) + "\n");
}

function weighted(R: ReturnType<typeof rng>): Kind {
  const total = KINDS.reduce((a, [, w]) => a + w, 0); let x = R.int(total);
  for (const [k, w] of KINDS) { if (x < w) return k; x -= w; } return "honest";
}

// Builds the token body of one delivery against the ACTUAL persisted state `pre`. Kinds named f-* are
// FAULTY-SIGNER tokens: the trusted test key signs them, but the approved spec does not authorize them.
function buildBody(kind: Kind, R: ReturnType<typeof rng>, pre: ReturnType<typeof pstate>, preText: string, states: string[],
    before: Snapshot, fresh: () => string, specLockSha256: string, checkerSha256: string): unknown {
  const rem = pre.remaining < 0n ? 0n : pre.remaining;
  let amount = kind === "zero" ? 0n : kind === "full" ? rem : R.big(rem);
  let reason = R.pick(REASONS), requestId = fresh(), intentReq = requestId, intentCharge = pre.chargeId;
  let preHash = sha256hex(preText);
  let post: ChargeState = st({ ...pre, remaining: pre.remaining - amount });
  switch (kind) {
    case "stale": {
      const old = states.filter(s => s !== preText);
      preHash = sha256hex(old.length ? R.pick(old) : canon(st({ ...pre, remaining: pre.remaining + 1n })));
      break;
    }
    case "reuse-id": requestId = intentReq = R.pick(before.settled); break;
    case "f-reqid": intentReq = before.outbox.length ? (JSON.parse(R.pick(before.outbox).intent).requestId as string) : fresh(); break;
    case "f-foreign-intent": intentCharge = "ch_foreign"; break;
    case "f-foreign-post": post = st({ ...pre, chargeId: "ch_foreign", remaining: pre.remaining - amount }); break;
    case "f-over-zero-post": amount = rem + 1n + R.big(1000n); post = st({ ...pre, remaining: 0n }); break;
    case "f-over-unchanged": amount = rem + 1n + R.big(1000n); post = st({ ...pre }); break;
    case "f-reason": reason = R.pick(["Duplicate_charge", "fraud", "", "returned_item "]); break;
    case "f-over-bound": post = st({ ...pre, original: 9999999999999999999n, remaining: pre.remaining - amount }); break;
    case "probe-long-id": requestId = intentReq = "r".repeat(300) + fresh(); break;
    case "probe-nul-id": requestId = intentReq = "rq\u0000" + fresh(); break;
    default: break;
  }
  // A negative remaining cannot be written as a money text; the sink would refuse it as token shape.
  if (BigInt(post.remaining) < 0n) post = { ...post, remaining: "0" };
  const body = {
    domain: DOMAIN, specLockSha256: kind === "bad-pin" ? sha256hex("another spec lock") : specLockSha256, checkerSha256,
    preStateSha256: preHash, requestId, post,
    intent: { chargeId: intentCharge, requestId: intentReq, amount: amount.toString(), reason },
  };
  return body;
}

main();
