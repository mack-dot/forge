// Lead 2: an effect that the sink committed and the ledger records, but that was never emitted, and that no later
// output reports. Usage: l2_silent_loss.ts <work> throw|ok
//  throw: the payment adapter (emit) throws for r1 BEFORE it sends anything (e.g. a connection refused).
//         flush() removes the lock in its finally; the next run (a normal retry) reports r1 as alreadyDispatched.
//  ok:    control, emit never throws.
// Exit 1 = a committed refund is never emitted AND the next run's result does not distinguish it (no refused
// entry, no stop, lock gone). Exit 0 = the loss is reported or does not happen.
import { existsSync, readFileSync, realpathSync } from "node:fs";
import { startMinter, world } from "./common";
const [work, mode] = process.argv.slice(2);
(async () => {
  const { m, ids, mint } = await startMinter("off");
  const w = world(work, ids);
  for (const [rid, a] of [["r1", "400"], ["r2", "100"]]) console.log(rid, w.sink.commit(await mint(w.state(), rid, a)).status);
  const sent: string[] = [];
  let first = "";
  try { first = JSON.stringify(w.flush((e: any) => { if (mode === "throw" && e.requestId === "r1") throw new Error("adapter: connection refused (nothing sent)"); sent.push(e.requestId); })); }
  catch (e) { first = "flush threw: " + (e as Error).message; }
  console.log("run 1:", first);
  console.log("lock left after run 1:", existsSync(realpathSync(w.ledger) + ".lock"));
  const r2 = w.flush((e: any) => sent.push(e.requestId));
  console.log("run 2 (retry):", JSON.stringify(r2));
  const r3 = w.flush((e: any) => sent.push(e.requestId));
  console.log("run 3:", JSON.stringify(r3));
  console.log("ledger:", readFileSync(w.ledger, "utf8").trim().split("\n").map(l => JSON.parse(l).requestId).join(","), "; actually sent:", sent.join(","));
  m.stop(); w.sink.close();
  const lost = !sent.includes("r1");
  const silent = r2.refused.length === 0 && r3.refused.length === 0 && r3.alreadyDispatched === 2;
  process.exit(lost && silent ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
