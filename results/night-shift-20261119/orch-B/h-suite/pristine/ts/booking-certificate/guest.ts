// Slice 3: the side of the optimizers. Nothing here is proved. No decision is made here: the checker
// core judges every proposal, and the sink accepts an effect only with a token.
// runGuest starts one untrusted optimizer as its own process, in any language. It writes ONE line (the
// problem) and takes ONE line (the proposal) from the RAW BYTES of the answer, with a byte limit, and
// waits for that line no longer than the time limit. The line is handed on as text. It is not parsed
// here.
// ISOLATION (review finding R1). An optimizer process runs as the same operating-system user as the
// sink. Without isolation it can write the database file of the sink behind the sink. runGuest
// therefore starts every optimizer under the sandbox tool of macOS with a profile that denies file
// writes, network use, signals and the task port of other processes, for the process and for every
// process that it starts. Reading files stays allowed: an optimizer can read the repository and the
// database (the private key is only in the memory of the issuer process). That tool is TRUSTED and
// not proved, and its vendor marks it as deprecated. On a platform without it, runGuest starts
// nothing. The time limit ends the wait and kills the process group of the optimizer; that kill is
// housekeeping, not containment (a process can leave its group).
// IssuerClient sends proposals to the token issuer process and returns its answers.
import { spawn, ChildProcessWithoutNullStreams } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { Batch, Board, Token, canon } from "./encoding";

export const MAX_GUEST_LINE_BYTES = 16384;
export const SANDBOX_TOOL = "/usr/bin/sandbox-exec";
export const SANDBOX_PROFILE = '(version 1)(allow default)(deny file-write*)(allow file-write-data (literal "/dev/null"))' +
  "(deny network*)(deny signal)(deny mach-priv-task-port)";
// The issuer takes a line of at most this number of bytes (ts/booking-certificate/issuer.ts).
const ISSUER_LINE_BYTES = 65536;
const ISSUER_ANSWER_MS = 30000;
export type GuestAnswer = { ok: true; line: string } | { ok: false; reason: string };

// The one line that an optimizer gets: the capacities, the needs and the values, as canonical JSON.
export const problemLine = (board: Board, batch: Batch): string =>
  canon({ capacity: board.capacity, needs: batch.needs, values: batch.values });

export function runGuest(command: string[], line: string, cwd: string, timeLimitMs: number): Promise<GuestAnswer> {
  return new Promise(done => {
    if (!existsSync(SANDBOX_TOOL)) { done({ ok: false, reason: "no isolation tool for the optimizer on this platform" }); return; }
    let finished = false, held: Buffer[] = [], heldBytes = 0;
    // detached: the optimizer gets its own process group, so that the whole group can be killed.
    const child = spawn(SANDBOX_TOOL, ["-p", SANDBOX_PROFILE, ...command],
      { cwd, detached: true, stdio: ["pipe", "pipe", "ignore"], env: { PATH: process.env.PATH ?? "" } });
    const finish = (answer: GuestAnswer) => {
      if (finished) return;
      finished = true; clearTimeout(timer);
      try { if (child.pid !== undefined) process.kill(-child.pid, "SIGKILL"); } catch { /* the group has ended */ }
      try { child.kill("SIGKILL"); } catch { /* the process has ended */ }
      // A process that the optimizer left behind must not keep this process waiting (review finding R4).
      child.stdout.destroy(); child.stdin.destroy(); child.unref();
      done(answer);
    };
    const timer = setTimeout(() => finish({ ok: false, reason: "time limit" }), timeLimitMs);
    child.on("error", () => finish({ ok: false, reason: "the optimizer did not start" }));
    child.stdin.on("error", () => { /* the optimizer closed its input */ });
    child.stdout.on("data", (chunk: Buffer) => {
      if (finished) return;
      const newline = chunk.indexOf(0x0a), end = newline === -1 ? chunk.length : newline;
      if (heldBytes + end > MAX_GUEST_LINE_BYTES) { finish({ ok: false, reason: "line too long" }); return; }
      held.push(Buffer.from(chunk.subarray(0, end))); heldBytes += end;
      if (newline !== -1) finish({ ok: true, line: Buffer.concat(held, heldBytes).toString("utf8") });
    });
    child.on("close", () => finish({ ok: false, reason: "no line" }));
    child.stdin.end(line + "\n");
  });
}

export type Ready = { publicKeyPem: string; specSha256: string; checkerSha256: string };
export type Issued = { ok: boolean; token?: Token; reason?: string };

export class IssuerClient {
  private next = 1;
  private readonly waiting = new Map<number, (answer: Issued) => void>();
  ready!: Ready;
  // Answers that carry no known id (the issuer answers a message with a bad id with id null).
  readonly unmatched: Issued[] = [];
  private constructor(private readonly child: ChildProcessWithoutNullStreams) {}
  static start(root: string, corePath: string, specPath: string, referencePath: string): Promise<IssuerClient> {
    const child = spawn(process.execPath, ["--import", "tsx", join(__dirname, "issuer.ts"), corePath, specPath, referencePath],
      { cwd: root, stdio: ["pipe", "pipe", "inherit"] }) as unknown as ChildProcessWithoutNullStreams;
    const client = new IssuerClient(child);
    return new Promise((done, fail) => {
      child.on("error", fail);
      child.on("exit", code => {
        fail(new Error("token issuer process ended with code " + code));
        // Every request that waits for an answer gets a refusal, so that no caller waits for ever.
        for (const waiter of client.waiting.values()) waiter({ ok: false, reason: "token issuer process ended" });
        client.waiting.clear();
      });
      createInterface({ input: child.stdout }).on("line", line => {
        const msg = JSON.parse(line);
        if (msg.ready) { client.ready = msg; done(client); return; }
        const waiter = client.waiting.get(msg.id);
        if (waiter) { waiter(msg); client.waiting.delete(msg.id); } else client.unmatched.push(msg);
      });
    });
  }
  // Sends any message body. The issuer accepts only { id, pre, batch, proposalText }.
  // A message above the line limit of the issuer is refused here: the issuer answers such a line
  // without an id, and a caller would wait for ever (review finding R3; a line of control characters
  // from an optimizer grows six times in JSON). No caller waits longer than ISSUER_ANSWER_MS.
  send(body: Record<string, unknown>): Promise<Issued> {
    const id = this.next++, line = JSON.stringify({ id, ...body });
    if (Buffer.byteLength(line, "utf8") > ISSUER_LINE_BYTES) return Promise.resolve({ ok: false, reason: "message too long for the issuer" });
    return new Promise(done => {
      const timer = setTimeout(() => { this.waiting.delete(id); done({ ok: false, reason: "no answer from the issuer in time" }); }, ISSUER_ANSWER_MS);
      this.waiting.set(id, answer => { clearTimeout(timer); done(answer); });
      this.child.stdin.write(line + "\n");
    });
  }
  issue(pre: unknown, batch: unknown, proposalText: unknown): Promise<Issued> { return this.send({ pre, batch, proposalText }); }
  // Writes one line as it is.
  raw(line: string): void { this.child.stdin.write(line + "\n"); }
  // Writes text with no line end.
  write(text: string): void { this.child.stdin.write(text); }
  stop(): void { this.child.removeAllListeners("exit"); this.child.stdin.end(); this.child.kill(); }
}
