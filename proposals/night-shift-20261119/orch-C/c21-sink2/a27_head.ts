// C-ATT-27 re-attack on 88ae6cbf: CommitResult.head, cfg.onHead (before COMMIT), cfg.outsideHead {committed, pending}.
// The host here follows B's FRESHNESS RULE exactly (outside store = a JSON file in <work>/outside.json, written+synced).
// Usage: a27_head.ts <work> <mode>
//  stale-z1del : expectedHead (h1 field) = a STALE head (count 1); writer deletes zero row z (chain recomputed) while the sink
//                is stopped; restart; retry z. B: "kept, stated". Exit 1 if z commits twice.
//  iface-z1del : same with outsideHead {committed: fresh head}. Exit 1 if z commits twice.
//  crash-pre   : child sink is SIGKILLed INSIDE onHead (pending persisted, COMMIT not run). Restart with {committed, pending}
//                (+ Sink.recover if a -journal is left). Exit 1 if an acknowledged row is lost or the store is not one of the
//                outside heads, or the honest restart path cannot serve.
//  crash-post  : child sink is SIGKILLed right AFTER COMMIT returned (before the host promotes). Then the writer rolls the
//                store back to `committed` (deletes the pending row). Restart; the client retries the pending request.
//                Exit 1 if the pending refund is emitted twice or an acknowledged row is lost.
//  two-writers : sink A (outsideHead + onHead) and sink B (no anchor, same file). B commits. A's next commit must halt; A's
//                restart with the fresh outside head must refuse. Exit 1 if A commits on top of B's row silently.
//  reenter     : onHead calls sink.audit() (a host that "checks" the store inside onHead). Exit 1 if commit() reports
//                committed while the row is not in the store, or the store holds a row the host never got a head for.
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync, openSync, fsyncSync, closeSync, writeSync } from "node:fs";
import { join } from "node:path";
import { kit, hostile, delRow, out, st, ids, short, Sink, S0 } from "./lib";
const [work, mode, child] = process.argv.slice(2);
const OUT = join(work, "outside.json");
const persist = (o: any) => { const fd = openSync(OUT + ".tmp", "w"); writeSync(fd, JSON.stringify(o)); fsyncSync(fd); closeSync(fd); require("node:fs").renameSync(OUT + ".tmp", OUT); };
const outside = () => JSON.parse(readFileSync(OUT, "utf8"));
// ---- child mode: re-create the same key from a saved PKCS8 so the parent can verify
if (child === "child") {
  const { createPrivateKey, createPublicKey, sign } = require("node:crypto");
  const E = require(require("./lib").ROOT + "/ts/refund-finality/encoding.ts");
  const pk = createPrivateKey(readFileSync(join(work, "key.pem"), "utf8"));
  const cfg0 = JSON.parse(readFileSync(join(work, "cfg.json"), "utf8"));
  const o = outside();
  const cfg = { ...cfg0, outsideHead: o.pending ? { committed: o.committed, pending: o.pending } : { committed: o.committed },
    onHead: (next: any) => { persist({ ...outside(), pending: next }); if (process.env.KILL === "pre") process.kill(process.pid, "SIGKILL"); } };
  const s = new Sink(join(work, "sink.sqlite"), cfg);
  const pre = JSON.parse(s.stateBlob());
  const body = { domain: E.DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: E.stateSha256(pre),
    requestId: "rx", post: { ...pre, remaining: (BigInt(pre.remaining) - 200n).toString() }, intent: { chargeId: pre.chargeId, requestId: "rx", amount: "200", reason: "duplicate_charge" } };
  const t = E.canon({ body, signature: sign(null, E.signedBytes(body), pk).toString("base64") });
  writeFileSync(join(work, "rx.token"), t);
  const r = s.commit(t);
  if (process.env.KILL === "post") process.kill(process.pid, "SIGKILL");
  if (r.status === "committed") persist({ committed: r.head });
  process.exit(0);
}
const K = kit(work);
const L: any = { mode };
// host helper: a sink following the freshness rule
const hostOpen = (extra: any = {}) => {
  const o = outside();
  return K.open({ outsideHead: o.pending ? { committed: o.committed, pending: o.pending } : { committed: o.committed },
    onHead: (next: any) => persist({ ...outside(), pending: next }), ...extra });
};
const hostCommit = (s: any, t: string) => { const r = s.commit(t); if (r.status === "committed") persist({ committed: r.head }); return r; };
persist({ committed: { count: 0, chainHash: K.h0 } });
let sink: any = hostOpen(); if (typeof sink === "string") { out({ sink }); process.exit(3); }
sink.init(K.cfg.initialState);
L.c1 = hostCommit(sink, K.tok(st(sink), "r1", "600")).status; const stale = sink.head();
const zt = K.tok(st(sink), "z", "0");
L.c2 = hostCommit(sink, zt).status;
L.c3 = hostCommit(sink, K.tok(st(sink), "r2", "100")).status;
L.f = K.flush({ newLedgerH0: K.h0, expectedHead: outside().committed });
const acked = ids(K.db);
let defect = false;
if (mode === "stale-z1del" || mode === "iface-z1del") {
  sink.close();
  L.applied = hostile(K.db, delRow("z"), true);
  const s2: any = mode === "stale-z1del" ? K.open({ expectedHead: stale }) : hostOpen();
  L.restart = typeof s2 === "string" ? s2.slice(0, 200) : "serves";
  if (typeof s2 !== "string") { L.retryZ = s2.commit(K.tok(st(s2), "z", "0")); s2.close(); }
  L.outbox = ids(K.db);
  defect = L.retryZ?.status === "committed";
} else if (mode === "crash-pre" || mode === "crash-post") {
  sink.close();
  writeFileSync(join(work, "key.pem"), K.privateKey.export({ type: "pkcs8", format: "pem" }) as string);
  const { onHead, outsideHead, ...cfg0 } = K.cfg as any; writeFileSync(join(work, "cfg.json"), JSON.stringify(cfg0));
  const r = spawnSync(process.execPath, ["--no-warnings", "--import", "tsx", __filename, work, mode, "child"], { env: { ...process.env, KILL: mode === "crash-pre" ? "pre" : "post" }, encoding: "utf8", timeout: 60000 });
  L.child = { status: r.status, signal: r.signal, err: (r.stderr || "").slice(0, 200) };
  L.outsideAfterCrash = outside(); L.companions = ["-journal", "-wal", "-shm"].filter(c => existsSync(K.db + c));
  if (mode === "crash-post") {
    // the attacker (file writer) rolls the store back to `committed` (deletes the not-yet-promoted row rx)
    L.applied = hostile(K.db, delRow("rx"), true);
  }
  let s2: any = hostOpen(); L.restart1 = typeof s2 === "string" ? s2.slice(0, 200) : "serves";
  if (typeof s2 === "string" && L.companions.includes("-journal")) {
    try { const o = outside(); L.recover = Sink.recover(K.db, { ...K.cfg, outsideHead: o.pending ? { committed: o.committed, pending: o.pending } : { committed: o.committed } }, join(work, "op.log")); } catch (e) { L.recover = short(e); }
    s2 = hostOpen(); L.restart2 = typeof s2 === "string" ? s2.slice(0, 200) : "serves";
  }
  if (typeof s2 !== "string") {
    L.headAtStart = s2.head();
    const rx = readFileSync(join(work, "rx.token"), "utf8");
    L.clientRetryRx = hostCommit(s2, rx);   // the client never got an answer: it retries the SAME token
    L.next = hostCommit(s2, K.tok(st(s2), "r3", "10")).status;
    s2.close();
  }
  L.outbox = ids(K.db);
  L.flush2 = K.flush({ expectedHead: outside().committed });
  L.effects = K.effects.map((e: any) => e.requestId); L.paid = K.paid();
  const lost = acked.some(a => !L.outbox.includes(a));
  const dup = new Set(L.effects).size !== L.effects.length;
  defect = lost || dup || L.paid > 1000 || (L.restart2 ?? L.restart1) !== "serves";
} else if (mode === "two-writers") {
  const B: any = K.open();
  L.bCommit = B.commit(K.tok(JSON.parse(B.stateBlob()), "rb", "50")).status; B.close();
  const r = hostCommit(sink, K.tok(st(sink), "ra", "50")); L.aCommit = r;
  sink.close();
  const s2 = hostOpen(); L.aRestart = typeof s2 === "string" ? s2.slice(0, 160) : "serves"; if (typeof s2 !== "string") s2.close();
  L.outbox = ids(K.db);
  defect = r.status === "committed";
} else if (mode === "reenter") {
  sink.close();
  let s2: any; let seen: any = null;
  s2 = K.open({ outsideHead: { committed: outside().committed }, onHead: (next: any) => { seen = { next, audit: s2.audit() }; persist({ ...outside(), pending: next }); } });
  const r = s2.commit(K.tok(st(s2), "r4", "10")); L.commit = r; L.seen = seen;
  if (r.status === "committed") persist({ committed: r.head });
  L.after = s2.commit(K.tok(st(s2), "r5", "10"));
  s2.close();
  L.outbox = ids(K.db);
  const inStore = L.outbox.includes("r4");
  defect = (r.status === "committed") !== inStore;
}
L.defect = defect; out(L);
process.exit(defect ? 1 : 0);
