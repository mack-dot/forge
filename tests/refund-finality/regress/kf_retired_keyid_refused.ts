// Regression for OWNER DECISION D-1 (rotation), task h-key: the key id of a RETIRED key is refused for a NEW commit;
// OLD rows signed by it (seq <= its verifyUpToSeq) still pass the start-up audit and the dispatcher; a row signed by it
// and appended AFTER the retirement (seq > verifyUpToSeq) is refused by the audit and the dispatcher.
// Phase 1, pin [A active]: rq_1 (A) committed (seq 1).
// Phase 2, pin [A retired verifyUpToSeq 1, B active] (the operator's rotation): the sink starts (row 1 still verifies);
//   a NEW token of A -> rejected; CONTROL: a token of B (amount 0) -> committed; the dispatcher sends rq_1 and rq_z.
// Late row: a copy of the store gets rq_late signed by A at seq 3 (written under pin [A active, B active]: a holder of A
//   or an operator error); under the phase-2 pin the sink refuses to start and the dispatcher sends nothing of rq_late.
// SAFE = exit 0. On f67c5c16: no allowlist and no keyId -> FAIL.
import { copyFileSync } from "node:fs";
import { join } from "node:path";
import { active, argv, guard, memKey, retired, sinkKit, verdict } from "./kf_lib";

guard((() => {
  const { root } = argv();
  const K = sinkKit(root), A = memKey(), B = memKey();
  const db = join(K.dir(), "s.sqlite"), r: any = {};
  const p1 = { issuerKeys: [active(A)] }, p2 = { issuerKeys: [retired(A, 1), active(B)] }, pAB = { issuerKeys: [active(A), active(B)] };
  const s1 = K.open(db, p1);
  if (typeof s1 === "string") verdict(false, { setup: s1 });
  s1.init(K.S0);
  r.phase1 = s1.commit(K.tok(K.S0, "rq_1", "100", A)).status; s1.close();
  const s2 = K.open(db, p2);
  if (typeof s2 === "string") verdict(false, { phase2Start: s2, phase1: r.phase1 });
  const pre = { ...K.S0, remaining: "900" };
  const retiredNew = s2.commit(K.tok(pre, "rq_2", "100", A));
  const control = s2.commit(K.tok(pre, "rq_z", "0", B));
  s2.close();
  r.phase2 = { started: true, retiredKeyNewCommit: retiredNew.status + (retiredNew.reason ? ": " + retiredNew.reason : ""), controlZeroByB: control.status, rows: K.rows(db) };
  if (K.ST && typeof K.ST.keyRefusal === "function") {
    const ring = K.ST.keyRingOf(p2), t = JSON.parse(K.tok(pre, "rq_2", "100", A));
    r.phase2.reasonText = { commit: K.ST.keyRefusal(ring, t, { kind: "commit" }), storedSeq1: K.ST.keyRefusal(ring, t, { kind: "stored", seq: 1 }), storedSeq2: K.ST.keyRefusal(ring, t, { kind: "stored", seq: 2 }) };
  }
  r.dispatch = K.flush(db, join(K.dir(), "l.jsonl"), p2, A.publicKeyPem);
  // Late row with the retired key.
  const copy = join(K.dir(), "late.sqlite"); copyFileSync(db, copy);
  const sAB = K.open(copy, pAB);
  r.late = { written: typeof sAB === "string" ? sAB : sAB.commit(K.tok(pre, "rq_late", "50", A)).status };
  if (typeof sAB !== "string") sAB.close();
  const sLate = K.open(copy, p2);
  if (typeof sLate !== "string") sLate.close();
  r.late.sinkUnderPhase2Pin = typeof sLate === "string" ? sLate.slice(0, 140) : "STARTED";
  r.late.dispatcher = K.flush(copy, join(K.dir(), "l2.jsonl"), p2, A.publicKeyPem);
  const pass = r.phase1 === "committed" && retiredNew.status === "rejected" && control.status === "committed" && r.phase2.rows.join() === "rq_1,rq_z" &&
    r.dispatch.alarm === undefined && r.dispatch.emitted.join() === "rq_1,rq_z" &&
    r.late.written === "committed" && typeof sLate === "string" && !r.late.dispatcher.emitted.includes("rq_late") &&
    (r.late.dispatcher.alarm !== undefined || r.late.dispatcher.refused.some((x: string) => x.startsWith("rq_late")));
  verdict(pass, r);
})());
