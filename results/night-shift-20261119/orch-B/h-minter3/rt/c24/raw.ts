// c7-minter: raw driver of minter.ts over stdin with 0x0A framing (no MinterClient, no readline).
import { spawn, ChildProcess } from "node:child_process";
import { createHash, createPublicKey, verify } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";

export const ROOT = process.env.C7_ROOT ||
  "<SCRATCH>/redteam-C/fix-370ff65c";
export const CORE = process.env.C7_CORE ||
  "<REPO>/results/night-shift-20261119/orch-B/h-minter2/build/issueauth.cjs";
export const SPEC_LOCK = join(ROOT, "spec/refund/spec.lock");
export const sha = (b: string | Buffer) => createHash("sha256").update(b).digest("hex");

export type Answer = { raw: Buffer; msg: any };
export class Raw {
  child: ChildProcess; ready!: any; answers: Answer[] = []; private buf = Buffer.alloc(0);
  private waiters: Array<() => void> = []; stderr = "";
  constructor(args: string[], core = CORE) {
    this.child = spawn(process.execPath, ["--import", "tsx", join(ROOT, "ts/refund-finality/minter.ts"), core, SPEC_LOCK, ...args],
      { cwd: ROOT, stdio: ["pipe", "pipe", "pipe"] });
    this.child.stderr!.on("data", d => { this.stderr += d.toString(); });
    this.child.stdout!.on("data", (d: Buffer) => {
      this.buf = Buffer.concat([this.buf, d]);
      let i: number;
      while ((i = this.buf.indexOf(0x0a)) !== -1) {
        const line = this.buf.subarray(0, i); this.buf = this.buf.subarray(i + 1);
        const msg = JSON.parse(line.toString("utf8"));
        if (msg.ready && !this.ready) this.ready = msg; else this.answers.push({ raw: Buffer.from(line), msg });
        const w = this.waiters; this.waiters = []; w.forEach(f => f());
      }
    });
  }
  async waitFor(pred: () => boolean, ms = 60000): Promise<void> {
    const end = Date.now() + ms;
    while (!pred()) {
      if (Date.now() > end) throw new Error("timeout; stderr=" + this.stderr);
      await new Promise<void>(r => { this.waiters.push(r); setTimeout(r, 200); });
    }
  }
  async start() { await this.waitFor(() => !!this.ready); return this; }
  write(b: Buffer | string) { this.child.stdin!.write(b); }
  // send raw bytes followed by 0x0A; wait for `n` more answers
  async send(b: Buffer | string, n = 1): Promise<Answer[]> {
    const k = this.answers.length; this.write(Buffer.concat([Buffer.from(b as any), Buffer.from([0x0a])]));
    await this.waitFor(() => this.answers.length >= k + n); return this.answers.slice(k, k + n);
  }
  stop() { this.child.stdin!.end(); this.child.kill(); }
}

// Extract the token body bytes from the raw answer line, verbatim.
export function bodyBytesOf(raw: Buffer): Buffer | null {
  const s = raw.toString("utf8"); const pre = "\"token\":{\"body\":"; const i = s.indexOf(pre); const j = s.lastIndexOf(",\"signature\":");
  if (i < 0 || j < 0) return null; return Buffer.from(s.slice(i + pre.length, j), "utf8");
}
export function verifies(ready: any, body: Buffer, sigB64: string): boolean {
  return verify(null, body, createPublicKey(ready.publicKeyPem), Buffer.from(sigB64, "base64"));
}
// Independent canonical JSON (sorted keys; strings via JSON.stringify; booleans). Own code, not encoding.ts.
export function mycanon(v: any): string {
  if (typeof v === "string") return JSON.stringify(v);
  if (typeof v === "boolean") return String(v);
  return "{" + Object.keys(v).sort().map(k => JSON.stringify(k) + ":" + mycanon(v[k])).join(",") + "}";
}
export function pinnedChecker(core = CORE): string {
  const enc = readFileSync(join(ROOT, "ts/refund-finality/encoding.ts")), mint = readFileSync(join(ROOT, "ts/refund-finality/minter.ts"));
  return sha(mycanon({ coreModuleSha256: sha(readFileSync(core)), encodingSha256: sha(enc), minterSha256: sha(mint) }));
}
export const pinnedSpec = () => sha(readFileSync(SPEC_LOCK));
