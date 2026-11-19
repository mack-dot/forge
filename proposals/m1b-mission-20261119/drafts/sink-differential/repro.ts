// Z4 task 1: the request-id gap, decided by a RUN. NOT a proof.
// Part A: the REAL issuer (ts/refund-finality/minter.ts, unchanged, with the recorded compiled core) is asked to
//         sign transitions whose intent request id differs from the request id.
// Part B: a token whose body.requestId differs from intent.requestId, signed with a TEST key that the sink is
//         configured to trust, is given to the UNCHANGED sink.ts, then to the dispatcher, then to the patched copy.
// Run (cwd = repository): NODE_PATH=<repo>/node_modules node --import tsx repro.ts
import { spawn } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { Dispatcher } from "<HOME>/forge/ts/refund-finality/dispatcher";
import { stateSha256 } from "<HOME>/forge/ts/refund-finality/encoding";
import { ROOT, Z, body, cfg, loadSink, refund, tokenText } from "./lib";

async function issuerPart() {
  const p = spawn("/opt/homebrew/bin/node", ["--import", "tsx", "ts/refund-finality/minter.ts", Z + "/model.cjs", "spec/refund/spec.lock", "off"],
    { cwd: ROOT, stdio: ["pipe", "pipe", "inherit"] });
  const lines = createInterface({ input: p.stdout! });
  const queue: string[] = []; let wake: (() => void) | null = null;
  lines.on("line", l => { queue.push(l); wake?.(); });
  const next = async () => { while (!queue.length) await new Promise<void>(r => (wake = r)); return JSON.parse(queue.shift()!); };
  const ready = await next();
  const S0 = { chargeId: "ch_z4", original: "1000", remaining: "1000", refundEnabled: true };
  const ask = async (id: number, req: string, intentReq: string, amount = 100n) => {
    const r = refund(S0, req, amount, "returned_item", intentReq);
    p.stdin!.write(JSON.stringify({ id, pre: S0, transition: { request: { requestId: req, amount: amount.toString(), reason: "returned_item" }, post: r.post, intent: r.intent } }) + "\n");
    return next();
  };
  const out = {
    issuer_ready: { checkerSha256: ready.checkerSha256, specLockSha256: ready.specLockSha256 },
    control_equal_ids: await ask(1, "rq_A", "rq_A"),
    mismatch_intent_other: await ask(2, "rq_A", "rq_B"),
    mismatch_intent_empty: await ask(3, "rq_A", ""),
    mismatch_case_only: await ask(4, "rq_A", "RQ_A"),
    mismatch_trailing_space: await ask(5, "rq_A", "rq_A "),
  };
  p.stdin!.end();
  const code = await new Promise<number>(r => p.on("close", c => r(c ?? -1)));
  const summary: any = { issuer_exit: code };
  for (const [k, v] of Object.entries(out)) summary[k] = k === "issuer_ready" ? v : (v as any).ok ? { ok: true, body_requestId: (v as any).token.body.requestId, intent_requestId: (v as any).token.body.intent.requestId } : v;
  return summary;
}

function sinkPart(sinkName: string) {
  const dir = mkdtempSync(join(Z, "db", "repro-" + sinkName + "-"));
  const Sink = loadSink(sinkName);
  const S0 = { chargeId: "ch_z4", original: "1000", remaining: "1000", refundEnabled: true };
  const sink = new Sink(join(dir, "sink.sqlite"), cfg);
  sink.init(S0);
  // The mismatched token: body.requestId = rq_body, intent.requestId = rq_victim. Validly signed by the trusted (test) key.
  const r1 = refund(S0, "rq_body", 100n, "returned_item", "rq_victim");
  const t1 = tokenText(body(S0, "rq_body", r1.post, r1.intent));
  const c1 = sink.commit(t1);
  // An honest token for request rq_victim on the new state (as the real issuer would sign it).
  const r2 = refund(r1.post, "rq_victim", 100n);
  const t2 = tokenText(body(r1.post, "rq_victim", r2.post, r2.intent));
  const c2 = sink.commit(t2);
  const emitted: any[] = [];
  let flush: any;
  try {
    flush = new Dispatcher(join(dir, "sink.sqlite"), join(dir, "ledger.jsonl"), { ...cfg, initialStateSha256: stateSha256(S0) },
      (e, i) => emitted.push({ effect_requestId: e.requestId, intent_requestId: i.requestId, amount: i.amount })).flush();
  } catch (e) { flush = { error: String(e) }; }
  const res = {
    sink: sinkName, commit_mismatched: c1, commit_honest_for_intent_id: c2,
    state: JSON.parse(sink.stateBlob()),
    settled: sink.settled().map((r: any) => ({ request_id: r.request_id, intent_requestId: JSON.parse(r.token).body.intent.requestId })),
    outbox: sink.outbox().map((r: any) => ({ request_id: r.request_id, intent_requestId: JSON.parse(r.intent).requestId, amount: JSON.parse(r.intent).amount })),
    audit: sink.audit(),
    dispatcher_emitted: emitted, dispatcher_refused: flush.refused ?? flush,
  };
  sink.close();
  return res;
}

(async () => {
  const report = { issuer: await issuerPart(), real: sinkPart("real"), patched: sinkPart("patched-reqid") };
  writeFileSync(Z + "/results/repro.json", JSON.stringify(report, null, 1));
  console.log(JSON.stringify(report, null, 1));
  // Test of task 3: "the sink must reject a token whose body.requestId differs from intent.requestId, with 0 effects".
  const pass = (r: any) => r.commit_mismatched.status === "rejected" && r.outbox.every((o: any) => o.request_id === o.intent_requestId);
  console.log("TEST reqid-equality: real sink.ts", pass(report.real) ? "PASS" : "FAIL", "| patched copy", pass(report.patched) ? "PASS" : "FAIL");
  process.exit(pass(report.patched) && !pass(report.real) ? 0 : 1);
})();
