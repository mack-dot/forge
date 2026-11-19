// Spec-conformance DRIVER (task h-specdiff; process model, dispatcher and exit codes: task h-judges). TESTED-UNPROVED.
// Run: node --import tsx tests/refund-finality/spec-conformance/run.ts <sinkModulePath> <mode> <count> <seed> <compiledCoreModule>
//        [workDir] [--dispatcher <dispatcherModulePath>] [--expect-violations P1,P2,...]
//   sinkModulePath: a module that exports class Sink(path, cfg) with init(state), commit(text), close()
//   mode: seq | fault | interleave
//     seq: one sink instance, one delivery after another
//     fault: as seq, and a storage fault is injected (an exception) at a random write of some commits
//     interleave: two sink instances on the same database file; each delivery goes to one of them at random
//   compiledCoreModule: the compiled Slice 1 core (model.cjs); the oracle uses only its Refund.Assess.
//   --dispatcher: after each sequence the dispatcher flushes the store; the oracle checks the EMITTED effects.
// With --dispatcher, the EFFECT RECEIVER is held by this process (../regress/remote.ts, task h-judges2): each emit call
// of the dispatcher under test is a record on a pipe that this process created, ACKed here before the call returns.
// The sink and dispatcher run in a CHILD process (../regress/worker.ts); this process generates the deliveries,
// reads the durable state through its OWN read-only SQLite connection (tables state, settled, outbox), and calls
// the oracle (oracle.ts) with the TRUSTED encoding.ts of this tree. Some sequences have restarts of the sink, more
// than 20 deliveries, long or non-ASCII request ids, and non-canonical token texts.
// Output: one JSON line. Exit 0 only when all sequences ran, the child stayed alive, and the set of violated
// properties (P5-SILENT excluded: a question, not a verdict) is empty, or equals --expect-violations. Exit 1
// otherwise; exit 2 on a usage error.
import { generateKeyPairSync, sign, KeyObject } from "node:crypto";
import { mkdtempSync, rmSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import * as sqlite from "node:sqlite";
import { ChildGone, Remote } from "../regress/remote";
import { TRUSTED_ENCODING_PATH } from "../regress/harness";
import { ChargeState, DOMAIN, TokenBody, canon, keyIdOf, sha256hex, signedBytes } from "../../../ts/refund-finality/encoding";
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
  "f-over-bound" | "f-disabled" | "probe-long-id" | "probe-nul-id" | "noncanon";
const KINDS: [Kind, number][] = [["honest", 22], ["zero", 8], ["full", 6], ["replay", 8], ["stale", 6], ["bad-sig", 4],
  ["bad-pin", 4], ["reuse-id", 4], ["f-reqid", 4], ["f-foreign-intent", 4], ["f-foreign-post", 3], ["f-over-zero-post", 3],
  ["f-over-unchanged", 4], ["f-reason", 4], ["f-over-bound", 3], ["probe-long-id", 3], ["probe-nul-id", 2], ["noncanon", 4]];
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

// ---- PROCESS MODEL (task h-judges): the sink (and the dispatcher) run in ONE CHILD process (regress/worker.ts) for
// the whole run; this process holds the generator, the keys, the snapshots (its own read-only connection) and the
// oracle. Storage faults are injected in the child (worker.ts patches StatementSync.run before the sink loads).
// A child that exits, is killed or stops answering ends the run with exit 1 (field childGone).
type Res = { status: string; reason?: string; faultHit?: boolean };
async function main(): Promise<number> {
  const argv = process.argv.slice(2);
  const take = (flag: string): string | null => { const i = argv.indexOf(flag); if (i < 0) return null; const v = argv[i + 1] ?? ""; argv.splice(i, 2); return v; };
  const dispArg = take("--dispatcher"), expArg = take("--expect-violations");
  const [sinkPath, mode, countArg, seedArg, corePath, workArg] = argv;
  if (!sinkPath || !["seq", "fault", "interleave"].includes(mode) || !corePath || !/^\d+$/.test(countArg ?? "") || !/^\d+$/.test(seedArg ?? "") || dispArg === "" || expArg === "") {
    process.stderr.write("usage: run.ts <sinkModulePath> <seq|fault|interleave> <count> <seed> <compiledCoreModule> [workDir] [--dispatcher <path>] [--expect-violations P1,P2,...]\n");
    return 2;
  }
  const expected = expArg === null ? null : new Set(expArg.split(",").map(s => s.trim()).filter(s => s.length > 0));
  const count = Number(countArg), seed = Number(seedArg);
  const oracle = new Oracle(corePath);
  const remote = new Remote(resolve(sinkPath), dispArg ? resolve(dispArg) : null);
  await remote.ready;
  const caps = await remote.call<{ loadError: string; hasSink: boolean; hasDispatcher: boolean; hasGenesisOf: boolean }>("hello");
  const work = mkdtempSync(join(workArg ? resolve(workArg) : tmpdir(), "specdiff-"));
  const R = rng(seed);
  const k1 = generateKeyPairSync("ed25519"), k2 = generateKeyPairSync("ed25519");
  const keys: Keys = { pub: k1.publicKey.export({ type: "spki", format: "pem" }) as string, priv: k1.privateKey, otherPriv: k2.privateKey };
  const specLockSha256 = sha256hex("spec-lock-test"), checkerSha256 = sha256hex("checker-test");
  const perProp: Record<string, number> = {}; const smallest: Record<string, unknown> = {};
  const outcomes: Record<string, number> = {}; const kindViolation: Record<string, Record<string, number>> = {}; const kindOutcome: Record<string, Record<string, number>> = {};
  let deliveriesTotal = 0, faultsHit = 0, sinkErrors = 0, restarts = 0, emittedTotal = 0, done = 0;
  let childGone: string | null = caps.hasSink ? null : "module under test does not export Sink: " + caps.loadError;
  const t0 = Date.now();
  for (let n = 0; n < count && childGone === null; n++) {
    const dbPath = join(work, `s${n}.sqlite`);
    const orig = R.pick([0n, 1n, 100n, 1000n, MAX, R.big(MAX)]);
    const c0 = st({ chargeId: `ch_${seed}_${n}`, original: orig, remaining: R.big(orig), refundEnabled: R.next() >= 0.15 });
    const cfg = { publicKeyPem: keys.pub, specLockSha256, checkerSha256, initialState: c0 };
    const handles: number[] = [];
    const history: History = { initial: c0, publicKeyPem: keys.pub, specLockSha256, checkerSha256, start: { state: null, settled: [], outbox: [] }, deliveries: [] };
    const trace: { kind: Kind | "restart"; outcome: string; reason?: string; fault?: boolean }[] = [];
    const openOne = async (): Promise<string> => { const o = await remote.call<{ handle: number; error: string }>("open", { db: dbPath, cfg }); if (!o.handle) return o.error || "refused"; handles.push(o.handle); return ""; };
    try {
      let err = await openOne();
      if (!err) { const i = await remote.call<{ error: string }>("init", { handle: handles[0], state: c0 }); err = i.error; }
      if (!err && mode === "interleave") err = await openOne();
      if (err) { history.startRefused = err; sinkErrors++; trace.push({ kind: "honest", outcome: "sink setup failed", reason: err }); }
      else {
        history.start = readSnap(dbPath);
        const sent: string[] = [], states: string[] = [history.start.state ?? canon(c0)];
        const len = R.next() < 0.1 ? 21 + R.int(15) : 1 + R.int(10);           // some stores get more than 20 deliveries
        let ridN = 0;
        const fresh = () => { const base = `rq_${n}_${ridN++}`; const r = R.next();      // ids: plain, long, non-ASCII
          return r < 0.08 ? base + "_" + "r".repeat(40) : r < 0.12 ? base + "_\u00e9\u4e2d" : r < 0.15 ? base + "_" + String.fromCodePoint(0x1f600) : r < 0.17 ? base + "_e\u0301" : base; };
        for (let d = 0; d < len; d++) {
          if (R.next() < 0.06) {                                                    // a restart of the sink
            for (const hd of handles.splice(0)) await remote.call("close", { handle: hd });
            let e2 = await openOne(); if (!e2 && mode === "interleave") e2 = await openOne();
            history.deliveries.push({ text: "", outcome: "rejected", restart: true, after: readSnap(dbPath) });
            trace.push({ kind: "restart", outcome: e2 ? "reopen refused: " + e2.slice(0, 80) : "reopened" }); restarts++;
            if (e2) break;
            continue;
          }
          const before = readSnap(dbPath);
          const preText = before.state ?? canon(c0), pre = pstate(preText);
          let kind = weighted(R);
          if (kind === "replay" && sent.length === 0) kind = "honest";
          if (kind === "reuse-id" && before.settled.length === 0) kind = "honest";
          if ((kind === "honest" || kind === "zero" || kind === "full" || kind === "noncanon") && !pre.refundEnabled) kind = "f-disabled";
          let text: string;
          if (kind === "replay") text = R.pick(sent);
          else {
            const body = buildBody(kind, R, pre, preText, states, before, fresh, specLockSha256, checkerSha256);
            const signer = kind === "bad-sig" ? keys.otherPriv : keys.priv;
            const keyId = keyIdOf(keys.pub);   // D-1: the pinned key id (also for a "bad-sig" token of the other key)
            const tok = { body, keyId, signature: sign(null, signedBytes(body as TokenBody, keyId), signer).toString("base64") };
            text = kind === "noncanon" ? JSON.stringify(tok, null, 1) : canon(tok);
          }
          sent.push(text);
          const target = handles[mode === "interleave" ? R.int(handles.length) : 0];
          const faultAt = mode === "fault" && R.next() < 0.3 ? R.int(3) : undefined;
          const res = await remote.call<Res>("commit", { handle: target, text, faultAt });
          if (res.status === "threw") sinkErrors++;
          const hit = res.faultHit === true; if (hit) faultsHit++;
          const after = readSnap(dbPath);
          if (after.state !== null && after.state !== preText) states.push(after.state);
          const outcome = (["committed", "replayed", "rejected"].includes(res.status) ? res.status : "rejected") as Delivery["outcome"];
          history.deliveries.push({ text, outcome, reason: res.reason, faultInjected: hit, after });
          trace.push({ kind, outcome, reason: res.reason, ...(hit ? { fault: true } : {}) });
          outcomes[outcome] = (outcomes[outcome] ?? 0) + 1;
          (kindOutcome[kind] ??= {})[outcome] = ((kindOutcome[kind] ?? {})[outcome] ?? 0) + 1;
          deliveriesTotal++;
        }
        if (caps.hasDispatcher) {
          const dcfg: any = { publicKeyPem: keys.pub, specLockSha256, checkerSha256, initialStateSha256: sha256hex(canon(c0)) };
          if (caps.hasGenesisOf) dcfg.newLedgerH0 = await remote.call("genesis", { initText: canon(c0), lock: specLockSha256, checker: checkerSha256, pem: keys.pub });
          // The emitted effects are the records that the PARENT's receiver got (regress/remote.ts), not a child report.
          const f = await remote.flush({ db: dbPath, ledger: dbPath + ".ledger.jsonl", dcfg });
          history.emitted = f.effects.map(e => ({ requestId: e.requestId, intent: e.intent }));
          emittedTotal += f.effects.length;
        }
      }
    } catch (e) {
      if (e instanceof ChildGone) { childGone = e.message + " | child output: " + remote.outputTail(200).replace(/\s+/g, " "); break; }
      sinkErrors++; trace.push({ kind: "honest", outcome: "driver error", reason: String((e as Error).message) });
    } finally {
      if (childGone === null) for (const hd of handles) { try { await remote.call("close", { handle: hd }); } catch { /* gone */ } }
      for (const f of [dbPath, dbPath + "-wal", dbPath + "-shm", dbPath + "-journal", dbPath + ".ledger.jsonl", dbPath + ".ledger.jsonl.lock"]) rmSync(f, { force: true });
    }
    done++;
    const v = oracle.check(history);
    const seen = new Set<Prop>();
    for (const x of v.violations) {
      const kk = x.index >= 0 && trace[x.index] ? trace[x.index].kind : x.index === -2 ? "dispatcher" : "init";
      (kindViolation[kk] ??= {})[x.property] = ((kindViolation[kk] ?? {})[x.property] ?? 0) + 1;
      if (seen.has(x.property)) continue; seen.add(x.property);
      perProp[x.property] = (perProp[x.property] ?? 0) + 1;
      const cut = x.index >= 0 ? trace.slice(0, x.index + 1) : trace, cur = smallest[x.property] as { length: number } | undefined;
      if (cur === undefined || cut.length < cur.length)
        smallest[x.property] = { length: cut.length, sequence: n, initial: c0, at: x.index, detail: x.detail.slice(0, 300), trace: cut };
    }
  }
  await remote.stop();
  rmSync(work, { recursive: true, force: true });
  // Effect-channel faults (regress/remote.ts): a record outside a flush, a line that is not a record, a channel held
  // open after the child died. Any of them makes the run NOT OK (an effect that the oracle did not see is still one).
  const channelProblems = remote.problems.slice(0, 5);
  // VERDICT. P5-SILENT is a question for the owner, not a violation. Exit 0 only when the run completed all
  // sequences, the child stayed alive, and the violated set is empty (or equals --expect-violations).
  const violated = Object.keys(perProp).filter(p => p !== "P5-SILENT").sort();
  const completed = childGone === null && done === count;
  const want = expected ? [...expected].sort() : [];
  const ok = completed && canon(violated) === canon(want) && channelProblems.length === 0;
  process.stdout.write(JSON.stringify({
    tool: "spec-conformance/run.ts", sink: resolve(sinkPath), sinkSha256: sha256hex(readFileSync(resolve(sinkPath))),
    dispatcher: dispArg ? resolve(dispArg) : null, dispatcherSha256: dispArg ? sha256hex(readFileSync(resolve(dispArg))) : null,
    trustedEncodingSha256: sha256hex(readFileSync(TRUSTED_ENCODING_PATH)),
    core: oracle.coreModule, coreSha256: sha256hex(readFileSync(oracle.coreModule)), mode, count, seed, sequencesDone: done, childGone,
    deliveries: deliveriesTotal, restarts, emitted: emittedTotal, effectChannelProblems: channelProblems, outcomes, faultsInjected: faultsHit, sinkErrors, ms: Date.now() - t0,
    sequencesWithViolation: perProp, violated, expectedViolations: expected ? want : null, verdict: ok ? "OK" : "NOT OK",
    kindOutcome, violationsByKind: kindViolation, smallest,
  }) + "\n");
  return ok ? 0 : 1;
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

main().then(c => process.exit(c), e => { process.stderr.write("judge error: " + String((e as Error)?.stack ?? e) + "\n"); process.exit(1); });
