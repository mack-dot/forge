// Shared helper of the key-file regressions kf_*.ts and of the test set-up of m_lib, d_lib, s_lib, suite (OWNER DECISION
// D-1, night shift 2026-11-19, task h-key). A TEST helper, not a proof.
// TEST KEYS ONLY: each key is made here with generateKeyPairSync and written to a NEW temporary directory (mode 0700) as
// key.pem (mode 0600, PKCS#8 PEM). Nothing here reads any other key. The directories are removed at process exit.
// No private key byte is ever printed.
import { createHash, generateKeyPairSync, KeyObject, sign } from "node:crypto";
import { chmodSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { spawn } from "node:child_process";
import { join, resolve } from "node:path";

const temps: string[] = [];
process.on("exit", () => { for (const d of temps) { try { rmSync(d, { recursive: true, force: true }); } catch { /* best effort */ } } });
export function keyTempDir(): string { const d = mkdtempSync(join(tmpdir(), "forge-kf-")); chmodSync(d, 0o700); temps.push(d); return d; }

export type TestKey = { path: string; dir: string; publicKeyPem: string; keyId: string; privateKey: KeyObject; publicKey: KeyObject };
// key_id, computed here independently of encoding.ts: SHA-256 (lower-case hex) of the DER SubjectPublicKeyInfo bytes.
export const testKeyIdOf = (publicKey: KeyObject): string =>
  createHash("sha256").update(publicKey.export({ type: "spki", format: "der" })).digest("hex");
// A new Ed25519 test key in a new temp directory, written with mode 0600 (or `mode`).
export function makeKeyFile(mode = 0o600, name = "key.pem", dir = keyTempDir()): TestKey {
  const { publicKey, privateKey } = generateKeyPairSync("ed25519");
  const path = join(dir, name);
  writeFileSync(path, privateKey.export({ type: "pkcs8", format: "pem" }) as string, { flag: "wx", mode: 0o600 });
  chmodSync(path, mode);
  return { path, dir, publicKeyPem: publicKey.export({ type: "spki", format: "pem" }) as string, keyId: testKeyIdOf(publicKey), privateKey, publicKey };
}
// A test-signed token text in the D-1 format, with the trusted encoding E of the tree under test.
export function signedTokenText(E: any, body: unknown, key: { privateKey: KeyObject; keyId: string }, keyId = key.keyId): string {
  return E.canon({ body, keyId, signature: sign(null, E.signedBytes(body, keyId), key.privateKey).toString("base64") });
}

// ---- shared parts of the kf_*.ts regressions. Usage of every kf_*.ts file (pinned Node 24.3.0):
//   node --import tsx tests/refund-finality/regress/kf_<name>.ts <treeRoot> <compiledIssuerModule> [<old tree>]
// Exit 0: PASS (the safe outcome, AND the positive controls in the same file commit). Exit 1: FAIL (the defect, or a
// positive control fails: a reject-all system fails). Exit 2: usage. Exit 3: the harness broke.
export type State = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
export function argv(): { root: string; core: string; old?: string } {
  const [root, core, old] = process.argv.slice(2);
  if (!root || !core) { console.error("usage: kf_<name>.ts <treeRoot> <compiledIssuerModule> [<old tree>]"); process.exit(2); }
  return { root: resolve(root), core: resolve(core), ...(old ? { old: resolve(old) } : {}) };
}
/* eslint-disable @typescript-eslint/no-require-imports */
export function load(root: string): any {
  const r = (p: string): any => { try { return require(join(root, p)); } catch { return null; } };
  return { E: r("ts/refund-finality/encoding.ts"), SK: r("ts/refund-finality/sink.ts"), D: r("ts/refund-finality/dispatcher.ts"),
    ST: r("ts/refund-finality/core/store.ts"), KF: r("ts/refund-finality/keyfile.ts"), P: r("ts/refund-finality/proposer.ts") };
}
/* eslint-enable @typescript-eslint/no-require-imports */
export function verdict(pass: boolean, detail: unknown): never {
  console.log(JSON.stringify(detail));
  console.log(pass ? "PASS" : "FAIL");
  process.exit(pass ? 0 : 1);
}
export function guard(p: Promise<void> | void): void { Promise.resolve(p).catch(e => { console.error(e); process.exit(3); }); }
export const IDS = { specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64) };
export const st = (remaining: string, chargeId = "ch_kf", original = "1000"): State => ({ chargeId, original, remaining, refundEnabled: true });
// A token body for `pre` (the honest transition: remaining - amount), ids = the pinned test ids.
export function bodyFor(E: any, pre: State, rid: string, amount: string, ids = IDS): any {
  return { domain: E.DOMAIN, ...ids, preStateSha256: E.stateSha256(pre), requestId: rid,
    post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() }, intent: { chargeId: pre.chargeId, requestId: rid, amount, reason: "duplicate_charge" } };
}
// A test key pair WITHOUT a file (for sink-side tests that sign in this process).
export function memKey(): { privateKey: KeyObject; publicKey: KeyObject; publicKeyPem: string; keyId: string } {
  const { publicKey, privateKey } = generateKeyPairSync("ed25519");
  return { privateKey, publicKey, publicKeyPem: publicKey.export({ type: "spki", format: "pem" }) as string, keyId: testKeyIdOf(publicKey) };
}
export const active = (k: { keyId: string; publicKeyPem: string }) => ({ keyId: k.keyId, publicKeyPem: k.publicKeyPem, status: "active" });
export const retired = (k: { keyId: string; publicKeyPem: string }, verifyUpToSeq: number) => ({ keyId: k.keyId, publicKeyPem: k.publicKeyPem, status: "retired", verifyUpToSeq });
export const shortErr = (e: unknown): string => String((e as Error)?.message ?? e).replace(/\s+/g, " ").slice(0, 200);

// A minter process with the given arguments after <core> <lock> <mode>. Waits for the ready line, or the exit, or `ms`.
export type MinterRun = { ready: any | null; code: number | null; timedOut: boolean; stderr: string;
  mint: (pre: State, rid: string, amount: string) => Promise<any>; stop: () => void };
export function startMinter(root: string, core: string, rest: string[], mode: "on" | "off" = "on", ms = 20000): Promise<MinterRun> {
  const child = spawn(process.execPath, ["--no-warnings", "--import", "tsx", join(root, "ts/refund-finality/minter.ts"), core, join(root, "spec/refund/spec.lock"), mode, ...rest],
    { cwd: root, stdio: ["pipe", "pipe", "pipe"] });
  let buf = "", stderr = "", next = 1, ready: any = null, code: number | null = null, timedOut = false;
  const waiting = new Map<number, (a: any) => void>();
  return new Promise(done => {
    let settled = false;
    const finish = () => { if (!settled) { settled = true; clearTimeout(timer); done(run); } };
    const run: MinterRun = {
      get ready() { return ready; }, get code() { return code; }, get timedOut() { return timedOut; }, get stderr() { return stderr; },
      mint: (pre, rid, amount) => new Promise(res => {
        const id = next++, post = { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() };
        waiting.set(id, res);
        child.stdin.write(JSON.stringify({ id, pre, transition: { request: { requestId: rid, amount, reason: "duplicate_charge" }, post,
          intent: { chargeId: pre.chargeId, requestId: rid, amount, reason: "duplicate_charge" } } }) + "\n");
      }),
      stop: () => { try { child.stdin.end(); child.kill(); } catch { /* gone */ } },
    } as MinterRun;
    const timer = setTimeout(() => { timedOut = true; try { child.kill("SIGKILL"); } catch { /* gone */ } finish(); }, ms);
    child.stderr.on("data", d => { stderr += String(d); });
    child.stdout.on("data", d => {
      buf += String(d);
      for (let i = buf.indexOf("\n"); i >= 0; i = buf.indexOf("\n")) {
        const line = buf.slice(0, i); buf = buf.slice(i + 1);
        let m: any; try { m = JSON.parse(line); } catch { continue; }
        if (m.ready) { ready = m; finish(); } else { const w = waiting.get(m.id); if (w) { waiting.delete(m.id); w(m); } }
      }
    });
    child.on("exit", c => { code = c; for (const w of waiting.values()) w({ ok: false, reason: "minter ended" }); waiting.clear(); finish(); });
  });
}

// A sink-side kit: one initial charge, the pinned test ids, a token maker, sink and dispatcher openers for a given pin.
// pin = { publicKeyPem } (the old single pin) or { issuerKeys } (the D-1 allowlist).
export function sinkKit(root: string, S0: State = st("1000")) {
  const L = load(root);
  const dirs: string[] = [];
  const tok = (pre: State, rid: string, amount: string, signer: { privateKey: KeyObject; keyId: string }, keyId = signer.keyId): string =>
    signedTokenText(L.E, bodyFor(L.E, pre, rid, amount), signer, keyId);
  const cfgOf = (pin: any): any => ({ ...pin, ...IDS, initialState: S0 });
  const open = (db: string, pin: any): any => { try { return new L.SK.Sink(db, cfgOf(pin)); } catch (e) { return "REFUSED: " + shortErr(e); } };
  const flush = (db: string, ledger: string, pin: any, genesisPem: string): { emitted: string[]; refused: string[]; alarm?: string } => {
    const effects: any[] = [];
    const dcfg = { ...pin, ...IDS, initialStateSha256: L.E.stateSha256(S0), newLedgerH0: L.SK.genesisOf(L.E.canon(S0), IDS.specLockSha256, IDS.checkerSha256, genesisPem) };
    try {
      const f = new L.D.Dispatcher(db, ledger, dcfg, (e: any) => effects.push(e)).flush();
      return { emitted: f.emitted.map((e: any) => e.requestId), refused: f.refused.map((x: any) => x.requestId + ": " + String(x.reason).slice(0, 80)) };
    } catch (e) { return { emitted: effects.map((x: any) => x.requestId), refused: [], alarm: shortErr(e) }; }
  };
  const dir = (): string => { const d = keyTempDir(); dirs.push(d); return d; };
  const rows = (db: string): string[] => {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { DatabaseSync } = require("node:sqlite");
    const d = new DatabaseSync(db, { readOnly: true });
    try { return (d.prepare("SELECT request_id FROM settled ORDER BY seq").all() as any[]).map(x => x.request_id); } finally { d.close(); }
  };
  return { ...L, S0, tok, cfgOf, open, flush, dir, rows };
}

// An EMPTY durable mint memory file (mode 0600) in a new temp directory: what an operator provisions (mintmemory.ts).
export function makeMemoryFile(dir = keyTempDir()): string {
  const path = join(dir, "mint-memory.jsonl");
  writeFileSync(path, "", { flag: "wx", mode: 0o600 });
  chmodSync(path, 0o600);
  return path;
}
