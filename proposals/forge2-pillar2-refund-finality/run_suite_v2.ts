// Round 3 task 3 (U428): suite for minter version 2 (proved decision core) and the checked outbound dispatcher.
// Real processes, real Ed25519, real SQLite files, raw row changes through a second connection.
// This is a FINITE TEST. It proves nothing universal. Run: node --import tsx run_suite_v2.ts <fresh-out-dir>
import { spawn, ChildProcessWithoutNullStreams } from "node:child_process";
import { createPublicKey, generateKeyPairSync, sign, verify } from "node:crypto";
import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { createInterface } from "node:readline";
import { DatabaseSync } from "node:sqlite";
import BigNumber from "bignumber.js";
import { ChargeState, Claim, RefundRequest, canon, makeClaim, payload, sha256hex } from "./common";
import { Dispatcher, DispatcherConfig, Effect, naiveFlush } from "./dispatcher";
import { Sink } from "./sink";

const ROOT = resolve(__dirname, "../..");
const CORE = join(ROOT, "build/round3-refund-core/model.cjs");
const KERNEL = join(ROOT, "build/refund-generated/model.cjs");
const SPEC_LOCK = join(ROOT, "spec/refund/spec.lock");
const outDir = resolve(process.argv[2]);
if (existsSync(outDir)) throw new Error("output directory is not fresh");
mkdirSync(outDir, { recursive: true });
const REASON = "duplicate_charge";

type Minted = { ok: boolean; claim?: Claim; sig?: string; reason?: string };
class Minter {
  private next = 1; private waiting = new Map<number, (v: any) => void>();
  ready!: { publicKeyPem: string; specLockSha256: string; minterSha256: string; singleUse: boolean };
  private constructor(readonly child: ChildProcessWithoutNullStreams) {}
  static start(env: Record<string, string> = {}): Promise<Minter> {
    const child = spawn(process.execPath, ["--import", "tsx", join(__dirname, "minter2.ts"), CORE, SPEC_LOCK],
      { cwd: ROOT, env: { ...process.env, ...env }, stdio: ["pipe", "pipe", "inherit"] }) as unknown as ChildProcessWithoutNullStreams;
    const m = new Minter(child);
    return new Promise((done, fail) => {
      child.on("error", fail);
      createInterface({ input: child.stdout }).on("line", line => {
        const msg = JSON.parse(line);
        if (msg.ready) { m.ready = msg; done(m); return; }
        m.waiting.get(msg.id)?.(msg); m.waiting.delete(msg.id);
      });
    });
  }
  send(body: Record<string, unknown>): Promise<Minted> {
    const id = this.next++;
    return new Promise(done => { this.waiting.set(id, done); this.child.stdin.write(JSON.stringify({ id, ...body }) + "\n"); });
  }
  mint(pre: unknown, request: unknown): Promise<Minted> { return this.send({ pre, request }); }
  stop(): void { this.child.stdin.end(); this.child.kill(); }
}

type Row = { part: string; name: string; expected: string; observed: string; pass: boolean; unauthorizedEffects: number; note?: string };
const rows: Row[] = [];
const add = (part: string, name: string, expected: string, observed: string, pass: boolean, unauthorizedEffects = 0, note?: string) =>
  rows.push({ part, name, expected, observed, pass, unauthorizedEffects, ...(note ? { note } : {}) });
const good = (pem: string, m: Minted) => !!m.ok && !!m.claim && !!m.sig &&
  verify(null, payload(m.claim), createPublicKey(pem), Buffer.from(m.sig, "base64"));

// Independent oracle. The effects, in order, must be a SUBSEQUENCE of one chain of claims signed by the minter
// (signature checked here) that starts at the true initial state: each claim's pre-state hash is the post-state hash
// of the one before, and no claim is used twice. An effect that does not fit is counted as unauthorized. A chain
// claim that is passed over without an effect is counted as lost (expected only in the crash case).
function judge(effects: Effect[], minted: { claim: Claim; sig: string }[], pem: string, initial: ChargeState) {
  const valid = minted.filter(m => good(pem, { ok: true, ...m }));
  const h = (s: ChargeState) => sha256hex(canon(s));
  const path = (from: string, e: Effect, used: Set<string>, depth: number): Claim[] | null => {
    for (const m of valid) {
      if (used.has(m.claim.reqId) || h(m.claim.pre) !== from) continue;
      if (m.claim.reqId === e.reqId && canon(m.claim.intent) === e.intent) return [m.claim];
      if (depth > 0) {
        const rest = path(h(m.claim.post), e, new Set([...used, m.claim.reqId]), depth - 1);
        if (rest) return [m.claim, ...rest];
      }
    }
    return null;
  };
  let head = h(initial), unauthorized = 0, lost = 0, total = 0n;
  const used = new Set<string>();
  for (const e of effects) {
    const p = path(head, e, used, valid.length);
    if (!p) { unauthorized++; continue; }
    lost += p.length - 1; p.forEach(c => used.add(c.reqId));
    head = h(p[p.length - 1].post); total += BigInt(p[p.length - 1].intent.amount);
  }
  return { unauthorized, lost, total: total.toString() };
}

async function main() {
  const minter = await Minter.start();
  const pem = minter.ready.publicKeyPem;
  const independentMinterSha = sha256hex(Buffer.concat([readFileSync(join(__dirname, "minter2.ts")), readFileSync(join(__dirname, "common.ts")), readFileSync(CORE)]));
  const specLockSha256 = sha256hex(readFileSync(SPEC_LOCK));
  add("setup", "minter reports the hashes that the operator computes independently", "equal", String(minter.ready.minterSha256 === independentMinterSha && minter.ready.specLockSha256 === specLockSha256),
    minter.ready.minterSha256 === independentMinterSha && minter.ready.specLockSha256 === specLockSha256);
  const state = (id: string, remaining = "1000", refundEnabled = true): ChargeState => ({ chargeId: "ch_" + id, original: "1000", remaining, refundEnabled });
  const req = (id: string, amount: string, reason = REASON): RefundRequest => ({ requestId: "rq_" + id, amount, reason });

  // ---- Part 1: the minter signs exactly what the proved core authorizes. ----
  const kernel = require(KERNEL);                    // the gate-built refund kernel: reference for the differential grid
  const kt = (s: string) => kernel.runtime.Seq.UnicodeFromString(s);
  let grid = 0, gridBad = 0, gridSigned = 0;
  for (const remaining of ["0", "500", "1000"]) for (const enabled of [true, false]) for (const reason of [REASON, "goodwill"])
    for (const amount of ["0", "1", "100", "500", "501", "1000", "1001"]) {
      const id = `g${grid++}`, pre = state(id, remaining, enabled), r = req(id, amount, reason);
      const [decision] = kernel.Refund.__default.Assess(kernel.Refund.Context.create_ChargeContext(kt(pre.chargeId), kt(r.requestId),
        new BigNumber(pre.original), new BigNumber(pre.remaining), pre.refundEnabled, true), kernel.Refund.ModelResponse.create_Candidate(new BigNumber(amount), kt(reason)));
      const m = await minter.mint(pre, r);
      const want = decision.is_Authorized as boolean;
      const shape = !m.ok || (good(pem, m) && canon(m.claim!.pre) === canon(pre) && canon(m.claim!.request) === canon(r) &&
        m.claim!.post.remaining === (BigInt(remaining) - BigInt(amount)).toString() && canon(m.claim!.post) === canon({ ...pre, remaining: m.claim!.post.remaining }) &&
        canon(m.claim!.intent) === canon({ chargeId: pre.chargeId, requestId: r.requestId, amount, reason }));
      if (m.ok !== want || !shape) gridBad++;
      if (m.ok) gridSigned++;
    }
  add("minter", `differential grid: ${grid} (state, request) pairs against the gate-built kernel`, "0 disagreements; some signed, some refused",
    `${gridBad} disagreements; ${gridSigned} signed; ${grid - gridSigned} refused`, gridBad === 0 && gridSigned > 0 && gridSigned < grid);
  const shapes: [string, unknown, unknown][] = [
    ["extra key in the pre-state", { ...state("s1"), admin: true }, req("s1", "10")],
    ["amount is a JSON number", state("s2"), { requestId: "rq_s2", amount: 10, reason: REASON }],
    ["negative amount", state("s3"), req("s3", "-5")],
    ["amount with 25 digits", state("s4"), req("s4", "1".repeat(25))],
    ["request missing", state("s5"), undefined],
    ["pre-state is an array", [], req("s6", "10")],
    ["remaining above original", { ...state("s7"), remaining: "2000" }, req("s7", "1500")],
  ];
  for (const [name, pre, r] of shapes) {
    const m = await minter.mint(pre, r);
    add("minter", "refused input: " + name, "no signature", m.ok ? "SIGNED" : "refused: " + m.reason, !m.ok);
  }
  {
    const pre = state("inj"), r = req("inj", "100");
    const m = await minter.send({ pre, request: r, post: { ...pre, remaining: "1000" }, intent: { chargeId: pre.chargeId, requestId: r.requestId, amount: "900", reason: REASON } });
    const ok = good(pem, m) && m.claim!.post.remaining === "900" && m.claim!.intent.amount === "100";
    add("minter", "caller sends its own post-state and intent with the request", "ignored: post and intent come from the core", ok ? "core values signed" : "CALLER VALUES USED", ok);
    const again = await minter.mint(pre, r), other = await minter.mint(pre, req("inj2", "50"));
    add("minter", "same request again for the same pre-state", "same signature", again.sig === m.sig ? "same signature" : "different", again.ok && again.sig === m.sig);
    add("minter", "another request for a pre-state that already has a signed claim", "refused", other.ok ? "SIGNED" : "refused: " + other.reason, !other.ok);
  }

  // ---- Part 2 and 3: one scenario per case. Two valid refunds are minted and committed; then the case acts. ----
  const attacker = generateKeyPairSync("ed25519");
  type Ctx = { dir: string; db: string; cfg: DispatcherConfig; initial: ChargeState; minted: { claim: Claim; sig: string }[]; committed: string[];
    effects: Effect[]; dispatcher: (emit?: (e: Effect) => void) => Dispatcher; raw: () => DatabaseSync; sinkOf: () => Sink };
  async function scenario(id: string, mk: Minter = minter, commits: [string, string][] = [["1", "100"], ["2", "200"]]): Promise<Ctx> {
    const dir = join(outDir, id); mkdirSync(dir);
    const db = join(dir, "sink.sqlite"), initial = state(id);
    const sinkCfg = { publicKeyPem: mk.ready.publicKeyPem, specLockSha256, minterSha256: independentMinterSha };
    const cfg: DispatcherConfig = { ...sinkCfg, initialStateSha256: sha256hex(canon(initial)) };
    const sink = new Sink(db, sinkCfg); sink.init(initial);
    const ctx: Ctx = { dir, db, cfg, initial, minted: [], committed: [], effects: [], raw: () => new DatabaseSync(db), sinkOf: () => new Sink(db, sinkCfg),
      dispatcher: emit => new Dispatcher(db, join(dir, "dispatch-ledger.jsonl"), cfg, emit ?? (e => { ctx.effects.push(e); appendFileSync(join(dir, "effects.jsonl"), JSON.stringify(e) + "\n"); })) };
    for (const [n, amount] of commits) {
      const m = await mk.mint(JSON.parse(sink.state().blob), req(`${id}_${n}`, amount));
      if (!good(mk.ready.publicKeyPem, m)) throw new Error(`setup mint failed in ${id}: ${m.reason}`);
      ctx.minted.push({ claim: m.claim!, sig: m.sig! });
      if (sink.commit(m.claim, m.sig).status !== "committed") throw new Error("setup commit failed in " + id);
      ctx.committed.push(m.claim!.reqId);
    }
    sink.close();
    return ctx;
  }
  // Runs the checked dispatcher and the unchecked control on the same database; records one row.
  function verdict(c: Ctx, name: string, expectIds: string[], naiveMustFail: boolean, extra = "", note?: string, mk: Minter = minter, expectLost = 0) {
    let thrown = "";
    let refused: string[] = [];
    try { refused = c.dispatcher().flush().refused.map(r => `${r.reqId}: ${r.reason}`); } catch (error) { thrown = String((error as Error).message); }
    const checked = judge(c.effects, c.minted, mk.ready.publicKeyPem, c.initial);
    const naive = judge(naiveFlush(c.db, () => undefined), c.minted, mk.ready.publicKeyPem, c.initial);
    const ids = c.effects.map(e => e.reqId);
    const pass = checked.unauthorized === 0 && canon(ids) === canon(expectIds) && (!naiveMustFail || naive.unauthorized > 0) && BigInt(checked.total) <= 1000n && checked.lost === expectLost;
    writeFileSync(join(c.dir, "case.json"), JSON.stringify({ name, effects: c.effects, refused, thrown, checked, naive, committedBySink: c.committed }, null, 1));
    add("dispatcher", name, `effects [${expectIds.join(", ")}]; 0 unauthorized` + (naiveMustFail ? "; unchecked control sends unauthorized effects" : ""),
      `effects [${ids.join(", ")}]; ${checked.unauthorized} unauthorized; ${checked.lost} lost; sum ${checked.total}; refused ${refused.length}${thrown ? "; stopped: " + thrown : ""}; ` +
      `unchecked control: ${naive.unauthorized} unauthorized${extra}`, pass, checked.unauthorized, note);
  }
  const ids = (id: string) => [`rq_${id}_1`, `rq_${id}_2`];
  const ins = (db: DatabaseSync, reqId: string, claimText: string, sig: string, intent: string, seq?: number) => {
    db.prepare("INSERT INTO settled(req_id, claim, claim_sha, sig) VALUES (?, ?, ?, ?)").run(reqId, claimText, sha256hex(claimText), sig);
    if (seq === undefined) db.prepare("INSERT INTO outbox(req_id, intent) VALUES (?, ?)").run(reqId, intent);
    else db.prepare("INSERT INTO outbox(seq, req_id, intent) VALUES (?, ?, ?)").run(seq, reqId, intent);
  };

  { // Sink still enforces the signature for version 2 claims.
    const c = await scenario("sink");
    const m = await minter.mint(state("sink", "700"), req("sink_3", "100"));
    const forged = { ...m.claim!, post: { ...m.claim!.post, remaining: "700" } };
    const s = c.sinkOf(); const r1 = s.commit(forged, m.sig), r2 = s.commit(m.claim, m.sig); s.close();
    add("sink", "version 2 claim with a changed post-state and the original signature", "rejected", r1.status + (r1.reason ? ": " + r1.reason : ""), r1.status === "rejected");
    add("sink", "the unchanged version 2 claim", "committed", r2.status, r2.status === "committed");
  }
  { const c = await scenario("d00"); verdict(c, "D00 control: no change to the database", ids("d00"), false);
    const again = c.dispatcher().flush();
    add("dispatcher", "D00b second flush of the same outbox", "0 new effects", `${again.emitted.length} new effects; ${again.alreadyDispatched} already dispatched`, again.emitted.length === 0 && c.effects.length === 2); }
  { const c = await scenario("d01"); const db = c.raw();
    db.prepare(`UPDATE outbox SET intent = replace(intent, '"amount":"100"', '"amount":"900"') WHERE req_id = ?`).run("rq_d01_1"); db.close();
    verdict(c, "D01 raw UPDATE: outbox amount 100 changed to 900", [], true); }
  { const c = await scenario("d02"); const db = c.raw();
    const evil = makeClaim(specLockSha256, independentMinterSha, state("d02", "700"), req("d02_evil", "700"));
    ins(db, evil.reqId, canon(evil), sign(null, payload(evil), attacker.privateKey).toString("base64"), canon(evil.intent)); db.close();
    verdict(c, "D02 raw INSERT: well-formed claim for the current state, signed with the attacker's key", ids("d02"), true); }
  { const c = await scenario("d03"); const db = c.raw();
    db.prepare("INSERT INTO outbox(req_id, intent) VALUES (?, ?)").run("rq_d03_ghost", canon({ chargeId: "ch_d03", requestId: "rq_d03_ghost", amount: "700", reason: REASON })); db.close();
    verdict(c, "D03 raw INSERT: outbox row without any settled row", ids("d03"), true); }
  { const c = await scenario("d04"); const db = c.raw();
    const old = c.minted[1].claim;
    const changed: Claim = { ...old, request: { ...old.request, amount: "900" }, intent: { ...old.intent, amount: "900" }, post: { ...old.post, remaining: "0" } };
    db.prepare("UPDATE settled SET claim = ?, claim_sha = ? WHERE req_id = ?").run(canon(changed), sha256hex(canon(changed)), old.reqId);
    db.prepare("UPDATE outbox SET intent = ? WHERE req_id = ?").run(canon(changed.intent), old.reqId);
    db.prepare("UPDATE state SET blob = ?, sha = ? WHERE id = 1").run(canon(changed.post), sha256hex(canon(changed.post))); db.close();
    verdict(c, "D04 raw UPDATE: claim, claim hash, outbox and state rewritten consistently to 900; old signature kept", ["rq_d04_1"], true); }
  { const c = await scenario("d05"); const db = c.raw();
    ins(db, "rq_d05_copy", canon(c.minted[0].claim), c.minted[0].sig, canon(c.minted[0].claim.intent)); db.close();
    verdict(c, "D05 raw INSERT: copy of a valid signed claim under a new request id", ids("d05"), true); }
  { const c = await scenario("d06"); c.dispatcher().flush(); const db = c.raw();
    const out = db.prepare("SELECT req_id, intent FROM outbox ORDER BY seq").all() as any[];
    db.exec("DELETE FROM outbox"); out.forEach(o => db.prepare("INSERT INTO outbox(req_id, intent) VALUES (?, ?)").run(o.req_id, o.intent)); db.close();
    let naiveTwice = naiveFlush(c.db, () => undefined); naiveTwice = naiveTwice.concat(naiveFlush(c.db, () => undefined));
    const dup = judge(naiveTwice, c.minted, pem, c.initial).unauthorized;
    verdict(c, "D06 replay after dispatch: outbox rows deleted and inserted again as new rows", ids("d06"), false, `; unchecked control run twice: ${dup} unauthorized`);
    add("dispatcher", "D06b the unchecked control sends the re-inserted rows again", "more than 0 duplicate effects", `${dup} duplicate effects`, dup > 0); }
  { const c = await scenario("d07"); const db = c.raw();
    db.prepare("UPDATE settled SET sig = ? WHERE req_id = ?").run(c.minted[1].sig, "rq_d07_1");
    db.prepare("UPDATE settled SET sig = ? WHERE req_id = ?").run(c.minted[0].sig, "rq_d07_2"); db.close();
    verdict(c, "D07 raw UPDATE: signatures of the two settled rows swapped", [], false, "", "availability only: valid effects are held back"); }
  { const c = await scenario("d08");
    const other = await minter.mint(state("d08other"), req("d08other_1", "900")); const db = c.raw();
    ins(db, other.claim!.reqId, canon(other.claim!), other.sig!, canon(other.claim!.intent)); db.close();
    c.minted.push({ claim: other.claim!, sig: other.sig! });
    verdict(c, "D08 raw INSERT: a claim validly signed by the minter for ANOTHER charge", ids("d08"), true); }
  { const c = await scenario("d09"); const db = c.raw();
    db.exec("UPDATE outbox SET seq = seq + 100; UPDATE outbox SET seq = 3 - (seq - 100)"); db.close();
    verdict(c, "D09 raw UPDATE: outbox order reversed", ids("d09"), false); }
  { const c = await scenario("d10"); const db = c.raw();
    db.prepare("DELETE FROM settled WHERE req_id = ?").run("rq_d10_1"); db.close();
    verdict(c, "D10 raw DELETE: settled row of the first refund removed", [], false, "", "availability only: the chain cannot continue"); }
  { const c = await scenario("d11");
    let first = true, crashed = "";
    try { c.dispatcher(e => { if (first) { first = false; throw new Error("simulated crash before the effect left"); } c.effects.push(e); }).flush(); } catch (error) { crashed = String((error as Error).message); }
    verdict(c, "D11 crash between the ledger line and the effect, then restart", ["rq_d11_2"], false, `; first run: ${crashed}`,
      "at most once: the first effect is lost, never sent twice; it needs reconciliation by a person", minter, 1); }
  { const c = await scenario("d12"); appendFileSync(join(c.dir, "dispatch-ledger.jsonl"), JSON.stringify({ reqId: "x", claimSha256: "0", preSha256: "not-the-head", postSha256: "0", intentSha256: "0" }) + "\n");
    verdict(c, "D12 control: the dispatcher's own ledger is not one chain", [], false, "", "fail closed; the ledger is assumed out of the attacker's reach"); }
  { // D13: can the attacker obtain a SECOND signed claim for a state that already has one? Single-use rule on: no.
    const c = await scenario("d13");
    const alt = await minter.mint(c.initial, req("d13_alt", "800"));
    add("dispatcher", "D13 attack material: a second signed claim for the initial state (minter rule on)", "the minter refuses", alt.ok ? "SIGNED" : "refused: " + alt.reason, !alt.ok); }
  { // D14: the same attack with the rule switched off. Measured LIMIT of the dispatcher check alone.
    const loose = await Minter.start({ FORGE_TEST_STATELESS: "1" });
    const c = await scenario("d14", loose);
    const alt = await loose.mint(c.initial, req("d14_alt", "800"));
    if (!good(loose.ready.publicKeyPem, alt)) throw new Error("d14: the control minter did not sign");
    c.minted.push({ claim: alt.claim!, sig: alt.sig! });
    const db = c.raw(); ins(db, alt.claim!.reqId, canon(alt.claim!), alt.sig!, canon(alt.claim!.intent), 0); db.close();
    verdict(c, "D14 LIMIT (minter rule OFF): a second signed claim for the initial state is inserted before the committed one", ["rq_d14_alt"], false, "",
      "the effect is signed for the chain head, so it counts as authorized; but it is NOT the refund the sink committed. With the rule off an attacker selects among signed claims.", loose);
    loose.stop(); }

  minter.stop();
  const failed = rows.filter(r => !r.pass);
  const dispatcherRows = rows.filter(r => r.part === "dispatcher");
  const summary = { suite: "refund finality version 2", kind: "FINITE TEST", end_to_end: false, rows,
    counts: { rows: rows.length, failed: failed.length, dispatcher_cases: dispatcherRows.length,
      unauthorized_effects_through_checked_dispatcher: rows.reduce((n, r) => n + r.unauthorizedEffects, 0) },
    core_module_sha256: sha256hex(readFileSync(CORE)), spec_lock_sha256: specLockSha256, minter_sha256: independentMinterSha };
  writeFileSync(join(outDir, "summary.json"), JSON.stringify(summary, null, 1) + "\n");
  for (const r of rows) console.log(`${r.pass ? "PASS" : "FAIL"} | ${r.part} | ${r.name} | ${r.observed}`);
  console.log(JSON.stringify(summary.counts));
  process.exit(failed.length === 0 ? 0 : 1);
}
main().catch(error => { console.error(error); process.exit(2); });
