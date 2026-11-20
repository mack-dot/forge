// Regression for OWNER DECISION D-1 (c), task h-key: the allowlist configuration rules (core/store.ts keyRingOf).
// (1) the OLD single pin {publicKeyPem} = an allowlist of ONE active key: a store made with it opens with
//     {issuerKeys: [A active]} and with {publicKeyPem: A, issuerKeys: [A active]} (the same h_0: entry 0 = genesis key),
//     and a new token of A commits under the list form (CONTROL).
// (2) refused configurations (sink AND dispatcher refuse to start): a wrong keyId for a key; the same key twice; a retired
//     entry without verifyUpToSeq; an active entry WITH verifyUpToSeq; an unknown status; an empty list; publicKeyPem
//     that is not entry 0; a non-Ed25519 key; neither field.
// (3) the genesis is bound to entry 0: a list with ANOTHER key first does not open the store (h_0 differs).
// SAFE = exit 0. On f67c5c16: no allowlist -> FAIL.
import { generateKeyPairSync } from "node:crypto";
import { join } from "node:path";
import { active, argv, guard, memKey, retired, sinkKit, verdict } from "./kf_lib";

guard((() => {
  const { root } = argv();
  const K = sinkKit(root), A = memKey(), B = memKey();
  const db = join(K.dir(), "s.sqlite"), r: any = {};
  const s = K.open(db, { publicKeyPem: A.publicKeyPem });
  if (typeof s === "string") verdict(false, { setup: s });
  s.init(K.S0); r.legacyCommit = s.commit(K.tok(K.S0, "rq_1", "100", A)).status; s.close();
  const s2 = K.open(db, { issuerKeys: [active(A)] });
  r.listForm = typeof s2 === "string" ? s2 : s2.commit(K.tok({ ...K.S0, remaining: "900" }, "rq_2", "0", A)).status;
  if (typeof s2 !== "string") s2.close();
  const s3 = K.open(db, { publicKeyPem: A.publicKeyPem, issuerKeys: [active(A), retired(B, 0)] });
  r.bothFieldsConsistent = typeof s3 === "string" ? s3 : "STARTED"; if (typeof s3 !== "string") s3.close();
  const s4 = K.open(db, { issuerKeys: [active(B), active(A)] });
  r.otherGenesisKeyFirst = typeof s4 === "string" ? "refused" : "STARTED"; if (typeof s4 !== "string") s4.close();
  const rsa = generateKeyPairSync("rsa", { modulusLength: 1024 }).publicKey.export({ type: "spki", format: "pem" }) as string;
  const bad: Record<string, any> = {
    wrongKeyId: { issuerKeys: [{ ...active(A), keyId: B.keyId }] },
    duplicate: { issuerKeys: [active(A), active(A)] },
    retiredWithoutBound: { issuerKeys: [active(A), { keyId: B.keyId, publicKeyPem: B.publicKeyPem, status: "retired" }] },
    activeWithBound: { issuerKeys: [{ ...active(A), verifyUpToSeq: 3 }] },
    unknownStatus: { issuerKeys: [{ ...active(A), status: "revoked" }] },
    emptyList: { issuerKeys: [] },
    pemNotEntry0: { publicKeyPem: B.publicKeyPem, issuerKeys: [active(A), active(B)] },
    notEd25519: { publicKeyPem: rsa },
    neither: {},
  };
  r.refused = {};
  let allRefused = true;
  for (const [name, pin] of Object.entries(bad)) {
    const fresh = join(K.dir(), name + ".sqlite"), x = K.open(fresh, pin);
    if (typeof x !== "string") x.close();
    const d = K.flush(fresh, join(K.dir(), name + ".jsonl"), pin, A.publicKeyPem);
    const ok = typeof x === "string" && d.alarm !== undefined;
    r.refused[name] = ok ? "sink and dispatcher refused" : "NOT REFUSED (sink " + (typeof x === "string" ? "refused" : "started") + ", dispatcher " + (d.alarm ? "refused" : "ran") + ")";
    allRefused &&= ok;
  }
  verdict(r.legacyCommit === "committed" && r.listForm === "committed" && r.bothFieldsConsistent === "STARTED" && r.otherGenesisKeyFirst === "refused" && allRefused, r);
})());
