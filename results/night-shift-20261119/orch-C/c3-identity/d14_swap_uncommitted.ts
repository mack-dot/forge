// D14 on v6. Threat: a database writer WITHOUT the key + one honest token that the honest minter (single-use off,
// the suite's mode) signed for a pre-state and the sink did NOT commit (stale after a concurrent request).
// The writer replaces the committed row by the uncommitted one and sets the state row to its post-state.
// Checks: the dispatcher emits the uncommitted effect; the RUNNING v6 sink re-audits and keeps serving; a restart serves.
// Exit 1 = an effect the sink never committed is emitted AND the v6 sink accepts the store; 0 = safe.
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { load, fresh, st, MINTER_CORE } from "./lib";
const [root, work] = process.argv.slice(2);
const { E, Sink, Dispatcher, P } = load(root);
fresh(work);
(async () => {
  const m = await P.MinterClient.start(root, MINTER_CORE, join(root, "spec/refund/spec.lock"), "off");
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const s0 = st("ch_D", "1000", "1000"), db = join(work, "d.sqlite");
  const sink = new Sink(db, { ...ids, initialState: s0 }); sink.init(s0);
  const mint = async (pre: any, rid: string, amount: string) => {
    const a = await m.mint(pre, P.propose(pre, { requestId: rid, amount, reason: "duplicate_charge" })); return E.tokenText(a.token); };
  const ta = await mint(s0, "rq_a", "100"), tb = await mint(s0, "rq_b", "700");
  const r: Record<string, any> = { ca: sink.commit(ta).status, cb: sink.commit(tb) };   // tb: stale, rejected
  const w = new DatabaseSync(db), b = JSON.parse(tb);
  w.exec("BEGIN");
  w.prepare("UPDATE settled SET request_id = ?, token = ?, token_sha256 = ? WHERE request_id = 'rq_a'").run("rq_b", tb, E.sha256hex(tb));
  w.prepare("UPDATE outbox SET request_id = ?, intent = ? WHERE request_id = 'rq_a'").run("rq_b", E.canon(b.body.intent));
  w.prepare("UPDATE state SET blob = ? WHERE id = 1").run(E.canon(b.body.post));
  w.exec("COMMIT"); w.close();
  const effects: any[] = [];
  new Dispatcher(db, join(work, "led.jsonl"), { ...ids, initialStateSha256: E.stateSha256(s0) }, (_e: any, i: any) => effects.push(i)).flush();
  r.emitted = effects.map(i => i.requestId + ":" + i.amount);
  // the running sink: the next honest request on the (rewritten) stored state
  const pre = JSON.parse(sink.stateBlob());
  r.runningSinkNext = sink.commit(await mint(pre, "rq_c", "100")); r.reaudits = sink.reaudits; sink.close();
  try { new Sink(db, { ...ids, initialState: s0 }).close(); r.restart = "served"; } catch (e) { r.restart = "REFUSED"; }
  m.stop();
  console.log(JSON.stringify(r));
  const uncommitted = effects.some(i => i.requestId === "rq_b");
  process.exit(uncommitted && r.restart === "served" ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
