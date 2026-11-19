// a5_claim_race.ts <root> <issuer.cjs> <rows> <rounds> <idkind: long|short>
// APPEND-ATOMIC through the REAL dispatcher: 4 processes with NO common lock race for the same rows at one instant;
// with idkind long every ledger line is about 2.1-2.3 KB (> PIPE_BUF 512, > 1024, < 4096). Repeated <rounds> times on new
// commits. Exit 1 = a request id emitted twice, a total above the original, or a ledger a clean run cannot read.
import { spawn } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { argv, dups, guard, total, verdict, world } from "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1/tests/refund-finality/regress/d_lib";
const [, , , , rowsA, roundsA, kind] = process.argv;
guard((async () => {
  const { root, core } = argv();
  const rows = Number(rowsA), rounds = Number(roundsA);
  const S0 = { chargeId: "ch_a5", original: String(rows * rounds * 10), remaining: String(rows * rounds * 10), refundEnabled: true };
  const w = await world(root, core, S0);
  const effects = join(w.dir, "effects.jsonl"), dcfgFile = join(w.dir, "dcfg.json");
  writeFileSync(effects, ""); writeFileSync(dcfgFile, JSON.stringify(w.dcfg));
  let pre: any = S0; const outs: string[] = []; let k = 0;
  for (let r = 0; r < rounds; r++) {
    for (let i = 0; i < rows; i++, k++) {
      const rid = kind === "long" ? "\u0001".repeat(240) + "_" + k : "r" + k;
      const t = await w.mint(pre, rid, "10"); if (w.commit(t.text) !== "committed") throw new Error("commit failed"); pre = t.post;
    }
    const at = Date.now() + 1200;
    const res = await Promise.all(["A", "B", "C", "D"].map(n => new Promise<string>(ok => {
      const p = spawn(process.execPath, ["--no-warnings", "--import", "tsx", join(__dirname, "a5_child.ts"), root, w.db, w.ledger, dcfgFile, effects, n, String(at)], { stdio: ["ignore", "pipe", "inherit"] });
      let o = ""; p.stdout.on("data", d => { o += d; }); p.on("exit", () => ok(o.trim()));
    })));
    outs.push(res.join(" "));
  }
  console.error("outs", JSON.stringify(outs).slice(0, 600));
  const ledgerBytes = readFileSync(w.ledger).length, maxLine = Math.max(...readFileSync(w.ledger, "utf8").split("\n").map(l => Buffer.byteLength(l)));
  let clean: any = null, err = "";
  try { const r = w.flush(); clean = { emitted: r.emitted.length, refused: r.refused.length, inDoubt: (r.inDoubt ?? []).length, already: r.alreadyDispatched }; } catch (e) { err = (e as Error).message.slice(0, 120); }
  w.stop();
  const eff = readFileSync(effects, "utf8").split("\n").filter(Boolean).map(l => JSON.parse(l)), ids = eff.map((e: any) => e.requestId);
  // A run that loses a race stops; rows it held as "in doubt" are not a defect. The defect is a duplicate or an unreadable ledger.
  verdict(dups(ids).length === 0 && total(eff) <= Number(S0.original) && clean !== null,
    { kind, rows, rounds, effects: ids.length, distinct: new Set(ids).size, byRun: eff.reduce((m: any, e: any) => (m[e.by] = (m[e.by] ?? 0) + 1, m), {}), ledgerBytes, maxLine, clean, err, outs: outs.slice(0, 3) });
})());
