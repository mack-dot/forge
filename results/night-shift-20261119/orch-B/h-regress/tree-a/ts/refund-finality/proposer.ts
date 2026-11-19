// Slice 1: the UNTRUSTED side. This file has no authority. Nothing here is proved and nothing here
// needs to be correct for safety: the checker core judges every candidate, and the sink accepts an
// effect only with a token.
// `propose` computes a candidate transition. `MinterClient` sends candidates to the token issuer
// process and returns its answers.
import { spawn, ChildProcessWithoutNullStreams } from "node:child_process";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { ChargeState, RefundRequest, Token, Transition } from "./encoding";

export function propose(pre: ChargeState, request: RefundRequest): Transition {
  return {
    request,
    post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(request.amount)).toString() },
    intent: { chargeId: pre.chargeId, requestId: request.requestId, amount: request.amount, reason: request.reason },
  };
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
      createInterface({ input: child.stdout }).on("line", line => {
        const msg = JSON.parse(line);
        if (msg.ready) { client.ready = msg; done(client); return; }
        const waiter = client.waiting.get(msg.id);
        if (waiter) { waiter(msg); client.waiting.delete(msg.id); } else client.unmatched.push(msg);
      });
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
