// Regression for OWNER DECISION D-1 (a), task h-key: the minter's key comes ONLY from the key file argument.
// (1) no key file argument, with FORGE_MINTER_KEY (a valid PEM test key) and FORGE_MINTER_KEY_FILE in the environment:
//     the minter exits 2 (usage), no ready line.
// (2) with a valid key file AND FORGE_MINTER_KEY set to ANOTHER key: the ready line has the FILE's key id (env ignored).
// (3) source text: minter.ts and keyfile.ts make no key (no generateKeyPair), read no key from process.env, and have no
//     flag that skips the file checks (no "unsafe", "--test", "bypass" text; minter.ts never calls the test seam).
// SAFE = exit 0. On f67c5c16: the minter makes a key in memory -> FAIL.
import { spawn } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { argv, guard, makeKeyFile, startMinter, verdict } from "./kf_lib";

function bare(root: string, core: string, env: Record<string, string>): Promise<{ code: number | null; out: string }> {
  return new Promise(res => {
    const c = spawn(process.execPath, ["--no-warnings", "--import", "tsx", join(root, "ts/refund-finality/minter.ts"), core, join(root, "spec/refund/spec.lock"), "on"],
      { cwd: root, env: { PATH: process.env.PATH ?? "/usr/bin:/bin", HOME: process.env.HOME ?? "/tmp", TMPDIR: process.env.TMPDIR ?? "/tmp", ...env }, stdio: ["pipe", "pipe", "ignore"] });
    let out = ""; const t = setTimeout(() => c.kill(), 15000);
    c.stdout.on("data", d => { out += String(d); if (out.includes("\n")) { c.kill(); } });
    c.on("exit", code => { clearTimeout(t); res({ code, out }); });
  });
}
guard((async () => {
  const { root, core } = argv();
  const envKey = makeKeyFile(), fileKey = makeKeyFile();
  const pem = readFileSync(envKey.path, "utf8");   // a TEST key made by this file
  const r: any = {};
  const b = await bare(root, core, { FORGE_MINTER_KEY: pem, FORGE_MINTER_KEY_FILE: envKey.path });
  r.noArgWithEnv = { code: b.code, ready: b.out.includes("\"ready\":true") };
  const prev = process.env.FORGE_MINTER_KEY; process.env.FORGE_MINTER_KEY = pem;
  const m = await startMinter(root, core, [fileKey.path]); m.stop();
  if (prev === undefined) delete process.env.FORGE_MINTER_KEY; else process.env.FORGE_MINTER_KEY = prev;
  r.fileWinsOverEnv = { ready: m.ready !== null, keyIdIsFile: m.ready?.keyId === fileKey.keyId };
  const src = ["ts/refund-finality/minter.ts", "ts/refund-finality/keyfile.ts"].map(p => existsSync(join(root, p)) ? readFileSync(join(root, p), "utf8") : "");
  const code = src.map(s => s.split("\n").filter(l => !l.trim().startsWith("//")).join("\n"));
  r.source = { keyfileExists: src[1] !== "", noGenerateKeyPair: code.every(s => !/generateKeyPair/.test(s)),
    noEnvKey: code.every(s => !/process\.env\.[A-Z_]*KEY/.test(s)) && !/process\.env/.test(code[1]), noBypassText: code.every(s => !/unsafe|bypass|--test/i.test(s)),
    minterUsesSeam: code[0].includes("loadSigningKeyWith") };
  verdict(b.code === 2 && !r.noArgWithEnv.ready && r.fileWinsOverEnv.ready && r.fileWinsOverEnv.keyIdIsFile && r.source.keyfileExists &&
    r.source.noGenerateKeyPair && r.source.noEnvKey && r.source.noBypassText && !r.source.minterUsesSeam, r);
})());
