// Round 2 task 3 (U420): adversarial suite for the refund finality experiment. Real processes, real Ed25519, real SQLite.
// This is a FINITE TEST. It proves nothing universal. Run: node --import tsx run_suite.ts <out-dir>
import { spawn, spawnSync, ChildProcessWithoutNullStreams } from "node:child_process";
import { createPrivateKey, generateKeyPairSync, sign, createHmac } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { resolve, join } from "node:path";
import { createInterface } from "node:readline";
import { ChargeState, Claim, RefundRequest, canon, makeClaim, payload, sha256hex } from "./common";
import { Sink, SinkConfig } from "./sink";

const ROOT = resolve(__dirname, "../..");
const MODEL = join(ROOT, "build/refund-generated/model.cjs");
const SPEC_LOCK = join(ROOT, "spec/refund/spec.lock");
const outDir = resolve(process.argv[2]);
mkdirSync(outDir, { recursive: true });

class MinterClient {
  private next = 1; private waiting = new Map<number, (v: any) => void>();
  ready!: { publicKeyPem: string; specLockSha256: string; minterSha256: string };
  private constructor(readonly child: ChildProcessWithoutNullStreams) {}
  static start(env: Record<string, string> = {}): Promise<MinterClient> {
    const child = spawn(process.execPath, ["--import", "tsx", join(__dirname, "minter.ts"), MODEL, SPEC_LOCK],
      { cwd: ROOT, env: { ...process.env, ...env }, stdio: ["pipe", "pipe", "pipe"] }) as ChildProcessWithoutNullStreams;
    const client = new MinterClient(child);
    return new Promise((done, fail) => {
      child.on("error", fail);
      createInterface({ input: child.stdout }).on("line", line => {
        const msg = JSON.parse(line);
        if (msg.ready) { client.ready = msg; done(client); return; }
        client.waiting.get(msg.id)?.(msg); client.waiting.delete(msg.id);
      });
    });
  }
  mint(claim: unknown): Promise<{ ok: boolean; sig?: string; reason?: string }> {
    const id = this.next++;
    return new Promise(done => { this.waiting.set(id, done); this.child.stdin.write(JSON.stringify({ id, claim }) + "\n"); });
  }
  stop(): void { this.child.stdin.end(); this.child.kill(); }
}

type Row = { name: string; cls: string; expected: string; observed: string; pass: boolean; unauthorized: boolean };
const rows: Row[] = [];
const snapshot = (s: Sink) => ({ sha: s.state().sha, outbox: s.outbox().length });

async function main() {
  const minter = await MinterClient.start();
  const { publicKeyPem, specLockSha256, minterSha256 } = minter.ready;
  // The operator pins the minter hash independently of what the minter reports.
  const independent = sha256hex(Buffer.concat([readFileSync(join(__dirname, "minter.ts")), readFileSync(join(__dirname, "common.ts")), readFileSync(MODEL)]));
  const cfg: SinkConfig = { publicKeyPem, specLockSha256: sha256hex(readFileSync(SPEC_LOCK)), minterSha256: independent };
  const idsAgree = cfg.specLockSha256 === specLockSha256 && cfg.minterSha256 === minterSha256;
  const dbPath = join(outDir, "sink.sqlite");
  if (existsSync(dbPath)) throw new Error("output directory is not fresh");
  const cfgPath = join(outDir, "sink-config.json");
  writeFileSync(cfgPath, JSON.stringify(cfg));
  const sink = new Sink(dbPath, cfg);
  const initial: ChargeState = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
  sink.init(initial);
  const current = (): ChargeState => JSON.parse(sink.state().blob);
  const claimFor = (r: RefundRequest, pre: ChargeState = current()) => makeClaim(cfg.specLockSha256, cfg.minterSha256, pre, r);
  const req = (id: string, amount: string, reason = "duplicate_charge"): RefundRequest => ({ requestId: id, amount, reason });

  // An attack row passes when the stored state and the outbox are exactly as expected afterwards.
  async function attack(name: string, cls: string, run: () => Promise<string> | string, expectDelta = 0) {
    const before = snapshot(sink);
    let observed: string;
    try { observed = await run(); } catch (error) { observed = "exception: " + String((error as Error).message); }
    const after = snapshot(sink);
    const delta = after.outbox - before.outbox;
    const unchanged = delta === 0 && after.sha === before.sha;
    const pass = expectDelta === 0 ? unchanged : delta === expectDelta;
    rows.push({ name, cls, expected: expectDelta === 0 ? "no state change, no effect" : `exactly ${expectDelta} effect`, observed, pass,
      unauthorized: expectDelta === 0 ? !unchanged : delta > expectDelta });
  }
  const show = (r: { status: string; reason?: string }) => r.status + (r.reason ? ": " + r.reason : "");

  // ---- Valid sequence: four authorized refunds settle, one effect each. ----
  const validPlan = [req("rq_1", "100"), req("rq_2", "250", "returned_item"), req("rq_3", "0", "service_not_delivered"), req("rq_4", "150")];
  const settled: { claim: Claim; sig: string }[] = [];
  let validOk = idsAgree;
  for (const r of validPlan) {
    const claim = claimFor(r);
    const m = await minter.mint(claim);
    const res = m.ok ? sink.commit(claim, m.sig) : { status: "rejected", reason: m.reason };
    validOk = validOk && res.status === "committed";
    if (m.ok) settled.push({ claim, sig: m.sig! });
  }
  validOk = validOk && sink.outbox().length === validPlan.length && current().remaining === "500" && sink.audit().length === 0;

  // ---- A. Direct bypass without a valid signature ----
  const fresh = claimFor(req("rq_a1", "10"));
  await attack("commit with an empty signature", "A bypass", () => show(sink.commit(fresh, "")));
  await attack("commit with 64 random bytes", "A bypass", () => show(sink.commit(fresh, Buffer.alloc(64, 7).toString("base64"))));
  await attack("commit with a non-string signature", "A bypass", () => show(sink.commit(fresh, 12345 as any)));
  await attack("valid signature of another claim", "A bypass", () => show(sink.commit(fresh, settled[0].sig)));
  await attack("claim with an extra field", "A bypass", () => show(sink.commit({ ...fresh, extra: "x" }, settled[0].sig)));
  // ---- B. Forgery with everything the sink holds (public key, config, database) ----
  const attackerKeys = generateKeyPairSync("ed25519");
  await attack("signature by an attacker key", "B forgery", () => show(sink.commit(fresh, sign(null, payload(fresh), attackerKeys.privateKey).toString("base64"))));
  await attack("public key bytes used as a private seed", "B forgery", () => {
    const der = Buffer.from(publicKeyPem.replace(/-----[^-]+-----|\s/g, ""), "base64");
    const seed = der.subarray(der.length - 32);
    const fake = createPrivateKey({ key: Buffer.concat([Buffer.from("302e020100300506032b657004220420", "hex"), seed]), format: "der", type: "pkcs8" });
    return show(sink.commit(fresh, sign(null, payload(fresh), fake).toString("base64")));
  });
  await attack("HMAC of the payload under the public key", "B forgery", () =>
    show(sink.commit(fresh, Buffer.concat([createHmac("sha256", publicKeyPem).update(payload(fresh)).digest(), Buffer.alloc(32)]).toString("base64"))));
  await attack("stored signature with one bit flipped", "B forgery", () => {
    const raw = Buffer.from(settled[0].sig, "base64"); raw[5] ^= 1;
    return show(sink.commit(settled[0].claim, raw.toString("base64")));
  });
  await attack("every signature stored in the database tried on a new claim", "B forgery", () => {
    const sigs = (sink.db.prepare("SELECT sig FROM settled").all() as { sig: string }[]).map(r => r.sig);
    return sigs.map(s => sink.commit(fresh, s).status).join(",");
  });
  // ---- C. Replay ----
  await attack("replay of a settled claim, 10 times in one process", "C replay", () =>
    Array.from({ length: 10 }, () => sink.commit(settled[1].claim, settled[1].sig).status).join(","));
  await attack("settled request id with a different amount, old signature", "C replay", () =>
    show(sink.commit({ ...settled[1].claim, request: { ...settled[1].claim.request, amount: "999" } }, settled[1].sig)));
  await attack("settled request id, new validly signed claim", "C replay", async () => {
    const c = claimFor(req("rq_1", "5")); const m = await minter.mint(c);
    return "minter: " + (m.ok ? "signed" : m.reason) + "; sink: " + (m.ok ? show(sink.commit(c, m.sig)) : "not called");
  });
  // ---- D. Stale state ----
  await attack("valid old claim against an advanced state", "D stale", () => show(sink.commit(settled[0].claim, settled[0].sig)));
  await attack("validly signed claim for a stale pre-state", "D stale", async () => {
    const c = claimFor(req("rq_d2", "10"), initial); const m = await minter.mint(c);
    return "minter: " + (m.ok ? "signed" : m.reason) + "; sink: " + (m.ok ? show(sink.commit(c, m.sig)) : "not called");
  });
  // ---- E. Other spec lock, other minter ----
  await attack("valid claim at a sink pinned to another spec lock", "E ids", async () => {
    const c = claimFor(req("rq_e1", "10")); const m = await minter.mint(c);
    const other = new Sink(join(outDir, "other-spec.sqlite"), { ...cfg, specLockSha256: "0".repeat(64) });
    other.init(current()); const r = other.commit(c, m.sig); const n = other.outbox().length; other.close();
    return show(r) + "; other sink effects " + n;
  });
  await attack("valid claim at a sink pinned to another minter hash", "E ids", async () => {
    const c = claimFor(req("rq_e2", "10")); const m = await minter.mint(c);
    const other = new Sink(join(outDir, "other-minter.sqlite"), { ...cfg, minterSha256: "1".repeat(64) });
    other.init(current()); const r = other.commit(c, m.sig); const n = other.outbox().length; other.close();
    return show(r) + "; other sink effects " + n;
  });
  await attack("claim signed by a minter for another spec lock", "E ids", async () => {
    const m2 = await MinterClient.start({ FORGE_TEST_OTHER_SPEC_LOCK: "2".repeat(64) });
    const c = makeClaim("2".repeat(64), cfg.minterSha256, current(), req("rq_e3", "10"));
    const m = await m2.mint(c); m2.stop();
    return "other minter: " + (m.ok ? "signed" : m.reason) + "; sink: " + (m.ok ? show(sink.commit(c, m.sig)) : "not called");
  });
  await attack("claim that names another spec lock, signed by nobody", "E ids", () =>
    show(sink.commit(makeClaim("3".repeat(64), cfg.minterSha256, current(), req("rq_e4", "10")), settled[0].sig)));
  // ---- F. Proposals that the approved refund relation rejects ----
  const refused = async (name: string, claim: unknown) => attack(name, "F spec", async () => {
    const m = await minter.mint(claim);
    const viaSink = show(sink.commit(claim, m.ok ? m.sig : settled[0].sig));
    return "minter: " + (m.ok ? "SIGNED" : "refused (" + m.reason + ")") + "; sink: " + viaSink;
  });
  await refused("refund above the remaining amount", claimFor(req("rq_f1", "501")));
  await refused("refund above the original amount", claimFor(req("rq_f2", "1001")));
  await refused("reason outside the approved set", claimFor(req("rq_f3", "10", "goodwill")));
  await refused("empty request id", claimFor(req("", "10")));
  await refused("refunds disabled in the pre-state", makeClaim(cfg.specLockSha256, cfg.minterSha256, { ...current(), refundEnabled: false }, req("rq_f5", "10")));
  await refused("post-state keeps the full remaining amount", { ...claimFor(req("rq_f6", "10")), post: current() });
  await refused("post-state re-enables a larger remaining amount", { ...claimFor(req("rq_f7", "10")), post: { ...current(), remaining: "999999" } });
  await refused("intent amount larger than the request", (() => { const c = claimFor(req("rq_f8", "10")); return { ...c, intent: { ...c.intent, amount: "400" } }; })());
  await refused("intent for another charge", (() => { const c = claimFor(req("rq_f9", "10")); return { ...c, intent: { ...c.intent, chargeId: "ch_other" } }; })());
  await refused("amount above the money bound", claimFor(req("rq_f10", "9223372036854775808")));
  // ---- G. Tampering after signing; encodings ----
  const good = claimFor(req("rq_g", "20"));
  const goodSig = (await minter.mint(good)).sig!;
  await attack("intent amount changed after signing", "G tamper", () => show(sink.commit({ ...good, intent: { ...good.intent, amount: "200" } }, goodSig)));
  await attack("post-state changed after signing", "G tamper", () => show(sink.commit({ ...good, post: { ...good.post, remaining: "500" } }, goodSig)));
  await attack("request id changed after signing", "G tamper", () => show(sink.commit({ ...good, reqId: "rq_other", request: { ...good.request, requestId: "rq_other" }, intent: { ...good.intent, requestId: "rq_other" } }, goodSig)));
  await attack("amount as a JavaScript number", "G encoding", () => show(sink.commit({ ...good, request: { ...good.request, amount: 20 as any } }, goodSig)));
  await attack("amount beyond 2^53 as a number", "G encoding", () => show(sink.commit({ ...good, request: { ...good.request, amount: 9007199254740993 as any } }, goodSig)));
  await attack("amount with a leading zero", "G encoding", () => show(sink.commit({ ...good, request: { ...good.request, amount: "020" } }, goodSig)));
  await attack("claim with a prototype", "G encoding", () => show(sink.commit(Object.assign(Object.create({ injected: true }), good), goodSig)));
  // ---- H. Concurrency across operating-system processes ----
  const cli = (job: { claim: Claim; sig: string }, tag: string) => {
    const p = join(outDir, `job-${tag}.json`); writeFileSync(p, JSON.stringify(job));
    return new Promise<string>(done => {
      const child = spawn(process.execPath, ["--import", "tsx", join(__dirname, "commit_cli.ts"), dbPath, cfgPath, p], { cwd: ROOT });
      let out = ""; child.stdout.on("data", d => out += d); child.on("close", () => { try { done(JSON.parse(out.trim().split("\n").pop()!).status); } catch { done("no result"); } });
    });
  };
  await attack("one valid claim sent by 10 processes at once", "H concurrency", async () => {
    const statuses = await Promise.all(Array.from({ length: 10 }, (_, i) => cli({ claim: good, sig: goodSig }, "storm" + i)));
    return statuses.sort().join(",");
  }, 1);
  await attack("two different valid claims on one pre-state, two processes", "H concurrency", async () => {
    const a = claimFor(req("rq_h1", "30")), b = claimFor(req("rq_h2", "40"));
    const [ma, mb] = [await minter.mint(a), await minter.mint(b)];
    const statuses = await Promise.all([cli({ claim: a, sig: ma.sig! }, "raceA"), cli({ claim: b, sig: mb.sig! }, "raceB")]);
    return statuses.sort().join(",");
  }, 1);
  const auditBeforeTamper = sink.audit();

  // ---- I. A compromised sink database (NOT prevented; detected by the public-key audit) ----
  const detections: { name: string; detected: boolean; problems: string[] }[] = [];
  const tamper = (name: string, sql: (s: Sink) => void) => {
    const copy = join(outDir, `tamper-${detections.length}.sqlite`);
    sink.db.exec(`VACUUM INTO '${copy.replace(/'/g, "''")}'`);
    const t = new Sink(copy, cfg); sql(t); const problems = t.audit(); t.close();
    detections.push({ name, detected: problems.length > 0, problems: problems.slice(0, 3) });
  };
  tamper("row inserted into settled and outbox without a signature", t => {
    const c = canon(claimFor(req("rq_fake", "400")));
    t.db.prepare("INSERT INTO settled(req_id, claim, claim_sha, sig) VALUES (?, ?, ?, ?)").run("rq_fake", c, sha256hex(c), Buffer.alloc(64).toString("base64"));
    t.db.prepare("INSERT INTO outbox(req_id, intent) VALUES (?, ?)").run("rq_fake", canon(claimFor(req("rq_fake", "400")).intent));
  });
  tamper("stored state overwritten", t => { t.db.prepare("UPDATE state SET blob = ?, sha = ? WHERE id = 1").run(canon(initial), sha256hex(canon(initial))); });
  tamper("outbox intent amount edited", t => { t.db.prepare("UPDATE outbox SET intent = replace(intent, '\"100\"', '\"900\"') WHERE seq = 1").run(); });
  tamper("extra outbox row", t => { t.db.prepare("INSERT INTO outbox(req_id, intent) VALUES ('rq_x', '{}')").run(); });

  const attacks = rows.length;
  const summary = {
    format: "forge-round2-refund-finality-suite/1", end_to_end: false,
    scope: "finite adversarial test of research code; no universal claim",
    ids_agree_with_independent_hashes: idsAgree,
    valid_sequence: { requests: validPlan.length, all_committed_one_effect_each: validOk },
    attacks: { total: attacks, passed: rows.filter(r => r.pass).length, unauthorized_settlements: rows.filter(r => r.unauthorized).length },
    final_state: current(), outbox_length: sink.outbox().length, audit_problems_untampered: auditBeforeTamper,
    sink_database_holds_private_key: false,
    compromised_database: { note: "not prevented by the sink; checked by audit with the public key", cases: detections },
    rows,
  };
  writeFileSync(join(outDir, "summary.json"), JSON.stringify(summary, null, 1) + "\n");
  for (const r of rows) console.log((r.pass ? "PASS" : "FAIL") + " | " + r.cls + " | " + r.name + " | " + r.observed.slice(0, 110));
  for (const d of detections) console.log((d.detected ? "DETECTED" : "MISSED") + " | I tamper | " + d.name);
  console.log(JSON.stringify({ valid: validOk, attacks, passed: summary.attacks.passed, unauthorized: summary.attacks.unauthorized_settlements,
    audit_clean: auditBeforeTamper.length === 0, tamper_detected: detections.filter(d => d.detected).length + "/" + detections.length }));
  minter.stop(); sink.close();
  const ok = validOk && summary.attacks.passed === attacks && summary.attacks.unauthorized_settlements === 0 &&
    auditBeforeTamper.length === 0 && detections.every(d => d.detected);
  process.exit(ok ? 0 : 1);
}
main().catch(error => { console.error(error); process.exit(2); });
