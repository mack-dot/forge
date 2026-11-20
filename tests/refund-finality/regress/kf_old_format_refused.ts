// Regression for OWNER DECISION D-1 (c), task h-key: a token WITHOUT key_id (the format before D-1: {body, signature},
// signature over the body bytes alone) is refused. NO MIGRATION tonight: a store that holds old-format rows is refused
// at start (the start-up audit cannot decode its tokens) and the dispatcher sends nothing from it. That is the stated
// effect of the format change, checked here, not a defect.
// (1) pin {A}: an old-format token of A (a valid signature over the old signed bytes) -> rejected, 0 rows.
// (2) the same old-format token with a keyId field added (signature over the body alone) -> rejected.
// (3) with <old tree> (third argument): a store written by the OLD sink (rows of A, one of amount 0) -> the new sink
//     refuses to start; the new dispatcher sends nothing.
// CONTROL: a new-format token of A commits. SAFE = exit 0. On f67c5c16: the old format is accepted there -> FAIL.
import { sign } from "node:crypto";
import { join } from "node:path";
import { argv, guard, load, memKey, sinkKit, verdict } from "./kf_lib";

guard((() => {
  const { root, old } = argv();
  const K = sinkKit(root), A = memKey();
  const body = (pre: any, rid: string, amount: string) => ({ domain: K.E.DOMAIN, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64),
    preStateSha256: K.E.stateSha256(pre), requestId: rid, post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() },
    intent: { chargeId: pre.chargeId, requestId: rid, amount, reason: "duplicate_charge" } });
  const oldTok = (b: any) => K.E.canon({ body: b, signature: sign(null, Buffer.from(K.E.canon(b), "utf8"), A.privateKey).toString("base64") });
  const db = join(K.dir(), "s.sqlite");
  const s = K.open(db, { publicKeyPem: A.publicKeyPem });
  if (typeof s === "string") verdict(false, { setup: s });
  s.init(K.S0);
  const st = (x: any) => x.status + (x.reason ? ": " + x.reason : "");
  const b1 = body(K.S0, "rq_old", "100");
  const r: any = { oldFormat: st(s.commit(oldTok(b1))) };
  const withId = JSON.parse(oldTok(b1)); withId.keyId = A.keyId;
  r.oldSignatureWithKeyIdAdded = st(s.commit(K.E.canon(withId)));
  r.control = st(s.commit(K.tok(K.S0, "rq_new", "100", A)));
  s.close();
  r.rows = K.rows(db);
  let pass = r.oldFormat.startsWith("rejected") && r.oldSignatureWithKeyIdAdded.startsWith("rejected") && r.control === "committed" && r.rows.join() === "rq_new";
  if (old !== undefined) {
    const O = load(old);
    const odb = join(K.dir(), "old.sqlite");
    const os = new O.SK.Sink(odb, { publicKeyPem: A.publicKeyPem, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: K.S0 });
    os.init(K.S0);
    const w = [os.commit(oldTok(b1)).status, os.commit(oldTok(body({ ...K.S0, remaining: "900" }, "rq_old_zero", "0"))).status];
    os.close();
    const ns = K.open(odb, { publicKeyPem: A.publicKeyPem });
    if (typeof ns !== "string") ns.close();
    const d = K.flush(odb, join(K.dir(), "l.jsonl"), { publicKeyPem: A.publicKeyPem }, A.publicKeyPem);
    r.oldStore = { writtenByOldSink: w, newSink: typeof ns === "string" ? ns.slice(0, 140) : "STARTED", newDispatcher: d };
    pass &&= w.join() === "committed,committed" && typeof ns === "string" && d.emitted.length === 0;
  } else r.oldStore = "NOT RUN (no <old tree> argument)";
  verdict(pass, r);
})());
