// d-reqid: a handful of SINGLE runs against one sink copy. A TEST, not a proof.
// Usage: node --import tsx single_runs.ts <copy dir> <out json>
// Keys: TEST Ed25519 keys generated in this process; the public key is written next to the result.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdtempSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const dir = process.argv[2], outFile = process.argv[3];
// eslint-disable-next-line @typescript-eslint/no-require-imports
const E = require(join(dir, "encoding.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Sink } = require(join(dir, "sink.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Dispatcher } = require(join(dir, "dispatcher.ts"));

const keys = generateKeyPairSync("ed25519");
const publicKeyPem = keys.publicKey.export({ type: "spki", format: "pem" }) as string;
const cfg = { publicKeyPem, specLockSha256: E.sha256hex("d-reqid test spec lock"), checkerSha256: E.sha256hex("d-reqid test checker") };
type S = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
const tok = (pre: S, requestId: string, post: S, intent: any) => {
  const body = { domain: E.DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256,
    preStateSha256: E.stateSha256(pre), requestId, post, intent };
  return E.canon({ body, signature: sign(null, E.signedBytes(body), keys.privateKey).toString("base64") });
};
const dec = (s: S, a: number): S => ({ ...s, remaining: String(Number(s.remaining) - a) });
const intent = (c: string, r: string, a: number, why = "returned_item") => ({ chargeId: c, requestId: r, amount: String(a), reason: why });

const work = mkdtempSync(join(__dirname, "db", "run-"));
const db = join(work, "sink.sqlite");
const sink = new Sink(db, cfg);
const S0: S = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
sink.init(S0);
const steps: any[] = [];
let cur = S0;
const step = (name: string, text: string, post: S) => {
  const r = sink.commit(text); steps.push({ name, result: r });
  if (r.status === "committed") cur = post;
};
// 1. mismatched: body rq_body, intent rq_victim
const p1 = dec(cur, 100); step("mismatch body=rq_body intent=rq_victim", tok(cur, "rq_body", p1, intent("ch_1", "rq_victim", 100)), p1);
// 2. honest token for the victim's id on the current state
const p2 = dec(cur, 100); step("honest rq_victim", tok(cur, "rq_victim", p2, intent("ch_1", "rq_victim", 100)), p2);
// 3. zero-amount token
const p3 = dec(cur, 0); step("zero amount rq_zero", tok(cur, "rq_zero", p3, intent("ch_1", "rq_zero", 0, "duplicate_charge")), p3);
// 4. charge id not bound: intent for another charge (ids match)
const p4 = dec(cur, 50); step("intent.chargeId=ch_other", tok(cur, "rq_cx", p4, intent("ch_other", "rq_cx", 50)), p4);
// 5. post.chargeId changed (intent bound to ch_1)
const p5 = { ...dec(cur, 10), chargeId: "ch_renamed" }; step("post.chargeId=ch_renamed", tok(cur, "rq_px", p5, intent("ch_1", "rq_px", 10)), p5);
// 6. exact replay of the honest token text (must not commit again)
steps.push({ name: "replay of a committed text", result: sink.commit(tok(S0, "rq_victim", dec(S0, 100), intent("ch_1", "rq_victim", 100))) });

const outbox = sink.outbox().map((o: any) => ({ request_id: o.request_id, intent_requestId: JSON.parse(o.intent).requestId, intent_chargeId: JSON.parse(o.intent).chargeId, amount: JSON.parse(o.intent).amount }));
const ids = outbox.map((o: any) => o.intent_requestId);
const emitted: any[] = []; let flush: any;
try {
  flush = new Dispatcher(db, join(work, "ledger.jsonl"), { ...cfg, initialStateSha256: E.stateSha256(S0) },
    (e: any, i: any) => emitted.push({ effect_requestId: e.requestId, intent_requestId: i.requestId, chargeId: i.chargeId, amount: i.amount })).flush();
} catch (e) { flush = { error: String(e) }; }
const report = {
  copy: dir, node: process.version, steps, state: JSON.parse(sink.stateBlob()),
  settled: sink.settled().map((r: any) => r.request_id), outbox,
  outbox_intent_ids_distinct: new Set(ids).size === ids.length,
  outbox_intent_ids_all_settled: ids.every((i: string) => sink.settled().some((r: any) => r.request_id === i)),
  audit: sink.audit(), dispatcher_emitted: emitted, dispatcher_refused: flush.refused ?? flush,
};
sink.close();
writeFileSync(outFile, JSON.stringify(report, null, 1));
writeFileSync(outFile.replace(/\.json$/, ".pub.pem"), publicKeyPem);
console.log(JSON.stringify({ copy: dir.split("/").pop(), steps: steps.map(s => [s.name, s.result.status, s.result.reason ?? ""]),
  distinct: report.outbox_intent_ids_distinct, all_settled: report.outbox_intent_ids_all_settled, audit: report.audit, emitted: emitted.length }));
