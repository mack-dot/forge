// c17-hminter shared helper: raw minter driver (0x0A framing) + the hardened sink/dispatcher of the target tree.
// Target root = C7_ROOT (default fix-370ff65c). Never writes inside the target. Work files go to a dir given per script.
import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { Raw, ROOT, CORE, sha } from "./raw";
export { Raw, ROOT, CORE, sha };
/* eslint-disable @typescript-eslint/no-require-imports */
export const E = require(join(ROOT, "ts/refund-finality/encoding.ts"));
export const SINK = require(join(ROOT, "ts/refund-finality/sink.ts"));
export const DISP = require(join(ROOT, "ts/refund-finality/dispatcher.ts"));
export const STORE = require(join(ROOT, "ts/refund-finality/core/store.ts"));
/* eslint-enable @typescript-eslint/no-require-imports */
export type St = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
export const st = (c: string, o: string, r: string): St => ({ chargeId: c, original: o, remaining: r, refundEnabled: true });
export const propose = (pre: St, requestId: string, amount: string, reason = "duplicate_charge") => ({
  request: { requestId, amount, reason },
  post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() },
  intent: { chargeId: pre.chargeId, requestId, amount, reason },
});
export function fresh(dir: string): string { rmSync(dir, { recursive: true, force: true }); mkdirSync(dir, { recursive: true }); return dir; }
let nextId = 1;
// one mint over the raw pipe; returns the parsed answer, the raw line, and the token text if any
export async function mint(m: Raw, pre: unknown, t: unknown): Promise<{ ok: boolean; reason?: string; text?: string; raw: Buffer; msg: any }> {
  const id = nextId++;
  const [a] = await m.send(JSON.stringify({ id, pre, transition: t }));
  if (a.msg.id !== id) throw new Error("answer id mismatch: " + a.raw.toString());
  return a.msg.ok ? { ok: true, text: E.tokenText(a.msg.token), raw: a.raw, msg: a.msg } : { ok: false, reason: a.msg.reason, raw: a.raw, msg: a.msg };
}
export function ids(m: Raw) { return { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 }; }
export function newSink(m: Raw, path: string, s0: St, extra: Record<string, unknown> = {}) {
  const s = new SINK.Sink(path, { ...ids(m), initialState: s0, ...extra }); return s;
}
export function done(defect: boolean, detail: unknown): never {
  console.log(JSON.stringify(detail));
  console.log(defect ? "DEFECT PRESENT (exit 1)" : "SAFE (exit 0)");
  process.exit(defect ? 1 : 0);
}
export function guard(p: Promise<void>): void { p.catch(e => { console.error(e); process.exit(3); }); }
