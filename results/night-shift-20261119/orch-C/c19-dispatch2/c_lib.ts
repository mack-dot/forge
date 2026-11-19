// c_lib.ts: helpers for the multi-process attacks (child processes of c_child.ts, control files).
import { spawn } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
export const D = "<SCRATCH>/redteam-C/fix-f08a21c1/tests/refund-finality/regress/d_lib";
export function procs(root: string, w: any, ctl: string, effects: string, dcfgFile: string) {
  const running = new Map<string, { pid: number; done: Promise<string> }>();
  const start = (name: string, hooks: string) => {
    const p = spawn(process.execPath, ["--no-warnings", "--import", "tsx", join(__dirname, "c_child.ts"), root, w.db, w.ledger, dcfgFile, effects, name, ctl, hooks],
      { stdio: ["ignore", "pipe", "inherit"] });
    let out = "";
    p.stdout.on("data", d => { out += d; });
    const done = new Promise<string>(res => p.on("exit", (c, s) => res(out.trim() || `{"name":"${name}","exit":${c},"signal":"${s}"}`)));
    running.set(name, { pid: p.pid!, done });
    return done;
  };
  const at = async (name: string, hook: string) => { const f = join(ctl, `${name}-${hook}-at`), t = Date.now();
    while (!existsSync(f)) { if (Date.now() - t > 60000) throw new Error("timeout waiting " + f); await new Promise(r => setTimeout(r, 5)); } };
  const go = (name: string, hook: string) => writeFileSync(join(ctl, `${name}-${hook}-go`), "");
  const effs = () => readFileSync(effects, "utf8").split("\n").filter(Boolean).map(l => JSON.parse(l));
  return { start, at, go, effs, running };
}
