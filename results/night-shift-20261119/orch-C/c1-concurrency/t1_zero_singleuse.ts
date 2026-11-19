// F1: minter single-use rule ("on") + an approved zero-amount refund. Honest use only; no attacker.
// Exit 1 = defect present (a legitimate refund after a committed zero-amount refund cannot be minted); 0 = safe.
import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { E, EVID, S0, Sink, minter } from "./lib";
(async () => {
  const work = join(EVID, "work/t1"); rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
  const mode = (process.argv[2] ?? "on") as "on" | "off";
  const { m, ids, mint } = await minter(mode);
  const sink = new Sink(join(work, "s.sqlite"), { ...ids, initialState: S0 }); sink.init(S0);
  const z = await mint(S0, "rq_zero", "0");
  const cz = z.ok ? sink.commit(z.text) : { status: "mint refused: " + z.reason };
  const pre = JSON.parse(sink.stateBlob());
  const a = await mint(pre, "rq_after", "100");
  const ca = a.ok ? sink.commit(a.text) : { status: "mint refused: " + a.reason };
  console.log(JSON.stringify({ zeroCommit: cz, mode, stateUnchangedByZero: E.canon(pre) === E.canon(S0), laterRefund100: ca }));
  sink.close(); m.stop();
  const defect = cz.status === "committed" && ca.status !== "committed";
  console.log(defect ? "DEFECT: after a committed zero-amount refund no further refund can be minted for this charge" : "SAFE");
  process.exit(defect ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
