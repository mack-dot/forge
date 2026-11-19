// r-reqid: ONE single run. A TEST, not a proof. TEST Ed25519 keys only, generated here.
// Scenario: a store written by the UNCHANGED sink (gap token) is later served by the PATCHED sink and
// the PATCHED dispatcher. Mode "flushed": the unchanged dispatcher dispatched the gap row before the
// upgrade. Mode "pending": it did not.
// Usage: node --import tsx upgrade_run.ts <d-reqid copies dir> <mode> <out json>
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdtempSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const copies = process.argv[2], mode = process.argv[3], outFile = process.argv[4];
const E = require(join(copies, "unchanged", "encoding.ts"));
const OldSink = require(join(copies, "unchanged", "sink.ts")).Sink;
const OldDisp = require(join(copies, "unchanged", "dispatcher.ts")).Dispatcher;
const NewSink = require(join(copies, "patched-reqid", "sink.ts")).Sink;
const NewDisp = require(join(copies, "dispatcher-reqid", "dispatcher.ts")).Dispatcher;
const keys = generateKeyPairSync("ed25519");
const publicKeyPem = keys.publicKey.export({ type: "spki", format: "pem" }) as string;
const cfg = { publicKeyPem, specLockSha256: E.sha256hex("r-reqid test spec lock"), checkerSha256: E.sha256hex("r-reqid test checker") };
type S = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
const tok = (pre: S, requestId: string, post: S, intent: any) => {
  const body = { domain: E.DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256,
    preStateSha256: E.stateSha256(pre), requestId, post, intent };
  return E.canon({ body, signature: sign(null, E.signedBytes(body), keys.privateKey).toString("base64") });
};
const dec = (s: S, a: number): S => ({ ...s, remaining: String(Number(s.remaining) - a) });
const intent = (r: string, a: number) => ({ chargeId: "ch_1", requestId: r, amount: String(a), reason: "returned_item" });
const work = mkdtempSync(join(__dirname, "db", "run-"));
const db = join(work, "sink.sqlite"), ledger = join(work, "ledger.jsonl");
const S0: S = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
const dcfg = { ...cfg, initialStateSha256: E.stateSha256(S0) };
const emitted: any[] = [];
const em = (who: string) => (e: any, i: any) => emitted.push({ who, row_request_id: e.requestId, intent_requestId: i.requestId, amount: i.amount });
const out: any = { mode, node: process.version, steps: [] };
const s1 = new OldSink(db, cfg); s1.init(S0);
const p1 = dec(S0, 100);
out.steps.push(["old sink: gap token body=rq_body intent=rq_victim", s1.commit(tok(S0, "rq_body", p1, intent("rq_victim", 100)))]);
s1.close();
if (mode === "flushed") out.steps.push(["old dispatcher flush", new OldDisp(db, ledger, dcfg, em("old")).flush()]);
const s2 = new NewSink(db, cfg);
const p2 = dec(p1, 100);
out.steps.push(["new sink: honest rq_victim on the current state", s2.commit(tok(p1, "rq_victim", p2, intent("rq_victim", 100)))]);
out.audit_new_sink = s2.audit();
out.outbox = s2.outbox().map((o: any) => ({ row: o.request_id, intent_requestId: JSON.parse(o.intent).requestId }));
s2.close();
try { out.steps.push(["new dispatcher flush", new NewDisp(db, ledger, dcfg, em("new")).flush()]); }
catch (e) { out.steps.push(["new dispatcher flush", { error: String(e) }]); }
out.emitted = emitted;
out.emitted_for_rq_victim = emitted.filter(e => e.intent_requestId === "rq_victim").length;
writeFileSync(outFile, JSON.stringify(out, null, 1));
console.log(JSON.stringify({ mode, emitted_for_rq_victim: out.emitted_for_rq_victim, emitted }));
