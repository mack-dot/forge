// Regression for OWNER DECISION D-1 (c), task h-key: a token whose key_id is NOT in the pinned allowlist is refused,
// by the sink (new commit), by the start-up audit (stored row) and by the dispatcher's own row check.
// (1) pin {A}: a token of key C, keyId C (a valid signature of C) -> rejected, 0 rows. CONTROL: a token of A -> committed.
// (2) a store written under pin [A, C] (entry 0 = A: the same h_0) holds a row of C; opened with pin {A} alone:
//     the sink refuses to start; the dispatcher with pin {A} sends nothing of that row (alarm or refusal).
//     CONTROL: the dispatcher with pin [A, C] sends both rows.
// SAFE = exit 0. On f67c5c16: the token format has no keyId -> the controls fail -> FAIL.
import { copyFileSync } from "node:fs";
import { join } from "node:path";
import { active, argv, guard, memKey, sinkKit, verdict } from "./kf_lib";

guard((() => {
  const { root } = argv();
  const K = sinkKit(root), A = memKey(), C = memKey();
  const r: any = {};
  const db = join(K.dir(), "s.sqlite");
  const s = K.open(db, { publicKeyPem: A.publicKeyPem });
  if (typeof s === "string") verdict(false, { setup: s });
  s.init(K.S0);
  const unknown = s.commit(K.tok(K.S0, "rq_c", "100", C));
  const good = s.commit(K.tok(K.S0, "rq_a", "100", A));
  s.close();
  r.sink = { unknownKeyId: unknown.status + (unknown.reason ? ": " + unknown.reason : ""), control: good.status, rows: K.rows(db) };
  const both = [active(A), active(C)];
  const db2 = join(K.dir(), "s2.sqlite");
  const s2 = K.open(db2, { issuerKeys: both });
  if (typeof s2 === "string") verdict(false, { setup2: s2 });
  s2.init(K.S0);
  const pre3 = { ...K.S0, remaining: "900" };
  const c1 = s2.commit(K.tok(K.S0, "rq_1", "100", A)).status, c2 = s2.commit(K.tok(pre3, "rq_x", "0", A)).status;
  const c3 = s2.commit(K.tok(pre3, "rq_c3", "50", C)).status;
  s2.close();
  const copy = join(K.dir(), "copy.sqlite"); copyFileSync(db2, copy);
  const reopenA = K.open(db2, { publicKeyPem: A.publicKeyPem });
  if (typeof reopenA !== "string") reopenA.close();
  const dA = K.flush(db2, join(K.dir(), "ledgerA.jsonl"), { publicKeyPem: A.publicKeyPem }, A.publicKeyPem);
  const dBoth = K.flush(copy, join(K.dir(), "ledgerBoth.jsonl"), { issuerKeys: both }, A.publicKeyPem);
  r.stored = { setupCommits: [c1, c2, c3], sinkWithPinA: typeof reopenA === "string" ? reopenA.slice(0, 120) : "STARTED",
    dispatcherPinA: dA, dispatcherPinAC_control: dBoth };
  const pass = unknown.status === "rejected" && good.status === "committed" && r.sink.rows.join() === "rq_a" &&
    c1 === "committed" && c2 === "committed" && c3 === "committed" && typeof reopenA === "string" &&
    !dA.emitted.includes("rq_c3") && (dA.alarm !== undefined || dA.refused.some(x => x.startsWith("rq_c3"))) &&
    dBoth.alarm === undefined && dBoth.emitted.join() === "rq_1,rq_x,rq_c3";
  verdict(pass, r);
})());
