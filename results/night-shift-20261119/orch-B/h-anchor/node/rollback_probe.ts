// h-anchor probe: roll back the SINK store (file copy) under an un-rolled-back dispatcher ledger.
// Merged code under test: ts/refund-finality/{sink,dispatcher,encoding}.ts (main = nightshift/B-trust for this dir).
// This script plays an honest issuer with a test key generated in the process (post.remaining = pre.remaining - amount).
import { generateKeyPairSync, sign } from "node:crypto";
import { copyFileSync, mkdtempSync, rmSync, unlinkSync, existsSync } from "node:fs";
import { join } from "node:path";
const SRC = process.argv[2];
const { Sink } = require(SRC + "/sink");
const { Dispatcher } = require(SRC + "/dispatcher");
const { DOMAIN, canon, sha256hex, signedBytes } = require(SRC + "/encoding");
type S = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const pem = publicKey.export({ type: "spki", format: "pem" }).toString();
const LOCK = "a".repeat(64), CHK = "b".repeat(64);
const st = (rem: string, chargeId = "ch_1"): S => ({ chargeId, original: "100", refundEnabled: true, remaining: rem });
function mint(pre: S, rid: string, amount: string): string {
  const post = { ...pre, remaining: String(Number(pre.remaining) - Number(amount)) };
  const intent = { chargeId: pre.chargeId, requestId: rid, amount, reason: "r" };
  const body = { domain: DOMAIN, specLockSha256: LOCK, checkerSha256: CHK, preStateSha256: sha256hex(canon(pre)), requestId: rid, post, intent };
  return canon({ body, signature: sign(null, signedBytes(body), privateKey).toString("base64") });
}
const root = mkdtempSync(join(process.env.HOME || "/tmp", "probe-"));
let n = 0;
function world(init: S, pinned: S) {
  const dir = join(root, "w" + (++n)); require("node:fs").mkdirSync(dir); require("node:fs").mkdirSync(join(dir, "witness"));
  const db = join(dir, "sink.db"), ledger = join(dir, "witness", "ledger.jsonl");
  const sinkCfg = { publicKeyPem: pem, specLockSha256: LOCK, checkerSha256: CHK };
  let sink = new Sink(db, sinkCfg); sink.init(init);
  const sent: string[] = [];
  const disp = new Dispatcher(db, ledger, { publicKeyPem: pem, specLockSha256: LOCK, checkerSha256: CHK, initialStateSha256: sha256hex(canon(pinned)) },
    (e: any) => sent.push(e.requestId + ":" + JSON.parse(e.intent).amount));
  const snap = (name: string) => { sink.close(); copyFileSync(db, join(dir, name)); sink = new Sink(db, sinkCfg); };
  const restore = (name: string) => { sink.close(); for (const x of ["-wal", "-shm"]) if (existsSync(db + x)) unlinkSync(db + x); copyFileSync(join(dir, name), db); sink = new Sink(db, sinkCfg); };
  const flush = () => { const r = disp.flush(); return { emitted: r.emitted.map((e: any) => e.requestId), refused: r.refused.map((x: any) => x.requestId + "(" + x.reason + ")"), already: r.alreadyDispatched }; };
  return { get sink() { return sink; }, snap, restore, flush, sent, ledger };
}
const out = (k: string, v: unknown) => console.log(k.padEnd(34) + JSON.stringify(v));
// A: rollback to a prefix after dispatch, re-commit the dropped token.
{ const w = world(st("100"), st("100")); w.snap("s0");
  const t1 = mint(st("100"), "r1", "10");
  out("A commit r1", w.sink.commit(t1).status); out("A flush 1", w.flush());
  w.restore("s0"); out("A after rollback audit", w.sink.audit()); out("A outbox rows", w.sink.outbox().length);
  out("A re-commit dropped r1", w.sink.commit(t1).status); out("A audit", w.sink.audit());
  out("A flush 2", w.flush()); out("A total effects", w.sent);
  const t2 = mint(st("100"), "r2", "10");          // new honest request minted from the rolled-back pre-state
  w.restore("s0"); out("A2 commit r2 on rolled-back", w.sink.commit(t2).status); out("A2 audit", w.sink.audit());
  out("A2 flush", w.flush());
  const t3 = mint(st("90"), "r3", "5"); out("A2 commit r3", w.sink.commit(t3).status); out("A2 flush r3", w.flush());
  out("A2 total effects", w.sent); }
// B: rollback BEFORE dispatch: the dropped token was never sent.
{ const w = world(st("100"), st("100")); w.snap("s0");
  const t1 = mint(st("100"), "r1", "10"); w.sink.commit(t1); w.restore("s0");
  out("B re-commit", w.sink.commit(t1).status); out("B flush", w.flush());
  out("B flush again", w.flush()); out("B total effects", w.sent); }
// C: forged initial charge (remaining 1000) with tokens signed from it.
{ const w = world(st("1000"), st("100"));
  out("C commit from forged", w.sink.commit(mint(st("1000"), "r1", "500")).status); out("C audit", w.sink.audit());
  out("C flush", w.flush()); out("C total effects", w.sent); }
// D: zero-amount: r1(10), r2(0), r3(5); dispatch; roll the sink back to after r1; re-commit r2 and r3.
{ const w = world(st("100"), st("100"));
  const t1 = mint(st("100"), "r1", "10"), t2 = mint(st("90"), "r2", "0"), t3 = mint(st("90"), "r3", "5");
  w.sink.commit(t1); w.snap("s1"); w.sink.commit(t2); w.sink.commit(t3); out("D flush", w.flush());
  w.restore("s1"); out("D re-commit r3 first (skip r2)", w.sink.commit(t3).status); out("D audit", w.sink.audit());
  out("D flush 2", w.flush()); out("D total effects", w.sent); }
// E (control, ANCHOR-MONOTONE violated): the dispatcher ledger is lost; the sink is unchanged.
{ const w = world(st("100"), st("100"));
  w.sink.commit(mint(st("100"), "r1", "10")); w.flush(); unlinkSync(w.ledger);
  out("E flush after ledger loss", w.flush()); out("E total effects", w.sent); }
rmSync(root, { recursive: true, force: true });
