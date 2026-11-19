// kf_c_own.ts <tree> <issuer core .cjs>   (owner decision D-1: persistent minter key from a checked file)
// Written by Orchestrator C. TEMPORARY TEST KEYS ONLY: every key here is generated in this run and deleted with its
// temp directory. It starts the real minter of <tree> with a key file in many conditions and records: started or refused.
// MUST-REFUSE cases: a wrong file type, a symbolic link as the key path, group or other permission bits, an empty or
//   damaged or too large file, a key given through the environment or as text in the argument.
// MUST-START cases: mode 0600 and mode 0400 with a good key.
// INFORMATION cases (printed, not counted): a symbolic link in a PARENT directory, a hard link, a file swapped or
//   re-moded AFTER the minter started.
// Exit 1 = a must-refuse case started, a must-start case was refused, a case hung, or the minter used another key than
// the one in the file. Exit 0 = none of these.
import { spawn, spawnSync } from "node:child_process";
import { chmodSync, linkSync, mkdirSync, renameSync, symlinkSync, writeFileSync } from "node:fs";
import { createHash, createPublicKey } from "node:crypto";
import { join } from "node:path";
const [root, core] = process.argv.slice(2);
// eslint-disable-next-line @typescript-eslint/no-require-imports
const KF = require(join(root, "tests/refund-finality/regress/kf_lib.ts"));
type Run = { ready: any | null; code: number | null; timedOut: boolean; stderr: string; child: any; out: string[] };
function start(rest: string[], env: Record<string, string> = {}, ms = 20000): Promise<Run> {
  const child = spawn(process.execPath, ["--no-warnings", "--import", "tsx", join(root, "ts/refund-finality/minter.ts"), core, join(root, "spec/refund/spec.lock"), "on", ...rest],
    { cwd: root, stdio: ["pipe", "pipe", "pipe"], env: { PATH: process.env.PATH ?? "", HOME: process.env.HOME ?? "", LANG: "C", NODE_PATH: process.env.NODE_PATH ?? "", ...env } });
  const run: Run = { ready: null, code: null, timedOut: false, stderr: "", child, out: [] };
  return new Promise(done => {
    let buf = "", settled = false;
    const finish = () => { if (!settled) { settled = true; clearTimeout(timer); done(run); } };
    const timer = setTimeout(() => { run.timedOut = true; try { child.kill("SIGKILL"); } catch { /* gone */ } finish(); }, ms);
    child.stderr.on("data", (d: Buffer) => { run.stderr += String(d); });
    child.stdout.on("data", (d: Buffer) => {
      buf += String(d);
      for (let i = buf.indexOf("\n"); i >= 0; i = buf.indexOf("\n")) {
        const line = buf.slice(0, i); buf = buf.slice(i + 1); run.out.push(line);
        try { const m = JSON.parse(line); if (m.ready) { run.ready = m; finish(); } } catch { /* not a json line */ }
      }
    });
    child.on("exit", (c: number | null) => { run.code = c; finish(); });
  });
}
const stop = (r: Run) => { try { r.child.stdin.end(); r.child.kill(); } catch { /* gone */ } };
const idOfPem = (pem: string): string => createHash("sha256").update(createPublicKey(pem).export({ type: "spki", format: "der" })).digest("hex");
const keyOfReady = (ready: any): string => typeof ready?.keyId === "string" ? ready.keyId : (typeof ready?.publicKeyPem === "string" ? idOfPem(ready.publicKeyPem) : "unknown");

KF.guard((async () => {
  const bad: string[] = []; const table: Record<string, string> = {}; const info: Record<string, string> = {};
  const K = KF.sinkKit(root);
  const good = KF.makeKeyFile(0o600);
  // a real sink store for the minter's store argument
  const db = join(K.dir(), "s.sqlite");
  const sink = K.open(db, { issuerKeys: [KF.active(good)] });
  if (typeof sink === "string") throw new Error("setup: sink " + sink);
  sink.init(K.S0); sink.close();
  const mem = () => KF.makeMemoryFile();
  const expect = async (name: string, want: "start" | "refuse", keyPath: string, env: Record<string, string> = {}, wantKeyId?: string) => {
    const r = await start([keyPath, db, mem()], env); stop(r);
    const got = r.timedOut ? "HUNG" : r.ready ? "started" : "refused";
    table[name] = got + (r.ready ? "" : " (" + r.stderr.replace(/\s+/g, " ").slice(0, 90) + ")");
    if (got === "HUNG") bad.push(name + ": hung");
    else if (want === "refuse" && got === "started") bad.push(name + ": started but must be refused");
    else if (want === "start" && got !== "started") bad.push(name + ": refused but must start");
    else if (want === "start" && wantKeyId && keyOfReady(r.ready) !== wantKeyId) bad.push(name + ": started with ANOTHER key than the file's");
    return r;
  };
  // must start
  await expect("mode 0600", "start", good.path, {}, good.keyId);
  const k400 = KF.makeKeyFile(0o400); await expect("mode 0400", "start", k400.path, {}, k400.keyId);
  // must refuse: permission bits
  for (const mode of [0o640, 0o604, 0o644, 0o660, 0o666, 0o610, 0o601, 0o620, 0o602]) {
    const k = KF.makeKeyFile(mode); await expect("mode 0" + mode.toString(8), "refuse", k.path);
  }
  // must refuse: file types and contents
  const d = KF.keyTempDir();
  symlinkSync(good.path, join(d, "link.pem")); await expect("symbolic link as the key path", "refuse", join(d, "link.pem"));
  symlinkSync(join(d, "missing.pem"), join(d, "dangling.pem")); await expect("dangling symbolic link", "refuse", join(d, "dangling.pem"));
  const fifo = join(d, "fifo.pem"); spawnSync("/usr/bin/mkfifo", ["-m", "600", fifo]); await expect("FIFO", "refuse", fifo);
  mkdirSync(join(d, "dir.pem"), { mode: 0o700 }); await expect("directory", "refuse", join(d, "dir.pem"));
  await expect("character device /dev/null", "refuse", "/dev/null");
  await expect("missing file", "refuse", join(d, "nothing.pem"));
  writeFileSync(join(d, "empty.pem"), "", { mode: 0o600 }); await expect("empty file", "refuse", join(d, "empty.pem"));
  writeFileSync(join(d, "junk.pem"), "not a key\n", { mode: 0o600 }); await expect("damaged file", "refuse", join(d, "junk.pem"));
  writeFileSync(join(d, "big.pem"), "x".repeat(5000), { mode: 0o600 }); await expect("file of 5000 bytes", "refuse", join(d, "big.pem"));
  const pub = join(d, "pub.pem"); writeFileSync(pub, good.publicKeyPem, { mode: 0o600 }); await expect("a PUBLIC key in the file", "refuse", pub);
  // must refuse: a key from the environment or as argument text
  const other = KF.makeKeyFile(0o600);
  const pem = String(other.privateKey.export({ type: "pkcs8", format: "pem" }));
  const envNames = ["FORGE_MINTER_KEY", "FORGE_MINTER_KEY_FILE", "MINTER_KEY", "MINTER_KEY_FILE", "PRIVATE_KEY", "KEY_FILE", "FORGE_KEY_PEM", "FORGE_TEST_KEY", "FORGE_MINTER_TEST", "FORGE_BYPASS"];
  const envPem: Record<string, string> = {}, envPath: Record<string, string> = {};
  for (const n of envNames) { envPem[n] = pem; envPath[n] = other.path; }
  await expect("no key file, key text in 10 environment names", "refuse", join(d, "nothing.pem"), envPem);
  await expect("no key file, key path in 10 environment names", "refuse", join(d, "nothing.pem"), envPath);
  await expect("key text as the argument", "refuse", pem);
  await expect("good file + ANOTHER key in the environment: the file's key is used", "start", good.path, envPem, good.keyId);
  // information: link in a parent directory, hard link
  const pd = KF.keyTempDir(); symlinkSync(good.dir, join(pd, "linkdir"));
  { const r = await start([join(pd, "linkdir", "key.pem"), db, mem()]); stop(r); info["symbolic link in a PARENT directory"] = r.ready ? "started (only the last path part is checked)" : "refused"; }
  { const hl = join(good.dir, "hard.pem"); linkSync(good.path, hl); const r = await start([hl, db, mem()]); stop(r); info["hard link to the key file"] = r.ready ? "started (stated by the design)" : "refused"; }
  // information + check: swap and permission change AFTER the start
  { const a = KF.makeKeyFile(0o600), b = KF.makeKeyFile(0o600);
    const r = await start([a.path, db, mem()]);
    const before = keyOfReady(r.ready);
    renameSync(b.path, a.path);                                   // another key file is moved over the path
    info["swap after start"] = "minter keeps the key it read at start: " + (before === a.keyId);
    if (before !== a.keyId) bad.push("swap case: the minter did not start with the file's key");
    stop(r);
    const r2 = await start([a.path, db, mem()]); stop(r2);
    info["restart after the swap"] = r2.ready ? "started with the NEW file's key: " + (keyOfReady(r2.ready) === b.keyId) : "refused";
    const c = KF.makeKeyFile(0o600); const r3 = await start([c.path, db, mem()]);
    chmodSync(c.path, 0o644); info["mode changed to 0644 after start"] = "minter still runs: " + (r3.ready !== null && r3.code === null); stop(r3);
    const r4 = await start([c.path, db, mem()]); stop(r4);
    table["restart with the file now mode 0644"] = r4.ready ? "started" : "refused";
    if (r4.ready) bad.push("restart with a 0644 key file started");
  }
  console.log(JSON.stringify({ table, info, bad }, null, 1));
  console.log(bad.length ? "DEFECT" : "SAFE"); process.exit(bad.length ? 1 : 0);
})());
