// x-bridge3: run vectors.json through native_bridge.ts (or a mutant of it) and compare with the Python reference
// results. Usage (cwd = repository root): node --import tsx run_ts.ts <bridge module .ts> <python results .json> <out .json>
// Exit 0: no difference; 1: at least one difference; 3: driver error.
import { spawn, ChildProcessWithoutNullStreams } from "node:child_process";
import { createHash } from "node:crypto";
import * as fs from "node:fs";
import * as path from "node:path";

const X = __dirname;
const CORE = "/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-corebacked/build/shellcore-orig.cjs";
const BIN = path.join(X, "bin", "refund");
const PIN = "b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8";
const WR = path.join(X, "run", "work-ts");
const [modPath, pyPath, outPath] = process.argv.slice(2);
// eslint-disable-next-line @typescript-eslint/no-require-imports
const NB = require(path.resolve(modPath));
fs.mkdirSync(WR, { recursive: true });

class Checker {
  private buf = ""; private q: ((s: string) => void)[] = [];
  readonly p: ChildProcessWithoutNullStreams;
  constructor(mode: string | null) {
    this.p = spawn("/opt/homebrew/bin/node", [path.join(X, "ref", "dafny_side2.cjs"), CORE, ...(mode ? [mode] : [])],
      { cwd: X, env: { PATH: "/opt/homebrew/bin:/usr/bin:/bin", HOME: path.join(X, "home") }, stdio: ["pipe", "pipe", "inherit"] }) as any;
    this.p.stdout.on("data", (c: Buffer) => {
      this.buf += c.toString("utf8");
      let i: number;
      while ((i = this.buf.indexOf("\n")) !== -1) { const l = this.buf.slice(0, i); this.buf = this.buf.slice(i + 1); this.q.shift()!(l); }
    });
  }
  ask(o: unknown): Promise<any> {
    return new Promise(done => { this.q.push(l => done(JSON.parse(l))); this.p.stdin.write(JSON.stringify(o) + "\n"); });
  }
  async check(c: any, h: string): Promise<boolean> {
    const t = { request: { requestId: c.request.requestId, amount: c.request.amount.toString(), reason: c.request.reason },
      post: NB.stateJson(c.post), intent: NB.intentJson(c.intent) };
    const a = await this.ask({ pre: NB.stateJson(c.pre), preStateSha256: h, t });
    if (a.error !== undefined) throw new Error(a.error);
    return a.issue === true && a.plan === 1 && a.tokenOk === true;
  }
  close(): void { this.p.stdin.end(); }
}

function val(v: any): any {
  if ("s" in v) return v.s;
  if ("i" in v) return BigInt(v.i);
  if ("fl" in v) return Number(v.fl);
  if ("b" in v) return v.b;
  const f = v.f.map(val);
  switch (v.t) {
    case "Charge": return { chargeId: f[0], original: f[1], remaining: f[2], enabled: f[3] };
    case "Request": return { requestId: f[0], amount: f[1], reason: f[2] };
    case "Intent": return { chargeId: f[0], requestId: f[1], amount: f[2], reason: f[3] };
    case "Candidate": return { pre: f[0], request: f[1], post: f[2], intent: f[3] };
    case "tuple": return f;
  }
  throw new Error("bad vector");
}
const sha = (p: string) => createHash("sha256").update(fs.readFileSync(p)).digest("hex");
const SENT: Record<string, string> = { DYLD_INSERT_LIBRARIES: "/nonexistent/forge-x.dylib", LD_PRELOAD: "/nonexistent/x.so", FORGE_SENTINEL: "leak" };
const setSent = () => Object.assign(process.env, SENT);
const clearSent = () => { for (const k of Object.keys(SENT)) delete process.env[k]; };
const AUTH = { pre: { chargeId: "ch_1", original: 100n, remaining: 60n, enabled: true }, request: { requestId: "req_1", amount: 40n, reason: "returned_item" } };

// Fields compared with the Python reference for each kind.
const FIELDS: Record<string, string[]> = {
  bridge: ["sign", "reason", "token", "launched", "stdout", "elapsed_lt_4s", "grandchild_alive"],
  planted: ["sign", "reason", "token"], launch_env: ["launched", "refusal", "stdout"],
  probe: ["envp", "pyenv_bad", "fds", "nonblock", "cwd_list", "stdin_is_wire"],
};
const norm = (x: unknown): string => JSON.stringify(x, (_k, v) => (v && typeof v === "object" && !Array.isArray(v))
  ? Object.fromEntries(Object.keys(v).sort().map(k => [k, v[k]])) : v);

(async () => {
  const vec = JSON.parse(fs.readFileSync(path.join(X, "vectors.json"), "utf8"));
  const py: Record<string, any> = Object.fromEntries(JSON.parse(fs.readFileSync(pyPath, "utf8")).map((r: any) => [r.id, r]));
  const chk: Record<string, Checker> = {};
  for (const m of ["real", "ignore-post", "ignore-intent", "accept-all"]) chk[m] = new Checker(m === "real" ? null : m);
  const out: any[] = [], diffs: any[] = [];
  for (const v of vec) {
    const r: any = { id: v.id };
    if (v.kind === "bridge") {
      const c = val(v.cand), b: string = v.binary;
      const p = b === "real" ? BIN : b.startsWith("standin:") ? path.join(X, "standin", b.slice(8)) : b.slice(4);
      const pin = v.pin === "real" ? PIN : v.pin === "standin" ? sha(p) : "00".repeat(32);
      const gp = path.join(X, "run", "grandchild.pid");
      if (v.grandchild) fs.rmSync(gp, { force: true });
      if (v.parent_env) setSent();
      const t0 = performance.now();
      let d: any, lr: any;
      try {
        [d, lr] = await NB.bridge2(c, { checker: (cc: any, h: string) => chk[v.checker ?? "real"].check(cc, h), binaryPath: p,
          pinnedSha256: pin, timeoutMs: v.timeout_s * 1000, workRoot: WR });
      } finally { clearSent(); }
      Object.assign(r, { sign: d.sign, reason: d.reason, token: d.token, launched: lr === null ? null : lr.launched,
        stdout: lr === null ? null : lr.stdout.toString("hex"), elapsed_lt_4s: performance.now() - t0 < 4000 });
      if (v.grandchild) {
        await new Promise(res => setTimeout(res, 300));
        try { const pid = Number(fs.readFileSync(gp, "utf8")); try { process.kill(pid, 0); r.grandchild_alive = true; } catch { r.grandchild_alive = false; } }
        catch { r.grandchild_alive = null; }
      }
    } else if (v.kind === "planted") {
      const q = v.result;
      const lr = { launched: q.launched, refusal: q.refusal, stdout: Buffer.from(q.stdout, "hex"), exitCode: q.exit_code, signal: q.signal,
        timedOut: q.timed_out, stderrLen: q.stderr_len, stdoutOverflow: q.stdout_overflow, stdinComplete: q.stdin_complete,
        copyUnchanged: q.copy_unchanged, elapsedMs: 0 };
      const d = NB.decide2(val(v.cand), v.issue, lr);
      Object.assign(r, { sign: d.sign, reason: d.reason, token: d.token });
    } else if (v.kind === "launch_env") {
      const lr = await NB.launch(BIN, PIN, NB.nativeWire(NB.encode(AUTH.pre, AUTH.request)), 4096, { workRoot: WR, env: v.env });
      Object.assign(r, { launched: lr.launched, refusal: lr.refusal, stdout: lr.stdout.toString("hex") });
    } else if (v.kind === "probe") {
      const wire = NB.nativeWire(NB.encode(AUTH.pre, AUTH.request));
      setSent();
      let lr: any;
      try { lr = await NB.launch(path.join(X, "standin", "probe"), sha(path.join(X, "standin", "probe")), wire, 65536, { timeoutMs: 10000, workRoot: WR }); }
      finally { clearSent(); }
      let p: any;
      try { p = JSON.parse(lr.stdout.toString("utf8")); } catch { p = { envp: ["NO_OUTPUT:" + lr.signal + ":" + lr.exitCode], pyenv: [], fds: null, nonblock: null, cwd_list: null, stdin: null }; }
      Object.assign(r, { envp: [...p.envp].sort(), pyenv_bad: p.pyenv.filter((k: string) => k.startsWith("DYLD_") || k.startsWith("LD_") || k === "FORGE_SENTINEL"),
        fds: p.fds, nonblock: p.nonblock, cwd_list: p.cwd_list, stdin_is_wire: p.stdin === wire.toString("latin1") });
    }
    out.push(r);
    const ref = py[v.id];
    const bad = ref === undefined ? ["missing-reference"] : FIELDS[v.kind].filter(k => norm(r[k] ?? null) !== norm(ref[k] ?? null));
    if (bad.length) diffs.push({ id: v.id, fields: bad, ts: Object.fromEntries(bad.map(k => [k, r[k]])), py: ref && Object.fromEntries(bad.map(k => [k, ref[k]])) });
  }
  for (const c of Object.values(chk)) c.close();
  const sign = out.filter(r => r.sign === true).length;
  fs.writeFileSync(outPath, JSON.stringify({ module: modPath, vectors: out.length, sign, differences: diffs.length, diffs, results: out }, null, 1));
  process.stdout.write(JSON.stringify({ vectors: out.length, sign, differences: diffs.length, diffIds: diffs.map(d => d.id + ":" + d.fields.join("+")) }) + "\n");
  process.exit(diffs.length === 0 ? 0 : 1);
})().catch(e => { process.stderr.write(String(e && e.stack) + "\n"); process.exit(3); });
