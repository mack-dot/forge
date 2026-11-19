// Shared helper of the issuer (minter) regressions m_*.ts (night shift 2026-11-19, task h-minter). A TEST, not a proof.
// Usage of every m_*.ts file (from any directory, pinned Node 24.3.0):
//   node --import tsx tests/refund-finality/regress/m_<name>.ts <treeRoot> <compiledIssuerModule>
// <treeRoot>: the checkout whose ts/refund-finality/{minter,proposer,sink,encoding}.ts are under test.
// <compiledIssuerModule>: the module that this tree's minter.ts expects (merged: the RefundFinality build; the v6
// draft: the IssueBytes2 build; this branch: the IssueOnce build). Every file starts the issuer with memory rule "on".
// Exit 0: PASS (the safe outcome). Exit 1: FAIL (the defect). Exit 2: usage. Exit 3: the harness broke.
// Test keys only: each issuer process makes its own throwaway key. Sink files go to a fresh temp directory.
import { spawn } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

export type State = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
export function argv(): { root: string; core: string } {
  const [root, core] = process.argv.slice(2);
  if (!root || !core) { console.error("usage: m_<name>.ts <treeRoot> <compiledIssuerModule>"); process.exit(2); }
  return { root: resolve(root), core: resolve(core) };
}
const temps: string[] = [];
process.on("exit", () => { for (const d of temps) { try { rmSync(d, { recursive: true, force: true }); } catch { /* best effort */ } } });
export function tempDir(): string { const d = mkdtempSync(join(tmpdir(), "forge-m-")); temps.push(d); return d; }

/* eslint-disable @typescript-eslint/no-require-imports */
export function load(root: string): { E: any; Sink: any; MinterClient: any; propose: any } {
  const E = require(join(root, "ts/refund-finality/encoding.ts"));
  const { Sink } = require(join(root, "ts/refund-finality/sink.ts"));
  const { MinterClient, propose } = require(join(root, "ts/refund-finality/proposer.ts"));
  return { E, Sink, MinterClient, propose };
}
/* eslint-enable @typescript-eslint/no-require-imports */

// An issuer with memory rule "on", a sink pinned to its key, and mint/commit helpers.
export async function world(root: string, core: string, S0: State) {
  const { E, Sink, MinterClient, propose } = load(root);
  const m = await MinterClient.start(root, core, join(root, "spec/refund/spec.lock"), "on");
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const sink = new Sink(join(tempDir(), "s.sqlite"), { ...ids, initialState: S0 });
  sink.init(S0);
  const mint = async (pre: State, requestId: string, amount: string): Promise<{ ok: boolean; text?: string; reason?: string; post: State }> => {
    const t = propose(pre, { requestId, amount, reason: "duplicate_charge" });
    const a = await m.mint(pre, t);
    return a.ok ? { ok: true, text: E.tokenText(a.token), post: t.post } : { ok: false, reason: a.reason, post: t.post };
  };
  const commit = (x: { ok: boolean; text?: string; reason?: string }): string =>
    x.ok ? sink.commit(x.text).status : "mint refused: " + x.reason;
  const stop = () => { try { sink.close(); } catch { /* ignore */ } m.stop(); };
  return { E, m, sink, mint, commit, stop };
}

// A raw issuer process: bytes in, one parsed answer per 0x0A-ended line out.
export function rawIssuer(root: string, core: string) {
  const child = spawn(process.execPath, ["--import", "tsx", join(root, "ts/refund-finality/minter.ts"), core,
    join(root, "spec/refund/spec.lock"), "on"], { cwd: root, stdio: ["pipe", "pipe", "ignore"] });
  let buf = Buffer.alloc(0); const lines: any[] = []; let wake: (() => void) | null = null;
  child.stdout.on("data", (c: Buffer) => {
    buf = Buffer.concat([buf, c]);
    for (let i = buf.indexOf(0x0a); i >= 0; i = buf.indexOf(0x0a)) {
      const l = buf.subarray(0, i).toString("utf8"); buf = buf.subarray(i + 1);
      try { lines.push(JSON.parse(l)); } catch { lines.push({ unparsable: l }); }
    }
    if (wake) { const w = wake; wake = null; w(); }
  });
  const next = async (n: number, ms = 20000): Promise<any[]> => {
    const end = Date.now() + ms;
    while (lines.length < n && Date.now() < end) await new Promise<void>(r => { wake = r; setTimeout(r, 200); });
    return lines.slice(0, n);
  };
  return { child, lines, next, send: (b: Buffer) => child.stdin.write(b), stop: () => { child.stdin.end(); child.kill(); } };
}

export function verdict(pass: boolean, detail: unknown): never {
  console.log(JSON.stringify(detail));
  console.log(pass ? "PASS" : "FAIL");
  process.exit(pass ? 0 : 1);
}
export function guard(p: Promise<void>): void { p.catch(e => { console.error(e); process.exit(3); }); }
