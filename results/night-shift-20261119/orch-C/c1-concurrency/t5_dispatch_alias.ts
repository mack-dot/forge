// Dispatcher: two flush() runs on one ledger file at once, the second named by an ALIAS of the first's path.
// Run A starts; when A has emitted its first effect, run B starts. Any request id emitted twice = double send.
// Aliases: same, relative, symlink-file, symlink-dir, case (APFS case-insensitive), firmlink (/System/Volumes/Data),
// dotdot, hardlink (KNOWN limit; control). Exit 1 if any alias other than the known hardlink gives a double send.
import { spawn } from "node:child_process";
import { linkSync, mkdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { join, relative } from "node:path";
import { E, EVID, S0, Sink, minter } from "./lib";
(async () => {
  const work = join(EVID, "work/t5"); rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
  const { m, ids, mint } = await minter("off");
  const db = join(work, "s.sqlite"); const s = new Sink(db, { ...ids, initialState: S0 }); s.init(S0);
  for (let i = 0; i < 3; i++) { const t = await mint(JSON.parse(s.stateBlob()), `d${i}`, "100"); if (s.commit(t.text!).status !== "committed") throw new Error("setup"); }
  s.close(); m.stop();
  const cfgFile = join(work, "dcfg.json"); writeFileSync(cfgFile, JSON.stringify({ ...ids, initialStateSha256: E.stateSha256(S0) }));
  const cases: Record<string, (dir: string) => [string, string]> = {
    same: d => [join(d, "ledger.jsonl"), join(d, "ledger.jsonl")],
    relative: d => [join(d, "ledger.jsonl"), relative(process.cwd(), join(d, "ledger.jsonl"))],
    dotdot: d => [join(d, "ledger.jsonl"), join(d, "..", "a-" + d.split("/").pop(), "..", d.split("/").pop()!, "ledger.jsonl")],
    symlinkFile: d => { symlinkSync(join(d, "ledger.jsonl"), join(d, "alias.jsonl")); return [join(d, "ledger.jsonl"), join(d, "alias.jsonl")]; },
    symlinkDir: d => { symlinkSync(d, d + "-ln"); return [join(d, "ledger.jsonl"), join(d + "-ln", "ledger.jsonl")]; },
    caseName: d => [join(d, "ledger.jsonl"), join(d, "LEDGER.JSONL")],
    caseDir: d => [join(d, "ledger.jsonl"), join(d.toUpperCase().replace("/USERS/MACKIANNI", "/Users/mackianni"), "ledger.jsonl")],
    firmlink: d => [join(d, "ledger.jsonl"), "/System/Volumes/Data" + join(d, "ledger.jsonl")],
    hardlinkKNOWN: d => { writeFileSync(join(d, "ledger.jsonl"), ""); linkSync(join(d, "ledger.jsonl"), join(d, "hl.jsonl")); return [join(d, "ledger.jsonl"), join(d, "hl.jsonl")]; },
  };
  const run = (ledger: string, ms: number, onEmit?: () => void) => new Promise<string[]>(res => {
    const c = spawn(process.execPath, ["--import", "tsx", join(EVID, "t5_dchild.ts"), db, ledger, cfgFile, String(ms)], { stdio: ["ignore", "pipe", "inherit"] });
    const lines: string[] = []; let buf = "";
    c.stdout.on("data", d => { buf += d; const ls = buf.split("\n"); buf = ls.pop()!; for (const l of ls) { lines.push(l); if (l.startsWith("emit") && onEmit) { onEmit(); onEmit = undefined; } } });
    c.on("exit", () => res(lines));
  });
  const out: Record<string, unknown> = {}; let defect = false;
  for (const [name, mk] of Object.entries(cases)) {
    const d = join(work, name); mkdirSync(d); mkdirSync(join(work, "a-" + name));
    const [pa, pb] = mk(d);
    let pB: Promise<string[]> | undefined;
    const la = await run(pa, 700, () => { pB = run(pb, 0); });
    const lb = await pB!;
    const emits = [...la, ...lb].filter(l => l.startsWith("emit")).map(l => l.slice(5));
    const twice = emits.filter((r, i) => emits.indexOf(r) !== i);
    out[name] = { A: la.filter(l => !l.startsWith("emit")), B: lb.filter(l => !l.startsWith("emit")), emits, doubleSent: twice };
    if (twice.length && name !== "hardlinkKNOWN") defect = true;
  }
  console.log(JSON.stringify(out, null, 0).replace(/\},"/g, "},\n\""));
  process.exit(defect ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
