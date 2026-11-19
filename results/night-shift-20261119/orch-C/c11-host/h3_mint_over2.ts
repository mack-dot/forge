// c11-host H3 helper 2: initial state {original 1000, remaining R}: mint refunds of 1000 in a chain until refused.
// Prints the total signed; exit 1 if the total signed exceeds original (1000).
import { join } from "node:path";
const [root, corePath, R] = process.argv.slice(2);
const { MinterClient, propose } = require(join(__dirname, "lib/proposer216.ts"));
(async () => {
  const m = await MinterClient.start(root, corePath, join(root, "spec/refund/spec.lock"), "off");
  let pre: any = { chargeId: "ch_over", original: "1000", remaining: R, refundEnabled: true }, total = 0, last = "";
  for (let i = 0; i < 6; i++) {
    const a = await m.mint(pre, propose(pre, { requestId: "rq_" + i, amount: "1000", reason: "duplicate_charge" }));
    if (!a.ok) { last = a.reason; break; }
    total += 1000; pre = a.token.body.post;
  }
  m.stop(); process.stdout.write(JSON.stringify({ initialRemaining: R, totalSigned: total, stop: last }) + "\n"); process.exit(total > 1000 ? 1 : 0);
})().catch(e => { process.stderr.write(String(e) + "\n"); process.exit(3); });
