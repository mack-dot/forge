// Regression for red team C-ATT-31 and C-ATT-14 (night shift 2026-11-19, task h-minter2). A TEST, not a proof.
// The CLOSED LAUNCH (ts/refund-finality/launch/minter-build.sh, minter-launch.sh): pre-compiled JavaScript, no tsx at
// run time, env -i with an allow-list, a manifest of SHA-256 digests checked before Node starts and again inside.
// Steps: (1) build a closed directory and take its manifest digest (the pin); (2) plant code in a tsx transform cache
// as the red team did (f9_tsx_cache.ts): start `node --import tsx minter.ts` with TMPDIR=<plant>, prepend a marker
// statement to the cached minter.ts entry (recorded, not judged: that launch is NOT closed); (3) closed launch with a
// hostile caller environment (TMPDIR=<plant>, NODE_OPTIONS=--require <evil>, NODE_PATH=<shim dir>): it must start, run
// no planted code, report the checker id of the three source files, and issue a zero-amount token; (4) a changed
// bignumber.js in a second closed directory: the launcher refuses (exit 2) BEFORE Node starts (no marker); (5) a wrong
// pin: refused; (6) minter.cjs started directly with FORGE_MINTER_CLOSED and an extra variable: refused (exit 2).
// FAILS on the earlier tree (no launcher). Usage, exit codes: as m2_squat_invented_prestate_does_not_block.ts.
// NOT shown: a process of the same user can still change files between the checks and the reads, or attach a
// debugger, or replace the Node binary (assumptions SAME-UID, FIXED-DEPS in SINGLE_USE_2.md).
import { spawn, spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { argv, guard, load, tempDir, verdict } from "./m_lib";

const ZERO = (id: number) => JSON.stringify({ id, pre: { chargeId: "ch_cl", original: "100", remaining: "60", refundEnabled: true },
  transition: { request: { requestId: "rq_cl", amount: "0", reason: "duplicate_charge" },
    post: { chargeId: "ch_cl", original: "100", remaining: "60", refundEnabled: true },
    intent: { chargeId: "ch_cl", requestId: "rq_cl", amount: "0", reason: "duplicate_charge" } } }) + "\n";
// Starts a command, sends one zero-amount request after the ready line, returns the lines, stderr and the exit code.
function run(cmd: string, args: string[], env: Record<string, string>, cwd: string): Promise<{ lines: any[]; err: string; code: number | null }> {
  return new Promise(res => {
    const c = spawn(cmd, args, { cwd, env, stdio: ["pipe", "pipe", "pipe"] });
    let out = "", err = ""; const lines: any[] = [];
    const t = setTimeout(() => c.kill(), 20000);
    c.stderr.on("data", d => { err += d; });
    c.stdout.on("data", d => {
      out += d;
      for (let i = out.indexOf("\n"); i >= 0; i = out.indexOf("\n")) {
        const msg = JSON.parse(out.slice(0, i)); out = out.slice(i + 1); lines.push(msg);
        if (msg.ready) c.stdin.write(ZERO(1)); else { c.stdin.end(); setTimeout(() => c.kill(), 500); }
      }
    });
    c.on("exit", code => { clearTimeout(t); res({ lines, err, code }); });
  });
}
const unlock = (dir: string) => spawnSync("/bin/chmod", ["-R", "u+w", dir]);

guard((async () => {
  const { root, core } = argv();
  const { E } = load(root);
  const build = join(root, "ts/refund-finality/launch/minter-build.sh"), launch = join(root, "ts/refund-finality/launch/minter-launch.sh");
  if (!existsSync(build) || !existsSync(launch)) verdict(false, { closedLaunch: "NOT AVAILABLE (no ts/refund-finality/launch scripts)" });
  const work = tempDir(), plant = join(work, "plant"), marker = join(work, "MARKER"), evil = join(work, "evil.js"), shim = join(work, "shim");
  mkdirSync(plant); mkdirSync(join(shim, "bignumber.js"), { recursive: true });
  writeFileSync(evil, `require("node:fs").writeFileSync(${JSON.stringify(marker)}, "evil preload ran in pid " + process.pid);\n`);
  writeFileSync(join(shim, "bignumber.js", "index.js"), `require("node:fs").writeFileSync(${JSON.stringify(marker)}, "shim ran"); module.exports = require(${JSON.stringify(require.resolve("bignumber.js", { paths: [root] }))});\n`);
  const PATH = "/opt/homebrew/bin:/usr/bin:/bin", r: any = {};
  // (1) build
  const b = spawnSync("/bin/sh", [build, root, core, join(work, "closed")], { cwd: root, env: { PATH, HOME: work, LANG: "C" }, encoding: "utf8" });
  const pin = (b.stdout ?? "").trim();
  r.build = b.status === 0 && /^[0-9a-f]{64}$/.test(pin) ? "pin " + pin : "BUILD FAILED: " + b.stderr;
  // (2) plant in the tsx cache (the earlier launch path)
  const tsxEnv = { PATH, HOME: work, LANG: "C", TMPDIR: plant };
  const first = await run(process.execPath, ["--import", "tsx", join(root, "ts/refund-finality/minter.ts"), core, join(root, "spec/refund/spec.lock"), "on"], tsxEnv, root);
  await new Promise(res => setTimeout(res, 1500));
  const tdir = readdirSync(plant).find(n => n.startsWith("tsx-"));
  const entry = tdir === undefined ? undefined : readdirSync(join(plant, tdir)).find(n => readFileSync(join(plant, tdir, n), "utf8").includes("refused to start: NODE_OPTIONS is set"));
  if (tdir !== undefined && entry !== undefined) {
    const v = JSON.parse(readFileSync(join(plant, tdir, entry), "utf8"));
    v.code = `require("node:fs").writeFileSync(${JSON.stringify(marker)}, "planted cache code ran in pid " + process.pid);` + v.code;
    writeFileSync(join(plant, tdir, entry), JSON.stringify(v));
    const second = await run(process.execPath, ["--import", "tsx", join(root, "ts/refund-finality/minter.ts"), core, join(root, "spec/refund/spec.lock"), "on"], tsxEnv, root);
    r.tsxLaunchRanPlantedCode = existsSync(marker) ? "YES (expected: the tsx launch is not closed)" : "no";
    r.tsxLaunchStarted = first.lines.length > 0 && second.lines.length > 0;
    if (existsSync(marker)) spawnSync("/bin/rm", ["-f", marker]);
  } else r.tsxLaunchRanPlantedCode = "no cache entry found";
  // (3) closed launch with a hostile caller environment
  const pinned = E.checkerSha256Of(readFileSync(core), readFileSync(join(root, "ts/refund-finality/encoding.ts")), readFileSync(join(root, "ts/refund-finality/minter.ts")));
  const hostile = { PATH, HOME: work, LANG: "C", TMPDIR: plant, NODE_OPTIONS: "--require " + evil, NODE_PATH: shim };
  const c = await run("/bin/sh", [launch, join(work, "closed"), pin, join(root, "spec/refund/spec.lock"), "on"], hostile, work);
  const ready = c.lines.find(l => l.ready), answer = c.lines.find(l => l.id === 1);
  r.closed = { started: ready !== undefined, checkerIsPinned: ready?.checkerSha256 === pinned, zeroIssued: answer?.ok === true,
    foreignCodeRan: existsSync(marker), closedInfo: /"closedLaunch":\{"manifestSha256":"[0-9a-f]{64}"/.test(c.err) };
  // (4) a changed bignumber.js in a second closed directory
  const b2 = spawnSync("/bin/sh", [build, root, core, join(work, "closed2")], { cwd: root, env: { PATH, HOME: work, LANG: "C" }, encoding: "utf8" });
  const pin2 = (b2.stdout ?? "").trim(), bn = join(work, "closed2", "node_modules", "bignumber.js", "bignumber.js");
  unlock(join(work, "closed2"));
  writeFileSync(bn, `require("node:fs").writeFileSync(${JSON.stringify(marker)}, "changed bignumber ran");\n` + readFileSync(bn, "utf8"));
  const t = await run("/bin/sh", [launch, join(work, "closed2"), pin2, join(root, "spec/refund/spec.lock"), "on"], { PATH, HOME: work, LANG: "C" }, work);
  r.changedFile = { code: t.code, foreignCodeRan: existsSync(marker), err: t.err.trim().slice(0, 120) };
  // (5) a wrong pin
  const w = await run("/bin/sh", [launch, join(work, "closed"), "0".repeat(64), join(root, "spec/refund/spec.lock"), "on"], { PATH, HOME: work, LANG: "C" }, work);
  r.wrongPin = { code: w.code, err: w.err.trim().slice(0, 120) };
  // (6) minter.cjs started directly, with the pin and one extra variable
  const d = await run("/opt/homebrew/bin/node", ["--no-addons", "--disallow-code-generation-from-strings", join(work, "closed", "minter.cjs"),
    join(work, "closed", "core.cjs"), join(root, "spec/refund/spec.lock"), "on"], { PATH, LANG: "C", TZ: "UTC", HOME: "/var/empty", FORGE_MINTER_CLOSED: pin, EXTRA: "1" }, work);
  r.directExtraVariable = { code: d.code, err: d.err.trim().split("\n").pop()?.slice(0, 120) };
  unlock(work);
  verdict(b.status === 0 && r.closed.started && r.closed.checkerIsPinned && r.closed.zeroIssued && !r.closed.foreignCodeRan && r.closed.closedInfo &&
    r.changedFile.code === 2 && !r.changedFile.foreignCodeRan && r.wrongPin.code === 2 && r.directExtraVariable.code === 2, r);
})());
