// C. Several stores / ledgers, honest minter (single-use off), token replay only (no DB write, no key).
// Usage: ... c_config_identity.ts <root> <work> <case>
//  dup     : two stores configured with the SAME initial charge text (same chargeId, same amounts), each with its own
//            ledger. A token committed on store A is replayed to store B. Exit 1 = two external refunds for one
//            (chargeId, requestId).  Threat: token replay + a deployment that gives one charge two stores (config).
//  reinit  : the operator deletes the store and re-creates it with the same cfg.initialState; the dispatcher ledger is
//            kept. The old token is replayed. Exit 1 = the old request is emitted a second time.
//  reinitNewLedger : as reinit, and the ledger is also new. Exit 1 = emitted a second time. Threat: config control.
//  twoLedgers : one store, two dispatcher ledgers. Exit 1 = emitted twice. Threat: config control.
import { rmSync } from "node:fs";
import { join } from "node:path";
import { load, fresh, st, MINTER_CORE } from "./lib";
const [root, work, which] = process.argv.slice(2);
const { E, Sink, Dispatcher, P } = load(root);
fresh(work);
(async () => {
  const m = await P.MinterClient.start(root, MINTER_CORE, join(root, "spec/refund/spec.lock"), "off");
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const s0 = st("ch_dup", "1000", "1000"), cfg = { ...ids, initialState: s0 }, dcfg = { ...ids, initialStateSha256: E.stateSha256(s0) };
  const a = await m.mint(s0, P.propose(s0, { requestId: "rq_1", amount: "600", reason: "duplicate_charge" }));
  const tok = E.tokenText(a.token);
  const effects: any[] = [], r: Record<string, any> = { case: which };
  const flush = (db: string, led: string) => new Dispatcher(db, join(work, led), dcfg, (_e: any, i: any) => effects.push(i)).flush();
  const dbA = join(work, "a.sqlite"), dbB = join(work, "b.sqlite");
  let sA = new Sink(dbA, cfg); sA.init(s0); r.commitA = sA.commit(tok).status; sA.close();
  if (which === "dup") {
    const sB = new Sink(dbB, cfg); sB.init(s0); r.commitB = sB.commit(tok).status; sB.close();
    flush(dbA, "ledA.jsonl"); flush(dbB, "ledB.jsonl");
  } else if (which === "reinit" || which === "reinitNewLedger") {
    flush(dbA, "led.jsonl");
    rmSync(dbA, { force: true });
    sA = new Sink(dbA, cfg); sA.init(s0); r.replayAfterReinit = sA.commit(tok).status;
    // the next honest refund on the re-created store (continues the old chain because the replay restored it)
    const pre = JSON.parse(sA.stateBlob()); const b = await m.mint(pre, P.propose(pre, { requestId: "rq_2", amount: "100", reason: "duplicate_charge" }));
    r.next = sA.commit(E.tokenText(b.token)).status; sA.close();
    const d = flush(dbA, which === "reinit" ? "led.jsonl" : "led2.jsonl"); r.refused = d.refused;
  } else if (which === "twoLedgers") {
    flush(dbA, "led1.jsonl"); flush(dbA, "led2.jsonl");
  }
  m.stop();
  r.emitted = effects.map(i => i.chargeId + "/" + i.requestId + ":" + i.amount);
  const n = effects.filter(i => i.requestId === "rq_1").length;
  console.log(JSON.stringify(r));
  process.exit(n >= 2 ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
