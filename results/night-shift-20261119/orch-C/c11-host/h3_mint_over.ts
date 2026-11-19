// c11-host H3 helper: does the minter sign a refund of 3000 at a pre-state {original 1000, remaining 5000}?
// Usage: node --import tsx h3_mint_over.ts <target root> <issuer core> ; prints the answer; exit 1 if a token is issued.
import { join } from "node:path";
const [root, corePath] = process.argv.slice(2);
const { MinterClient, propose } = require(join(__dirname, "lib/proposer216.ts"));
(async () => {
  const m = await MinterClient.start(root, corePath, join(root, "spec/refund/spec.lock"), "off");
  const pre = { chargeId: "ch_over", original: "1000", remaining: "5000", refundEnabled: true };
  const a = await m.mint(pre, propose(pre, { requestId: "rq_over", amount: "3000", reason: "duplicate_charge" }));
  m.stop(); process.stdout.write(JSON.stringify({ ok: a.ok, reason: a.reason }) + "\n"); process.exit(a.ok ? 1 : 0);
})().catch(e => { process.stderr.write(String(e) + "\n"); process.exit(3); });
