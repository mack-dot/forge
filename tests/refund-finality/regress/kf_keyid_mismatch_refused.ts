// Regression for OWNER DECISION D-1 (c), task h-key: a token whose key_id names key A but whose signature is made by
// key B is refused, also when BOTH keys are pinned and active, and a key id changed after signing is refused (the key
// id is inside the signed bytes). Pin [A active, B active].
// (1) keyId A, signed by B over the bytes with keyId A -> rejected.
// (2) a valid token of B (keyId B), keyId field changed to A, signature kept -> rejected.
// (3) a valid token of A (keyId A), keyId field changed to B, signature kept -> rejected.
// (4) keyId A, signed by an UNPINNED key D -> rejected.
// CONTROL: a valid token of A and one of B (amount 0) commit. SAFE = exit 0. On f67c5c16 -> FAIL.
import { join } from "node:path";
import { active, argv, guard, memKey, sinkKit, verdict } from "./kf_lib";

guard((() => {
  const { root } = argv();
  const K = sinkKit(root), A = memKey(), B = memKey(), D = memKey();
  const db = join(K.dir(), "s.sqlite");
  const s = K.open(db, { issuerKeys: [active(A), active(B)] });
  if (typeof s === "string") verdict(false, { setup: s });
  s.init(K.S0);
  const swapId = (text: string, keyId: string) => { const o = JSON.parse(text); o.keyId = keyId; return K.E.canon(o); };
  const st = (x: any) => x.status + (x.reason ? ": " + x.reason : "");
  const r: any = {
    namesA_signedByB: st(s.commit(K.tok(K.S0, "rq_1", "100", B, A.keyId))),
    tokenOfB_idChangedToA: st(s.commit(swapId(K.tok(K.S0, "rq_2", "100", B), A.keyId))),
    tokenOfA_idChangedToB: st(s.commit(swapId(K.tok(K.S0, "rq_3", "100", A), B.keyId))),
    namesA_signedByUnpinnedD: st(s.commit(K.tok(K.S0, "rq_4", "100", D, A.keyId))),
  };
  r.controlA = st(s.commit(K.tok(K.S0, "rq_a", "100", A)));
  r.controlBzero = st(s.commit(K.tok({ ...K.S0, remaining: "900" }, "rq_b", "0", B)));
  s.close();
  r.rows = K.rows(db);
  const neg = ["namesA_signedByB", "tokenOfB_idChangedToA", "tokenOfA_idChangedToB", "namesA_signedByUnpinnedD"].every(k => r[k].startsWith("rejected"));
  verdict(neg && r.controlA === "committed" && r.controlBzero === "committed" && r.rows.join() === "rq_a,rq_b", r);
})());
