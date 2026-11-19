// c7-minter P3 (client integrity/liveness): MinterClient matches answers by the id field only, and its ids are a
// predictable counter (proposer.ts:23,51). send(body) spreads body AFTER id (proposer.ts:52), so a body key "id"
// overrides the client's id. A co-user of the client (or anyone who can write a line to the minter's stdin)
// that sends a request with the id that the next caller will get makes the next caller A receive a token for
// B's request (A's own token goes to `unmatched`, or B's waiter never resolves).
// Exit 1 = A's promise resolves with a token for another request; 0 = A gets its own token.
import { join } from "node:path";
import { ROOT, CORE, SPEC_LOCK } from "./raw";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { MinterClient, propose } = require(join(ROOT, "ts/refund-finality/proposer.ts"));
(async () => {
  const c = await MinterClient.start(ROOT, CORE, SPEC_LOCK, "off");
  const S = { chargeId: "ch_1", original: "100", remaining: "100", refundEnabled: true };
  const tA = propose(S, { requestId: "rq_A_honest", amount: "7", reason: "duplicate_charge" });
  const tB = propose(S, { requestId: "rq_B_other", amount: "93", reason: "returned_item" });
  // B: the client's first id is 1. B's body carries "id": 1 (the id A will get); B's own waiter is under a later id.
  const pB = c.send({ id: 2, pre: S, transition: tB });        // B's waiter = 1, message id = 2 (spread override)
  const pA = c.mint(S, tA);                                    // A's waiter = 2, message id = 2
  const a = await Promise.race([pA, new Promise(r => setTimeout(() => r({ timeout: true }), 20000))]) as any;
  const b = await Promise.race([pB, new Promise(r => setTimeout(() => r({ timeout: true }), 3000))]) as any;
  c.stop();
  const out = { A_asked: "rq_A_honest", A_got: a.token?.body?.requestId ?? a, A_amount: a.token?.body?.intent?.amount,
    B_resolved: !b.timeout, unmatched: c.unmatched.map((u: any) => u.token?.body?.requestId ?? u.reason) };
  console.log(JSON.stringify(out));
  process.exit(a.ok && a.token.body.requestId !== "rq_A_honest" ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
