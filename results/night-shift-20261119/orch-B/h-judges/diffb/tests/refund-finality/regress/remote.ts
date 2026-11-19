// PARENT side of the judge process model (task h-judges). A TEST, not a proof.
// Starts worker.ts as a child process with the module(s) under test and sends it operations over IPC.
// The parent keeps every verdict. The child's stdout and stderr are captured (never forwarded as verdict lines; the
// tail is shown, prefixed, only when the parent asks). A child that exits, is killed, or does not answer in time
// makes every pending and later call throw ChildGone: the caller records that as a FAIL.
import { ChildProcess, fork } from "node:child_process";
import { join } from "node:path";

export class ChildGone extends Error {}
export class Remote {
  private child: ChildProcess;
  private seq = 1;
  private pending = new Map<number, { res: (v: unknown) => void; rej: (e: Error) => void; timer: NodeJS.Timeout }>();
  private gone: string | null = null;
  private out = "";
  readonly ready: Promise<void>;
  constructor(sinkPath: string, dispatcherPath: string | null, private readonly timeoutMs = 60000, env?: NodeJS.ProcessEnv) {
    this.child = fork(join(__dirname, "worker.ts"), [sinkPath, dispatcherPath ?? "none"],
      { execArgv: ["--no-warnings", "--import", "tsx"], stdio: ["ignore", "pipe", "pipe", "ipc"], env: env ?? process.env });
    const keep = (b: Buffer) => { this.out = (this.out + b.toString("utf8")).slice(-4000); };
    this.child.stdout?.on("data", keep); this.child.stderr?.on("data", keep);
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
  goneReason(): string | null { return this.gone; }
  outputTail(n = 400): string { return this.out.slice(-n); }
  kill(): void { try { this.child.kill("SIGKILL"); } catch { /* gone */ } this.die(this.gone ?? "killed by the parent"); }
  async stop(): Promise<void> {
    if (this.gone !== null) return;
    await new Promise<void>(res => { this.child.once("exit", () => res()); this.kill(); });
  }
}
