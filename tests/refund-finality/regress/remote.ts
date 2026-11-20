// PARENT side of the judge process model (tasks h-judges, h-judges2). A TEST, not a proof.
// Starts worker.ts as a child process with the module(s) under test and sends it operations over IPC.
// The parent keeps every verdict. The child's stdout and stderr are captured (never forwarded as verdict lines; the
// tail is shown, prefixed, only when the parent asks). A child that exits, is killed, or does not answer in time
// makes every pending and later call throw ChildGone: the caller records that as a FAIL.
//
// EFFECT RECEIVER (task h-judges2, red-team evasion e_emit_twice_hidden2). The PARENT holds the effect receiver. It
// creates one extra pipe (child fd 4) for each child. The emit function that the child gives to the dispatcher under
// test writes ONE record line per call into that pipe and then BLOCKS until this process answers with an ACK line
// (HMAC with a per-child secret that only the worker's closure holds). So every emit call is observed here BEFORE it
// returns, and this process decides at that moment (a) whether the ledger file already holds the request id (read
// here, with a tolerant parser) and (b) whether that emit fails (failure injection is decided here, not in the child).
// DEFINITION: an EFFECT is a record that this receiver got. A record cannot be "unsent". Every well-formed record on
// the pipe counts, whoever in the child wrote it (a module that writes into the pipe directly SENDS an effect). A
// module that does not call emit (or makes the emit write go elsewhere) did not send: a real receiver would not get
// it either, and the liveness parts of the regressions see the effect as MISSING.
// CHANNEL FAULTS (each makes the regression FAIL; see channelProblems()): a line that is not a well-formed record or
// barrier; an effect record that arrives outside a flush window (after the barrier of the flush); a channel that is
// still held open by some process 5 s after the child was killed (a forked process that could send a late effect).
// REMAINING TRUST (named in the README): OUT-OF-BAND-EFFECT (a side channel this process does not own, for example
// a network socket or a file: out of scope for a test harness; in production the receiver is the provider) and
// IN-PROCESS-TAMPER (code in the child that reads the worker's closure, for example through the inspector, and
// forges ACKs; that only hides its OWN failure injection, never an effect: every record on the pipe still counts).
import { ChildProcess, fork } from "node:child_process";
import { createHmac, randomBytes } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import type { Readable, Writable } from "node:stream";

export class ChildGone extends Error {}
export type Received = { requestId: string; intent: any; ledgerHadLine: boolean; threw: boolean };

// Tolerant ledger reader (the ledger format changes: plain JSON lines, a hash chain of lines, more fields). For each
// line: parse it as JSON, or else the text from its first "{" to its last "}"; collect every string value of a key
// named "requestId" at any depth. Unparsable lines give no id.
export function ledgerLineIds(path: string): string[][] {
  if (!path || !existsSync(path)) return [];
  let text = ""; try { text = readFileSync(path, "utf8"); } catch { return []; }
  const ids = (v: unknown, out: string[]): string[] => {
    if (Array.isArray(v)) { for (const x of v) ids(x, out); }
    else if (v !== null && typeof v === "object") {
      for (const [k, x] of Object.entries(v as Record<string, unknown>)) { if (k === "requestId" && typeof x === "string") out.push(x); else ids(x, out); }
    }
    return out;
  };
  return text.split("\n").filter(l => l.trim().length > 0).map(l => {
    for (const cand of [l, l.slice(l.indexOf("{"), l.lastIndexOf("}") + 1)]) { try { return ids(JSON.parse(cand), []); } catch { /* next */ } }
    return [];
  });
}
export const ledgerHas = (path: string, rid: string): boolean => ledgerLineIds(path).some(xs => xs.includes(rid));

type Window = { ledger: string; failAt: number | undefined; list: Received[]; nonce: string; done: (() => void) | null };
export class Remote {
  private child: ChildProcess;
  private seq = 1;
  private pending = new Map<number, { res: (v: unknown) => void; rej: (e: Error) => void; timer: NodeJS.Timeout }>();
  private gone: string | null = null;
  private out = "";
  private readonly secret = randomBytes(32).toString("hex");
  private chan: (Readable & Writable) | null;
  private acc = "";
  private win: Window | null = null;
  private chanClosed: Promise<void>;
  readonly problems: string[] = [];
  readonly received: Received[] = [];                       // every effect record of this child, in arrival order
  readonly ready: Promise<void>;
  constructor(sinkPath: string, dispatcherPath: string | null, private readonly timeoutMs = 60000, env?: NodeJS.ProcessEnv) {
    this.child = fork(join(__dirname, "worker.ts"), [sinkPath, dispatcherPath ?? "none"],
      { execArgv: ["--no-warnings", "--import", "tsx"], stdio: ["ignore", "pipe", "pipe", "ipc", "pipe"], env: env ?? process.env });
    const keep = (b: Buffer) => { this.out = (this.out + b.toString("utf8")).slice(-4000); };
    this.child.stdout?.on("data", keep); this.child.stderr?.on("data", keep);
    this.chan = (this.child.stdio as unknown[])[4] as (Readable & Writable) | null;
    this.chanClosed = new Promise<void>(res => { if (!this.chan) return res(); this.chan.on("close", () => res()); this.chan.on("error", () => res()); });
    if (this.chan) {
      this.chan.on("data", (b: Buffer) => this.onData(b));
      this.chan.write("S " + this.secret + "\n");             // the worker reads this line before it loads any module
    } else this.problems.push("no effect channel");
    this.ready = new Promise((res, rej) => {
      const t = setTimeout(() => { this.die("no ready message in time"); rej(new ChildGone("child did not start")); }, timeoutMs);
      this.pending.set(0, { res: () => { clearTimeout(t); res(); }, rej: (e) => { clearTimeout(t); rej(e); }, timer: t });
    });
    this.child.on("message", (m: any) => {
      const p = m && typeof m.id === "number" ? this.pending.get(m.id) : undefined;
      if (!p) return;                                      // an unknown or repeated id is ignored
      this.pending.delete(m.id); clearTimeout(p.timer);
      if (m.ok) p.res(m.value); else p.rej(new Error("child operation error: " + String(m.error)));
    });
    this.child.on("exit", (code, signal) => this.die(`child exited (code ${code}, signal ${signal})`));
    this.child.on("error", (e) => this.die("child error: " + e.message));
  }
  private mac(seq: unknown, fail: number): string { return createHmac("sha256", this.secret).update(String(seq) + ":" + fail).digest("hex"); }
  private onData(b: Buffer): void {
    this.acc += b.toString("utf8");
    if (this.acc.length > 1 << 22) { this.problems.push("effect channel: more than 4 MiB without a line end"); this.acc = ""; return; }
    let i: number;
    while ((i = this.acc.indexOf("\n")) >= 0) {
      const line = this.acc.slice(0, i); this.acc = this.acc.slice(i + 1);
      let m: any; try { m = JSON.parse(line); } catch { m = null; }
      if (m && m.t === "e" && typeof m.requestId === "string" && Number.isSafeInteger(m.seq)) {
        const w = this.win;
        const idx = w ? w.list.length : -1;
        const threw = w !== null && w.failAt === idx;
        const r: Received = { requestId: m.requestId, intent: m.intent ?? null, ledgerHadLine: w ? ledgerHas(w.ledger, m.requestId) : false, threw };
        this.received.push(r);
        if (w) w.list.push(r); else this.problems.push(`effect for ${JSON.stringify(m.requestId).slice(0, 60)} arrived outside a flush`);
        const f = threw ? 1 : 0;
        try { this.chan?.write(`${m.seq} ${f} ${this.mac(m.seq, f)}\n`); } catch { /* gone */ }
      } else if (m && m.t === "b" && typeof m.nonce === "string") {
        if (this.win && this.win.nonce === m.nonce && this.win.done) { const d = this.win.done; this.win.done = null; d(); }
        else this.problems.push("effect channel: a barrier that this process did not ask for");
      } else this.problems.push("effect channel: not a record: " + JSON.stringify(line.slice(0, 80)));
    }
  }
  private die(why: string): void {
    if (this.gone === null) this.gone = why;
    for (const [, p] of this.pending) { clearTimeout(p.timer); p.rej(new ChildGone(this.gone)); }
    this.pending.clear();
  }
  call<T = any>(op: string, args: unknown = {}): Promise<T> {
    if (this.gone !== null) return Promise.reject(new ChildGone(this.gone));
    const id = this.seq++;
    return new Promise<T>((res, rej) => {
      const timer = setTimeout(() => { this.pending.delete(id); this.kill(); rej(new ChildGone(`no answer to ${op} in ${this.timeoutMs} ms`)); }, this.timeoutMs);
      this.pending.set(id, { res: res as (v: unknown) => void, rej, timer });
      try { this.child.send({ id, op, args }); } catch (e) { this.die("send failed: " + (e as Error).message); }
    });
  }
  // One flush of the dispatcher under test. The effects are the records that THIS receiver got between the start
  // of the flush and the barrier that follows the child's answer (the pipe keeps order: every record that the child
  // wrote before the barrier is read before it). failAt: the record with this index in the window gets a failing ACK.
  async flush(args: { db: string; ledger: string; dcfg: unknown }, failAt?: number): Promise<{ effects: Received[]; error: string }> {
    if (this.win) throw new Error("judge fault: nested flush");
    const w: Window = { ledger: args.ledger, failAt, list: [], nonce: randomBytes(16).toString("hex"), done: null };
    this.win = w;
    try {
      const r = await this.call<{ error: string }>("flush", args);
      const barrier = new Promise<void>((res, rej) => {
        const t = setTimeout(() => { this.kill(); rej(new ChildGone("effect channel barrier did not arrive")); }, this.timeoutMs);
        w.done = () => { clearTimeout(t); res(); };
      });
      await this.call("barrier", { nonce: w.nonce });
      await barrier;
      return { effects: w.list, error: String(r?.error ?? "") };
    } finally { this.win = null; }
  }
  goneReason(): string | null { return this.gone; }
  outputTail(n = 400): string { return this.out.slice(-n); }
  kill(): void { try { this.child.kill("SIGKILL"); } catch { /* gone */ } this.die(this.gone ?? "killed by the parent"); }
  // Kills the child and waits until the effect channel is closed by every process that holds it (5 s at most).
  async stop(): Promise<void> {
    if (this.gone === null) await new Promise<void>(res => { this.child.once("exit", () => res()); this.kill(); });
    let t: NodeJS.Timeout | undefined;
    const closed = await Promise.race([this.chanClosed.then(() => true), new Promise<boolean>(res => { t = setTimeout(() => res(false), 5000); })]);
    if (t) clearTimeout(t);
    if (!closed) { this.problems.push("effect channel still held open 5 s after the child was killed (another process holds it)"); try { this.chan?.destroy(); } catch { /* gone */ } }
  }
}
