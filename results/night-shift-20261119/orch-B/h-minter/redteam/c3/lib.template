// c3-identity helper. Loads the sink, dispatcher, encoding and proposer of a given checkout ROOT.
// "faulty signer" = a throwaway Ed25519 key that the test pins in the sink config and signs any body with it.
import { generateKeyPairSync, sign, KeyObject } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";

export function load(root: string) {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const E = require(join(root, "ts/refund-finality/encoding.ts"));
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { Sink } = require(join(root, "ts/refund-finality/sink.ts"));
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { Dispatcher } = require(join(root, "ts/refund-finality/dispatcher.ts"));
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const P = require(join(root, "ts/refund-finality/proposer.ts"));
  return { E, Sink, Dispatcher, P };
}
export const H = (c: string) => c.repeat(64);
export const SPEC = H("a"), CHK = H("b");
export function keys(): { pub: string; priv: KeyObject } {
  const k = generateKeyPairSync("ed25519");
  return { pub: k.publicKey.export({ type: "spki", format: "pem" }) as string, priv: k.privateKey };
}
// Sign ANY body (faulty signer). Returns the canonical token text.
export function forge(E: any, priv: KeyObject, body: any): string {
  const sig = sign(null, Buffer.from(E.canon(body), "utf8"), priv).toString("base64");
  return E.canon({ body, signature: sig });
}
export function body(E: any, pre: any, requestId: string, post: any, intent: any, spec = SPEC, chk = CHK) {
  return { domain: E.DOMAIN, specLockSha256: spec, checkerSha256: chk, preStateSha256: E.stateSha256(pre), requestId, post, intent };
}
export function fresh(dir: string) { rmSync(dir, { recursive: true, force: true }); mkdirSync(dir, { recursive: true }); return dir; }
export const st = (chargeId: string, original: string, remaining: string, refundEnabled = true) => ({ chargeId, original, remaining, refundEnabled });
export const it = (chargeId: string, requestId: string, amount: string, reason = "duplicate_charge") => ({ chargeId, requestId, amount, reason });
export const MINTER_CORE = "/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-minter/build/issueonce.cjs";
