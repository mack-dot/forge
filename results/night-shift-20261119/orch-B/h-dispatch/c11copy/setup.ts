// c11-host setup: throwaway minter (216dfbe2 client), a fresh sink store (init s0), configs, tokens.
// Usage: node --import tsx setup.ts <target root> <issuer core .cjs> <work dir> <plan>
// plan "zero-full": t0 = amount 0 at s0 (rq_zero), t1 = amount 1000 (== remaining) at s0 (rq_full).
// plan "two": t0 = 400 at s0 (rq_a), t1 = 600 at s0-400 (rq_b).
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const [root, corePath, work, plan] = process.argv.slice(2);
const E = require(join(root, "ts/refund-finality/encoding.ts"));
const { Sink } = require(join(root, "ts/refund-finality/sink.ts"));
// h-dispatch copy: the proposer of the tree under test; dispatcher config carries newLedgerH0 (as suite.ts does).
const { MinterClient, propose } = require(join(root, "ts/refund-finality/proposer.ts"));
const { genesisOf } = require(join(root, "ts/refund-finality/core/store.ts"));
(async () => {
  rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
  const m = await MinterClient.start(root, corePath, join(root, "spec/refund/spec.lock"), "off");
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const s0 = { chargeId: "ch_host", original: "1000", remaining: "1000", refundEnabled: true };
  const cfg = { ...ids, initialState: s0 };
  writeFileSync(join(work, "sink-config.json"), JSON.stringify(cfg));
  writeFileSync(join(work, "sink-config-noinit.json"), JSON.stringify(ids));
  writeFileSync(join(work, "disp-config.json"), JSON.stringify({ ...ids, initialStateSha256: E.stateSha256(s0), newLedgerH0: genesisOf(E.canon(s0), ids.specLockSha256, ids.checkerSha256, ids.publicKeyPem) }));
  const db = join(work, "sink.sqlite"); const sink = new Sink(db, cfg); sink.init(s0); sink.close();
  const mint = async (pre: any, rid: string, amount: string) => {
    const a = await m.mint(pre, propose(pre, { requestId: rid, amount, reason: "duplicate_charge" }));
    if (!a.ok) throw new Error("mint refused: " + a.reason); return E.tokenText(a.token);
  };
  if (plan === "two") {
    writeFileSync(join(work, "t0.token"), await mint(s0, "rq_a", "400"));
    writeFileSync(join(work, "t1.token"), await mint({ ...s0, remaining: "600" }, "rq_b", "600"));
  } else {
    writeFileSync(join(work, "t0.token"), await mint(s0, "rq_zero", "0"));
    writeFileSync(join(work, "t1.token"), await mint(s0, "rq_full", "1000"));
  }
  m.stop();
  process.stdout.write("setup ok\n"); process.exit(0);
})().catch(e => { process.stderr.write(String(e && e.stack) + "\n"); process.exit(3); });
