// Attack 6: two HONEST sink processes reach one database file through two path names. One is SIGKILLed while its
// commit waits for the exclusive lock (a reader holds SHARED: deterministic). The journal it leaves is named after ITS
// path. The other process commits r2, r3 ("committed"). Then the first instance restarts by its own name.
// Modes: same (control: one name), dirlink (directory symlink, like /tmp -> /private/tmp), filelink (file symlink), hardlink.
// exit 1 = an acknowledged commit is lost and the audit accepts the store; 0 = safe.
import { spawn, ChildProcess } from "node:child_process";
import { existsSync, linkSync, mkdirSync, readdirSync, symlinkSync } from "node:fs";
import { join } from "node:path";
import { fixture, fresh, EV, tryOpen, settledIds } from "./common15";
const mode = process.argv[2] ?? "hardlink";
const sleep = (ms: number) => new Promise(r => setTimeout(r, ms));
function start(script: string, args: string[]): { p: ChildProcess; out: string[] } {
  const p = spawn(process.execPath, ["--import", "tsx", join(EV, script), ...args], { stdio: ["ignore", "pipe", "ignore"] });
  const out: string[] = []; p.stdout!.on("data", d => out.push(...String(d).split("\n").filter(Boolean))); return { p, out };
}
async function until(f: () => boolean, ms: number) { const t = Date.now(); while (!f() && Date.now() - t < ms) await sleep(25); return f(); }
(async () => {
  const fx = await fixture(); const W = join(EV, "work", "s6-" + mode); fresh(W);
  mkdirSync(join(W, "real")); const real = join(W, "real", "sink.sqlite"); let nameA = real;
  if (mode === "dirlink") { symlinkSync(join(W, "real"), join(W, "link")); nameA = join(W, "link", "sink.sqlite"); }
  const out: any = { mode };
  let s = tryOpen(real, fx).sink; s.init(fx.cfg.initialState); out.c1 = s.commit(fx.tokens[0].text).status; s.close();
  if (mode === "filelink") { symlinkSync(real, join(W, "real", "alias.sqlite")); nameA = join(W, "real", "alias.sqlite"); }
  if (mode === "hardlink") { linkSync(real, join(W, "real", "alias.sqlite")); nameA = join(W, "real", "alias.sqlite"); }
  const b = start("child_blocker.ts", [real]); await until(() => b.out.includes("SHARED"), 20000);
  const a = start("child_commit.ts", [nameA, "1"]); await until(() => a.out.includes("OPEN"), 20000);
  await sleep(1500);                                      // A is now waiting in COMMIT (busy_timeout 30 s)
  out.filesBeforeKill = readdirSync(join(W, "real")); out.aOut = [...a.out];
  a.p.kill("SIGKILL"); await new Promise(r => a.p.once("exit", r));
  b.p.kill("SIGKILL"); await new Promise(r => b.p.once("exit", r));
  out.filesAfterKill = readdirSync(join(W, "real"));
  // the second honest instance, by the REAL name
  s = tryOpen(real, fx).sink; out.B_r2 = s.commit(fx.tokens[1].text).status; out.B_r3 = s.commit(fx.tokens[2].text).status; out.B_ids = settledIds(s); s.close();
  out.filesAfterB = readdirSync(join(W, "real"));
  // instance A restarts by ITS name
  const o = tryOpen(nameA, fx); out.A_restart = o.err ?? "ok";
  if (o.sink) { out.A_ids = settledIds(o.sink); out.A_audit = o.sink.audit(); out.A_r4 = o.sink.commit(fx.tokens[3].text); o.sink.close(); }
  const o2 = tryOpen(real, fx); out.real_restart = o2.err ?? "ok"; if (o2.sink) { out.real_ids = settledIds(o2.sink); o2.sink.close(); }
  const lost = out.B_r2 === "committed" && ((Array.isArray(out.A_ids) && !out.A_ids.includes("r2")) || (Array.isArray(out.real_ids) && !out.real_ids.includes("r2")));
  console.log(JSON.stringify(out));
  console.log(lost ? "DEFECT: acknowledged commit r2 lost; audit accepted the store" : "SAFE"); process.exit(lost ? 1 : 0);
})();
