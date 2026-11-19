// Shared helper of the dispatcher regressions d_*.ts (night shift 2026-11-19, task h-dispatch). A TEST, not a proof.
// Usage of every d_*.ts file (from any directory, pinned Node 24.3.0):
//   node --import tsx tests/refund-finality/regress/d_<name>.ts <treeRoot> <compiledIssuerModule>
// <treeRoot>: the checkout whose ts/refund-finality/{dispatcher,sink,proposer,encoding}.ts (and, for d_host_*, the
// tests/refund-finality/{dispatch,commit}_cli.ts) are under test. <compiledIssuerModule>: the module that this tree's
// minter.ts expects (this branch: the IssueOnce build).
// Exit 0: PASS (the safe outcome). Exit 1: FAIL (the defect). Exit 2: usage. Exit 3: the harness broke.
// Test keys only (D-1): each issuer process gets a NEW throwaway key FILE (kf_lib.ts). Files go to a fresh temp directory (removed at exit).
// The dispatcher config always carries newLedgerH0 (as suite.ts does), so a NEW ledger is allowed by configuration.
import { spawn } from "node:child_process";
import { makeKeyFile } from "./kf_lib";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

export type State = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
export type Effect = { requestId: string; intent: string };
export function argv(): { root: string; core: string } {
  const [root, core] = process.argv.slice(2);
  if (!root || !core) { console.error("usage: d_<name>.ts <treeRoot> <compiledIssuerModule>"); process.exit(2); }
  return { root: resolve(root), core: resolve(core) };
}
const temps: string[] = [];
process.on("exit", () => { for (const d of temps) { try { rmSync(d, { recursive: true, force: true }); } catch { /* best effort */ } } });
export function tempDir(): string { const d = mkdtempSync(join(tmpdir(), "forge-d-")); temps.push(d); return d; }

/* eslint-disable @typescript-eslint/no-require-imports */
export function load(root: string): any {
  return {
    E: require(join(root, "ts/refund-finality/encoding.ts")),
    Sink: require(join(root, "ts/refund-finality/sink.ts")).Sink,
    Dispatcher: require(join(root, "ts/refund-finality/dispatcher.ts")).Dispatcher,
    genesisOf: require(join(root, "ts/refund-finality/core/store.ts")).genesisOf,
    ...require(join(root, "ts/refund-finality/proposer.ts")),
  };
}
/* eslint-enable @typescript-eslint/no-require-imports */

// One issuer (memory rule "on"), one sink store, one ledger path, one list of effects.
export async function world(root: string, core: string, S0: State) {
  const L = load(root);
  const m = await L.MinterClient.start(root, core, join(root, "spec/refund/spec.lock"), "on", makeKeyFile().path);
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const dir = tempDir(), db = join(dir, "sink.sqlite"), ledger = join(dir, "ledger.jsonl");
  const sinkCfg = { ...ids, initialState: S0 };
  const dcfg: any = { ...ids, initialStateSha256: L.E.stateSha256(S0), newLedgerH0: L.genesisOf(L.E.canon(S0), ids.specLockSha256, ids.checkerSha256, ids.publicKeyPem) };
  let sink = new L.Sink(db, sinkCfg); sink.init(S0);
  const effects: Effect[] = [];
  // Mint a token for a pre-state; returns the token text and the post-state (no commit).
  const mint = async (pre: State, requestId: string, amount: string): Promise<{ text: string; post: State }> => {
    const t = L.propose(pre, { requestId, amount, reason: "duplicate_charge" });
    const a = await m.mint(pre, t);
    if (!a.ok) throw new Error("mint refused: " + a.reason);
    return { text: L.E.tokenText(a.token), post: t.post };
  };
  const commit = (text: string): string => sink.commit(text).status;
  const dispatcher = (emit?: (e: Effect) => void, ledgerPath = ledger, cfg: any = dcfg) =>
    new L.Dispatcher(db, ledgerPath, cfg, emit ?? ((e: Effect) => { effects.push(e); }));
  const flush = (emit?: (e: Effect) => void, ledgerPath = ledger, cfg: any = dcfg) => dispatcher(emit, ledgerPath, cfg).flush();
  const reopen = () => { try { sink.close(); } catch { /* closed */ } sink = new L.Sink(db, sinkCfg); };
  const stop = () => { try { sink.close(); } catch { /* closed */ } m.stop(); };
  return { L, ids, dir, db, ledger, sinkCfg, dcfg, effects, mint, commit, dispatcher, flush, reopen, stop, closeSink: () => sink.close() };
}

// Runs `node --import tsx <file> args...` and returns its exit code and stdout.
export function runNode(cwd: string, args: string[], env: NodeJS.ProcessEnv = { PATH: process.env.PATH ?? "/usr/bin:/bin" }): Promise<{ code: number | null; stdout: string }> {
  return new Promise(done => {
    const child = spawn(process.execPath, ["--no-warnings", "--import", "tsx", ...args], { cwd, env, stdio: ["ignore", "pipe", "ignore"] });
    let stdout = "";
    child.stdout.on("data", c => { stdout += String(c); });
    child.on("close", code => done({ code, stdout }));
  });
}
export const total = (effects: Effect[]): number => effects.reduce((s, e) => s + Number(JSON.parse(e.intent).amount), 0);
export const dups = (ids: string[]): string[] => ids.filter((x, i) => ids.indexOf(x) !== i);
export function verdict(pass: boolean, detail: unknown): never {
  console.log(JSON.stringify(detail));
  console.log(pass ? "PASS" : "FAIL");
  process.exit(pass ? 0 : 1);
}
export function guard(p: Promise<void>): void { p.catch(e => { console.error(e); process.exit(3); }); }
