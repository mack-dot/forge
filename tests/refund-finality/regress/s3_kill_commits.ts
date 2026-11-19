// Regression C-ATT-33 (h-sink3), part 3: REAL kills. A child process commits refunds in a loop through a host that follows
// the FRESHNESS RULE of sink.ts (onHead -> persist pending; "committed" -> persist committed, THEN acknowledge); the parent
// SIGKILLs it at a random time (start-up, audit, inside a write transaction, between COMMIT and the acknowledgement), many
// short rounds. After each kill the parent runs the DOCUMENTED procedure: start with cfg.outsideHead = the persisted heads;
// if refused because of a companion file, Sink.recover with the same cfg; start again; the host promotes pending to
// committed when the served head is pending.
// PASS: every round's leftover state is served after the procedure; the served head equals the persisted committed head
// (= the last acknowledged head) or the pending head (the unacknowledged commit); no acknowledged request id is missing.
// Also reported (INFORMATION): the journal class after each kill, and how often Sink.recover WITHOUT an outside head (on a
// copy) refuses (a torn live file: the stated cost of the C-ATT-34 depth rule).
// HEAVY (a kill run): it refuses to start unless S3_HEAVY_OK=1 (exit 2: NOT RUN). The orchestrator runs it in a window:
// orch-B/h-sink3/heavy_kill_NOT_RUN.sh. Bounded: at most S3_ROUNDS (default 30) rounds and S3_SECONDS (default 50) s.
// Usage: S3_HEAVY_OK=1 node --import tsx tests/refund-finality/regress/s3_kill_commits.ts <treeRoot> [<compiledIssuerModule>]
import { spawn } from "node:child_process";
import { closeSync, copyFileSync, existsSync, fsyncSync, mkdirSync, openSync, readFileSync, renameSync, rmSync, writeSync } from "node:fs";
import { join } from "node:path";
import { argv, guard, kit, tempDir, verdict } from "./s_lib";

const full = (e: unknown): string => String((e as Error)?.message ?? e);
const durable = (p: string, text: string) => { const t = p + ".tmp"; const fd = openSync(t, "w"); try { writeSync(fd, text); fsyncSync(fd); } finally { closeSync(fd); } renameSync(t, p); };
const appendDurable = (p: string, text: string) => { const fd = openSync(p, "a"); try { writeSync(fd, text); fsyncSync(fd); } finally { closeSync(fd); } };
const [, , , mode, dirArg, roundArg] = process.argv;
const S0 = { chargeId: "ch_kill", original: "1000000000000000", remaining: "1000000000000000", refundEnabled: true };

if (mode === "--child") {
  guard((() => {
    const { root } = argv();
    const { sign, createPrivateKey } = require("node:crypto");   // eslint-disable-line @typescript-eslint/no-require-imports
    const E = require(join(root, "ts/refund-finality/encoding.ts"));   // eslint-disable-line @typescript-eslint/no-require-imports
    const { Sink } = require(join(root, "ts/refund-finality/sink.ts"));   // eslint-disable-line @typescript-eslint/no-require-imports
    const cfg = JSON.parse(readFileSync(join(dirArg, "cfg.json"), "utf8")), pk = createPrivateKey(readFileSync(join(dirArg, "key.pem"), "utf8"));
    const outside = join(dirArg, "outside.json"), acks = join(dirArg, "acks.jsonl");
    const anchor = JSON.parse(readFileSync(outside, "utf8"));
    const s = new Sink(join(dirArg, "sink.sqlite"), { ...cfg, outsideHead: anchor, onHead: (h: any) => durable(outside, JSON.stringify({ committed: anchor.committed, pending: h })) });
    for (let i = 0; ; i++) {
      const pre = JSON.parse(s.stateBlob()), rid = "k" + roundArg + "_" + i, amount = i % 2 === 0 ? "0" : "1";
      const body = { domain: E.DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: E.stateSha256(pre), requestId: rid,
        post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() }, intent: { chargeId: pre.chargeId, requestId: rid, amount, reason: "duplicate_charge" } };
      const r = s.commit(E.canon({ body, signature: sign(null, E.signedBytes(body), pk).toString("base64") }));
      if (r.status !== "committed") { process.stderr.write("child: " + JSON.stringify(r) + "\n"); process.exit(4); }
      anchor.committed = r.head; delete anchor.pending;
      durable(outside, JSON.stringify({ committed: r.head }));          // persist committed, THEN acknowledge
      appendDurable(acks, JSON.stringify({ rid, head: r.head }) + "\n");
    }
  })());
} else guard((async () => {
  const { root } = argv();
  if (process.env.S3_HEAVY_OK !== "1") { console.log("NOT RUN: a kill run (heavy); set S3_HEAVY_OK=1 in a heavy window"); process.exit(2); }
  const K = kit(root, S0);
  const dir = tempDir(), db = join(dir, "sink.sqlite"), outside = join(dir, "outside.json"), acks = join(dir, "acks.jsonl");
  // The child signs with its own throwaway key (exported here); the sink config pins its public key.
  const { generateKeyPairSync } = require("node:crypto");   // eslint-disable-line @typescript-eslint/no-require-imports
  const kp = generateKeyPairSync("ed25519");
  const cfg = { ...K.cfg, publicKeyPem: kp.publicKey.export({ type: "spki", format: "pem" }) };
  durable(join(dir, "cfg.json"), JSON.stringify(cfg)); durable(join(dir, "key.pem"), kp.privateKey.export({ type: "pkcs8", format: "pem" }) as string);
  const genesis = K.SK.genesisOf(K.E.canon(S0), cfg.specLockSha256, cfg.checkerSha256, cfg.publicKeyPem);
  { const s = new K.SK.Sink(db, cfg); s.init(S0); s.close(); }
  durable(outside, JSON.stringify({ committed: { count: 0, chainHash: genesis } }));
  const maxRounds = Number(process.env.S3_ROUNDS ?? 30), maxMs = 1000 * Number(process.env.S3_SECONDS ?? 50), t0 = Date.now();
  const rounds: any[] = []; const classes: Record<string, number> = {}; let noAnchorRefused = 0, failures = 0, total = 0;
  const side = join(dir, "side"); mkdirSync(side);
  for (let k = 0; k < maxRounds && Date.now() - t0 < maxMs; k++) {
    const c = spawn(process.execPath, ["--no-warnings", "--import", "tsx", __filename, root, "--child", dir, String(k)], { stdio: ["ignore", "ignore", "pipe"] });
    let err = ""; c.stderr.on("data", d => { err += String(d); });
    await new Promise(r => setTimeout(r, 700 + Math.floor(Math.random() * 1500)));
    c.kill("SIGKILL"); await new Promise(r => c.on("exit", r));
    total++;
    const jc: string = typeof K.ST.classifyJournal === "function" ? K.ST.classifyJournal(db).kind : existsSync(db + "-journal") ? "present (no classifier)" : "none"; classes[jc] = (classes[jc] ?? 0) + 1;
    // INFORMATION: Sink.recover without an outside head, on a copy.
    if (jc !== "none") {
      rmSync(side, { recursive: true, force: true }); mkdirSync(side);
      copyFileSync(db, join(side, "sink.sqlite")); copyFileSync(db + "-journal", join(side, "sink.sqlite-journal"));
      try { K.SK.Sink.recover(join(side, "sink.sqlite"), cfg, join(side, "op.log")); } catch { noAnchorRefused++; }
    }
    // The documented procedure.
    const anchor = JSON.parse(readFileSync(outside, "utf8"));
    const ackList = existsSync(acks) ? readFileSync(acks, "utf8").split("\n").filter(l => l.length > 0).map(l => JSON.parse(l)) : [];
    const r: any = { k, journal: jc, child: err.slice(-200) };
    let s: any;
    try { s = new K.SK.Sink(db, { ...cfg, outsideHead: anchor }); r.start1 = "serves"; } catch (e) {
      r.start1 = full(e);
      if (/companion file/.test(r.start1)) { try { r.recover = K.SK.Sink.recover(db, { ...cfg, outsideHead: anchor }, join(dir, "op.log")).reason; } catch (e2) { r.recover = full(e2); } }
      try { s = new K.SK.Sink(db, { ...cfg, outsideHead: anchor }); r.start2 = "serves"; } catch (e3) { r.start2 = full(e3); }
    }
    if (s === undefined) { r.ok = false; failures++; rounds.push(r); break; }
    const h = s.head(), ids = new Set(s.settled().map((x: any) => x.request_id));
    const lastAck = ackList.length > 0 ? ackList[ackList.length - 1].head : { count: 0, chainHash: genesis };
    const same = (a: any, b: any) => a !== undefined && a.count === b.count && a.chainHash === b.chainHash;
    const missing = ackList.filter(a => !ids.has(a.rid)).map(a => a.rid);
    r.head = h.count; r.acked = ackList.length; r.missing = missing;
    r.ok = missing.length === 0 && (same(anchor.committed, h) || same(anchor.pending, h)) && (same(lastAck, h) || same(anchor.pending, h)) && s.audit().length === 0;
    s.close();
    durable(outside, JSON.stringify({ committed: h }));   // the host promotes the served head (committed or pending)
    if (!r.ok) failures++;
    if (!r.ok || rounds.length < 8 || jc !== "none") rounds.push(r);
    if (!r.ok) break;
  }
  verdict(failures === 0 && total > 0, { rounds: total, seconds: Math.round((Date.now() - t0) / 1000), journalClasses: classes, noAnchorRecoverRefused: noAnchorRefused, failures, sample: rounds.slice(-12) });
})());
