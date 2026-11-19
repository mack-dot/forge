// Q. Minter identity. Threat: a caller of the minter (the untrusted proposer side; NO key, NO DB write) who can
// also hand a token text to the sink. Honest minter, single-use off.
// (1) squat: before the host asks, the caller gets a ZERO-amount token for the victim's request id "rq_victim" on the
//     current state and commits it. The host's real refund (100) for rq_victim is then refused for ever.
// (2) the minter signs for a request id already settled in the sink (it has no notion of "open").
// (3) future-state presign: a token for a pre-state the store does not hold yet commits once the store reaches it.
// (4) fake pre-state (remaining above the stored remaining) is signed but never commits.
// Exit 1 = (1) succeeds (the legitimate refund for rq_victim can no longer commit); 0 = safe.
import { join } from "node:path";
import { load, fresh, st, MINTER_CORE } from "./lib";
const [root, work] = process.argv.slice(2);
const { E, Sink, Dispatcher, P } = load(root);
fresh(work);
(async () => {
  const m = await P.MinterClient.start(root, MINTER_CORE, join(root, "spec/refund/spec.lock"), "off");
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const s0 = st("ch_Q", "1000", "1000"), db = join(work, "q.sqlite");
  const sink = new Sink(db, { ...ids, initialState: s0 }); sink.init(s0);
  const mint = async (pre: any, rid: string, amount: string) => {
    const a = await m.mint(pre, P.propose(pre, { requestId: rid, amount, reason: "duplicate_charge" }));
    return a.ok ? E.tokenText(a.token) : null; };
  const r: Record<string, any> = {};
  const squat = await mint(s0, "rq_victim", "0");
  r.squatCommit = sink.commit(squat).status;
  const real = await mint(JSON.parse(sink.stateBlob()), "rq_victim", "100");
  r.realMinted = real !== null; r.realCommit = real ? sink.commit(real) : null;
  r.minterSignsSettledId = (await mint(JSON.parse(sink.stateBlob()), "rq_victim", "50")) !== null;
  const s1 = st("ch_Q", "1000", "900");
  const future = await mint(s1, "rq_future", "200");
  r.futureEarly = sink.commit(future).status;
  r.step = sink.commit(await mint(JSON.parse(sink.stateBlob()), "rq_step", "100")).status;   // s0 -> s1
  r.futureLater = sink.commit(future).status;
  const fake = await mint(st("ch_Q", "5000", "5000"), "rq_fake", "5000");
  r.fakeSigned = fake !== null; r.fakeCommit = fake ? sink.commit(fake) : null;
  sink.close();
  const effects: any[] = [];
  new Dispatcher(db, join(work, "led.jsonl"), { ...ids, initialStateSha256: E.stateSha256(s0) }, (_e: any, i: any) => effects.push(i)).flush();
  r.emitted = effects.map(i => i.requestId + ":" + i.amount);
  m.stop();
  console.log(JSON.stringify(r));
  process.exit(r.squatCommit === "committed" && r.realCommit?.status !== "committed" ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
