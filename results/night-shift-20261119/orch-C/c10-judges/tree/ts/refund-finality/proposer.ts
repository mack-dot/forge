// Slice 1: the UNTRUSTED side. This file has no authority. Nothing here is proved and nothing here
// needs to be correct for safety: the checker core judges every candidate, and the sink accepts an
// effect only with a token.
// `propose` computes a candidate transition. `MinterClient` sends candidates to the token issuer
// process and returns its answers.
import { spawn, ChildProcessWithoutNullStreams } from "node:child_process";
import { join } from "node:path";
import { ChargeState, RefundRequest, Token, Transition } from "./encoding";

export function propose(pre: ChargeState, request: RefundRequest): Transition {
  return {
    request,
    post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(request.amount)).toString() },
    intent: { chargeId: pre.chargeId, requestId: request.requestId, amount: request.amount, reason: request.reason },
  };
}

// Splits a byte stream into lines at the byte 0x0A only (never at U+2028, U+2029, CR or any other character) and
// decodes each complete line as UTF-8. A multi-byte character that is cut by a chunk boundary stays whole.
export class LineSplitter {
  private pending: Buffer[] = [];
  constructor(private readonly onLine: (line: string) => void) {}
  push(chunk: Buffer): void {
    let start = 0;
    for (let i = 0; i < chunk.length; i++) {
      if (chunk[i] !== 0x0a) continue;
      this.pending.push(chunk.subarray(start, i));
      const line = Buffer.concat(this.pending).toString("utf8");
      this.pending = [];
      start = i + 1;
      this.onLine(line);
    }
    if (start < chunk.length) this.pending.push(chunk.subarray(start));
  }
}

export type Ready = { publicKeyPem: string; specLockSha256: string; checkerSha256: string; singleUse: boolean };
export type Minted = { ok: boolean; token?: Token; reason?: string };

export class MinterClient {
  private next = 1;
  private readonly waiting = new Map<number, (answer: Minted) => void>();
  ready!: Ready;
  // Answers that carry no known id (the issuer answers a message with a bad id with id null).
  readonly unmatched: Minted[] = [];
  private constructor(private readonly child: ChildProcessWithoutNullStreams) {}
  static start(root: string, corePath: string, specLockPath: string, singleUse: "on" | "off"): Promise<MinterClient> {
    const child = spawn(process.execPath, ["--import", "tsx", join(__dirname, "minter.ts"), corePath, specLockPath, singleUse],
      { cwd: root, stdio: ["pipe", "pipe", "inherit"] }) as unknown as ChildProcessWithoutNullStreams;
    const client = new MinterClient(child);
    return new Promise((done, fail) => {
      child.on("error", fail);
      child.on("exit", code => {
        fail(new Error("token issuer process ended with code " + code));
        // Every request that waits for an answer gets a refusal, so that no caller waits for ever.
        for (const waiter of client.waiting.values()) waiter({ ok: false, reason: "token issuer process ended" });
        client.waiting.clear();
      });
      // The issuer writes one JSON text per line and ends a line with the byte 0x0A only. node:readline also
      // splits at U+2028 and U+2029, which JSON.stringify leaves unescaped inside a string: an answer whose
      // token held such a character was cut in two and the request never got its answer (C-ATT-01, review F5).
      const lines = new LineSplitter(line => {
        let msg: any;
        try { msg = JSON.parse(line); } catch { client.unmatched.push({ ok: false, reason: "answer is not JSON" }); return; }
        if (msg.ready) { client.ready = msg; done(client); return; }
        const waiter = client.waiting.get(msg.id);
        if (waiter) { waiter(msg); client.waiting.delete(msg.id); } else client.unmatched.push(msg);
      });
      child.stdout.on("data", (chunk: Buffer) => lines.push(chunk));
    });
  }
  // Sends any message body. The issuer accepts only { id, pre, transition }.
  send(body: Record<string, unknown>): Promise<Minted> {
    const id = this.next++;
    return new Promise(done => { this.waiting.set(id, done); this.child.stdin.write(JSON.stringify({ id, ...body }) + "\n"); });
  }
  mint(pre: unknown, transition: unknown): Promise<Minted> { return this.send({ pre, transition }); }
  // Writes one line as it is.
  raw(line: string): void { this.child.stdin.write(line + "\n"); }
  // Writes text with no line end.
  write(text: string): void { this.child.stdin.write(text); }
  stop(): void { this.child.removeAllListeners("exit"); this.child.stdin.end(); this.child.kill(); }
}
