// Attack 6b: kill loop. Instance A (name A) commits r2 and is SIGKILLed at a random point; instance B (real name)
// then commits r2/r3 and closes; then A restarts by name A. Count acknowledged commits lost while the audit accepts.
// args: mode (same|hardlink) iterations seed maxDelayUs.  exit 1 = at least one acknowledged commit lost (or a store
// that never starts again); 0 = safe in all iterations.
import { spawn } from "node:child_process";
import { copyFileSync, existsSync, linkSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { fixture, fresh, EV, tryOpen, settledIds } from "./common15";
const [mode = "hardlink", itS = "50", seedS = "1", maxS = "4000"] = process.argv.slice(2);
let seed = Number(seedS); const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
const busyWaitUs = (us: number) => { const t = process.hrtime.bigint() + BigInt(Math.floor(us)) * 1000n; while (process.hrtime.bigint() < t) { /* spin */ } };
(async () => {
  const fx = await fixture(); const W = join(EV, "work", "s6b-" + mode + "-" + seedS); fresh(W);
  const tpl = join(W, "tpl.sqlite"); { const s = tryOpen(tpl, fx).sink; s.init(fx.cfg.initialState); s.commit(fx.tokens[0].text); s.close(); }
  const real = join(W, "sink.sqlite"), alias = mode === "same" ? real : join(W, "alias.sqlite");
  const stats: Record<string, number> = {}; const bad: any[] = []; const inc = (k: string) => { stats[k] = (stats[k] ?? 0) + 1; };
  for (let it = 0; it < Number(itS); it++) {
    for (const f of [real, alias]) for (const x of ["", "-journal"]) rmSync(f + x, { force: true });
    copyFileSync(tpl, real); if (alias !== real) linkSync(real, alias);
    const p = spawn(process.execPath, ["--import", "tsx", join(EV, "child_go.ts"), alias, "1"], { stdio: ["pipe", "pipe", "ignore"] });
    let txt = ""; p.stdout!.on("data", d => { txt += String(d); });
    await new Promise<void>(r => { const t = setInterval(() => { if (txt.includes("OPEN")) { clearInterval(t); r(); } }, 5); });
    p.stdin!.write("g"); busyWaitUs(rnd() * Number(maxS)); p.kill("SIGKILL");
    await new Promise(r => p.once("exit", r));
    const ackA = /RESULT \{"status":"committed"/.test(txt);
    const jb = existsSync(alias + "-journal") ? readFileSync(alias + "-journal") : null; const hot = jb === null ? -1 : jb.length < 12 ? -2 : jb[0] === 0 ? -3 : jb.readUInt32BE(8);
    inc(ackA ? "A_acked" : "A_not_acked"); inc("aliasJournal_" + (hot === -1 ? "none" : hot === -2 ? "short" : hot === -3 ? "zeroed" : hot === 0 ? "nRec0" : "nRec>0"));
    // instance B by the real name
    const ob = tryOpen(real, fx); if (!ob.sink) { inc("B_openfail"); bad.push({ it, B: ob.err }); continue; }
    const b2 = ob.sink.commit(fx.tokens[1].text).status, b3 = ob.sink.commit(fx.tokens[2].text).status; ob.sink.close();
    const acked = ["r1", "r2", "r3"].filter((r, i) => i === 0 || (i === 1 && (b2 === "committed" || b2 === "replayed" || ackA)) || (i === 2 && b3 === "committed"));
    // instance A restarts by its own name
    const oa = tryOpen(alias, fx);
    if (!oa.sink) { inc("A_restart_refused"); bad.push({ it, hot, b2, b3, A: oa.err }); continue; }
    const ids = settledIds(oa.sink); oa.sink.close();
    const lost = acked.filter(r => !ids.includes(r));
    if (lost.length) { inc("lost_acked"); bad.push({ it, hot, ackA, b2, b3, ids, lost }); } else inc("ok");
  }
  console.log(JSON.stringify({ mode, iterations: Number(itS), seed: Number(seedS), stats, bad: bad.slice(0, 5) }));
  process.exit(bad.length ? 1 : 0);
})();
