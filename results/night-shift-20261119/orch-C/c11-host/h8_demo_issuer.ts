// c11-host H8: the v6 minter started with a module that has no IssueBytes2 export (as demo_gauntlet.py act 2 does):
// what does it answer for a valid and an out-of-policy proposal? Prints both; exit 1 if ANY token is issued (unsafe), 0 if it fails closed.
import { join } from "node:path";
const [root, corePath] = process.argv.slice(2);
const { MinterClient, propose } = require(join(__dirname, "lib/proposer216.ts"));
(async () => {
  const m = await MinterClient.start(root, corePath, join(root, "spec/refund/spec.lock"), "off");
  const pre = { chargeId: "ch_demo", original: "1000", remaining: "600", refundEnabled: true };
  const good = await m.mint(pre, propose(pre, { requestId: "rq_ok", amount: "100", reason: "returned_item" }));
  const bad = await m.mint(pre, propose(pre, { requestId: "rq_over", amount: "601", reason: "returned_item" }));
  m.stop(); process.stdout.write(JSON.stringify({ ready: true, good, bad }) + "\n"); process.exit(good.ok || bad.ok ? 1 : 0);
})().catch(e => { process.stderr.write("start failed: " + String(e) + "\n"); process.exit(0); });
