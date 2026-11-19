// a6_fsize.ts <root> <issuer.cjs> <keep list, comma>
// C-ATT-22 ported, REAL short writes by the kernel (not a wrapped writeSync). Environment fact found here: on this macOS,
// RLIMIT_FSIZE is NOT enforced for an O_APPEND write into a NON-EMPTY file (the check uses the fd offset 0), so the
// limit can cut only the FIRST ledger line. Each case: a fresh store, r1 committed, an EMPTY ledger; the dispatcher child
// runs under RLIMIT_FSIZE = keep bytes (fsize.py, SIGXFSZ ignored); then two normal runs N1, N2.
// SAFE: if the limited run emitted r1, the ledger must hold r1's complete intent line; r1 is never emitted twice;
// unless the limited run emitted r1, N1 emits it once; N2 emits nothing. Exit 1 = a violation.
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { argv, guard, world } from "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1/tests/refund-finality/regress/d_lib";
const keeps = (process.argv[4] ?? "100,300,450").split(",").map(Number);
const run = (args: string[], limit: number | null) => new Promise<string>(ok => {
  const node = [process.execPath, "--no-warnings", "--import", "tsx", ...args];
  const p = limit === null ? spawn(node[0], node.slice(1), { stdio: ["ignore", "pipe", "pipe"] }) : spawn("/usr/bin/python3", ["-I", join(__dirname, "fsize.py"), String(limit), ...node], { stdio: ["ignore", "pipe", "pipe"] });
  let o = ""; p.stdout.on("data", d => { o += d; }); p.stderr.on("data", d => { o += "[stderr]" + String(d).slice(0, 160); }); p.on("exit", (c, s) => ok(o.trim().slice(0, 330) + ` (exit ${c} ${s ?? ""})`));
});
guard((async () => {
  const { root, core } = argv();
  const rep: any[] = []; let bad = false;
  for (const keep of keeps) {
    const S0 = { chargeId: "ch_a6", original: "1000", remaining: "1000", refundEnabled: true };
    const w = await world(root, core, S0);
    const ctl = join(w.dir, "ctl"), effects = join(w.dir, "effects.jsonl"), dcfgFile = join(w.dir, "dcfg.json");
    mkdirSync(ctl); writeFileSync(effects, ""); writeFileSync(dcfgFile, JSON.stringify(w.dcfg));
    const child = (name: string) => [join(__dirname, "c_child.ts"), root, w.db, w.ledger, dcfgFile, effects, name, ctl, ""];
    const t1 = await w.mint(S0, "r1", "300"); w.commit(t1.text);
    const lim = await run(child("L"), keep);
    const led = existsSync(w.ledger) ? readFileSync(w.ledger, "utf8") : "";
    const lockF = readdirSync(w.dir).filter(f => /\.lock|witness/.test(f)).map(f => f + "=" + readFileSync(join(w.dir, f), "utf8").slice(0, 60));
    const afterLim = readFileSync(effects, "utf8").split("\n").filter(Boolean).length;
    let n1 = await run(child("N1"), null), n2 = await run(child("N2"), null), person = "";
    const lk = join(w.dir, "ledger.jsonl.lock");
    if (/unreadable lock/.test(n2) && existsSync(lk)) {   // a person removes the unreadable lock, then runs again
      const wit = join(w.dir, "sink.sqlite.dispatch-witness.json");
      person = "lock=" + JSON.stringify(readFileSync(lk, "utf8")) + " witness=" + (existsSync(wit) ? JSON.stringify(readFileSync(wit, "utf8")) : "none");
      require("node:fs").unlinkSync(lk); n1 = await run(child("N3"), null); n2 = await run(child("N4"), null);
    }
    const ids = readFileSync(effects, "utf8").split("\n").filter(Boolean).map(l => JSON.parse(l).requestId);
    const firstLineComplete = led.indexOf("\n") > 0;
    const ok = (afterLim === 0 || firstLineComplete) && ids.length <= 1 && (afterLim > 0 || ids.length === 1) && /"emitted":\[\]/.test(n2);
    if (!ok) bad = true;
    rep.push({ keep, person, ledgerAfterLimited: led.length + (firstLineComplete ? " (line complete)" : " (torn)"), files: lockF, limited: lim, n1, n2: n2.slice(0, 200), effects: ids, ok });
    w.stop();
  }
  console.log(JSON.stringify(rep, null, 1)); console.log(bad ? "FAIL" : "PASS"); process.exit(bad ? 1 : 0);
})());
