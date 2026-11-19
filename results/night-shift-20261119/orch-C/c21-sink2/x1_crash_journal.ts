// NEW finding candidate (c21): an honest crash DURING a write transaction (before COMMIT) leaves a NON-hot -journal (zero
// magic: SQLite with synchronous=FULL writes the journal magic only at the commit's journal sync). SQLite ignores such a
// journal, but the h-sink2 sink refuses to start while ANY -journal exists, and the documented operator step Sink.recover
// refuses too ("the journal is still present after the rollback"): the store is stuck although it is intact.
// Attacker: NONE (a crash). Also reachable by a party that can only create a file next to the database.
// Usage: x1_crash_journal.ts <work> onhead      : the child is SIGKILLed inside cfg.onHead (deterministic; B's crash window
//                                                "crash before COMMIT -> store = committed -> starts").
//        x1_crash_journal.ts <work> kill <N>    : NO onHead; the child commits in a loop and is SIGKILLed after a random
//                                                delay; N rounds (N <= 60); counts rounds that leave the store stuck.
//        x1_crash_journal.ts <work> planted     : a create-only party writes a 512-byte all-zero <db>-journal.
//        x1_crash_journal.ts <work> control     : no crash.
// Exit 1 = the honest restart path (start, then Sink.recover, then start) cannot serve an intact store (defect); 0 = safe.
import { spawn, spawnSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { kit, out, short, Sink, st, E } from "./lib";
const [work, mode, nArg, child] = process.argv.slice(2);
if (child === "child") {
  const { createPrivateKey, sign } = require("node:crypto");
  const pk = createPrivateKey(readFileSync(join(work, "key.pem"), "utf8"));
  const cfg0 = JSON.parse(readFileSync(join(work, "cfg.json"), "utf8"));
  const cfg = mode === "onhead" ? { ...cfg0, onHead: () => process.kill(process.pid, "SIGKILL") } : cfg0;
  const s = new Sink(join(work, "sink.sqlite"), cfg);
  for (let i = 0; ; i++) {
    const pre = JSON.parse(s.stateBlob()), rid = "k" + process.pid + "_" + i;
    const body = { domain: E.DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: E.stateSha256(pre),
      requestId: rid, post: { ...pre }, intent: { chargeId: pre.chargeId, requestId: rid, amount: "0", reason: "duplicate_charge" } };
    const r = s.commit(E.canon({ body, signature: sign(null, E.signedBytes(body), pk).toString("base64") }));
    if (r.status !== "committed") { process.stderr.write("child: " + JSON.stringify(r) + "\n"); process.exit(4); }
  }
}
const K = kit(work);
const L: any = { mode };
const s: any = K.open(); s.init(K.cfg.initialState);
L.c1 = s.commit(K.tok(st(s), "r1", "100")).status; L.headBefore = s.head(); s.close();
writeFileSync(join(work, "key.pem"), K.privateKey.export({ type: "pkcs8", format: "pem" }) as string);
writeFileSync(join(work, "cfg.json"), JSON.stringify(K.cfg));
const tryServe = (): any => {
  const r: any = {};
  let a: any = K.open(); r.start1 = typeof a === "string" ? a.slice(0, 120) : "serves";
  if (typeof a === "string") {
    try { r.recover = Sink.recover(K.db, K.cfg, join(work, "op.log")).reason; } catch (e) { r.recover = short(e).slice(0, 120); }
    a = K.open(); r.start2 = typeof a === "string" ? a.slice(0, 120) : "serves";
  }
  if (typeof a !== "string") { r.audit = a.audit(); r.head = a.head(); a.close(); }
  r.ok = typeof a !== "string";
  return r;
};
const firstBytes = () => existsSync(K.db + "-journal") ? readFileSync(K.db + "-journal").subarray(0, 8).toString("hex") : "none";
(async () => {
  if (mode === "control") { L.serve = tryServe(); }
  else if (mode === "planted") { writeFileSync(K.db + "-journal", Buffer.alloc(512)); L.journal = firstBytes(); L.serve = tryServe(); }
  else if (mode === "onhead") {
    const r = spawnSync(process.execPath, ["--no-warnings", "--import", "tsx", __filename, work, "onhead", "0", "child"], { encoding: "utf8", timeout: 60000 });
    L.child = { status: r.status, signal: r.signal }; L.journal = firstBytes(); L.serve = tryServe();
  } else if (mode === "kill") {
    const N = Math.min(60, Number(nArg ?? 20)); let stuck = 0, rounds = 0, other = 0; const samples: any[] = [];
    for (let i = 0; i < N; i++) {
      const c = spawn(process.execPath, ["--no-warnings", "--import", "tsx", __filename, work, "kill", "0", "child"], { stdio: ["ignore", "ignore", "pipe"] });
      await new Promise(r => setTimeout(r, 900 + Math.floor(Math.random() * 400)));
      c.kill("SIGKILL"); await new Promise(r => c.on("exit", r)); rounds++;
      const j = firstBytes(); const sv = tryServe();
      if (!sv.ok) { stuck++; if (samples.length < 2) samples.push({ journal: j, ...sv }); break; }
      else if (j !== "none") other++;
    }
    L.rounds = rounds; L.stuck = stuck; L.samples = samples; L.serve = { ok: stuck === 0 };
  }
  out(L);
  process.exit(L.serve.ok ? 0 : 1);
})().catch(e => { console.error(e); process.exit(3); });
