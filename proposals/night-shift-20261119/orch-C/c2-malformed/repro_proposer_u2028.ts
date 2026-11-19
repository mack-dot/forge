// c2-malformed repro: proposer.ts MinterClient frames the issuer's answers with node:readline, which ALSO
// splits lines at U+2028 and U+2029. JSON.stringify (and canon) does not escape those characters, so a
// LEGITIMATE token whose request id (or charge id) holds U+2028 arrives as two "lines"; JSON.parse throws
// inside the 'line' listener (an uncaught exception in the client process) and the mint never resolves.
// Exit 1 = defect present (legitimate mint not delivered); exit 0 = token delivered and commits.
// Usage: node --import tsx repro_proposer_u2028.ts <target root> <issuer .cjs>
import { join } from "node:path";
const [root, corePath] = process.argv.slice(2);
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { MinterClient, propose } = require(join(root, "ts/refund-finality/proposer.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const E = require(join(root, "ts/refund-finality/encoding.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Sink } = require(join(root, "ts/refund-finality/sink.ts"));
const uncaught: string[] = [];
process.on("uncaughtException", e => { uncaught.push(String(e.message)); });   // record instead of dying, to report
(async () => {
  const m = await MinterClient.start(root, corePath, join(root, "spec/refund/spec.lock"), "off");
  const s0 = { chargeId: "ch_1", original: "100", remaining: "100", refundEnabled: true };
  const rid = process.argv[4] === "control" ? "rq_plain" : "rq a";
  const t = propose(s0, { requestId: rid, amount: "0", reason: "duplicate_charge" });
  if (!E.isTransition(t)) { console.log("not a legitimate input"); process.exit(3); }
  const a = await Promise.race([m.mint(s0, t), new Promise<any>(r => setTimeout(() => r({ ok: false, reason: "TIMEOUT: no answer delivered" }), 8000))]);
  m.stop();
  let commit: any = null;
  if (a.ok) {
    const sink = new Sink(":memory:", { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256, initialState: s0 });
    sink.init(s0); commit = sink.commit(E.tokenText(a.token)); sink.close();
  }
  console.log(JSON.stringify({ requestId: rid, answer: a.ok ? "ok" : a.reason, commit, uncaught }));
  process.exit(a.ok && commit?.status === "committed" && uncaught.length === 0 ? 0 : 1);
})().catch(e => { console.error(e); process.exit(3); });
