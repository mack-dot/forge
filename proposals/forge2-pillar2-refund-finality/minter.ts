// Round 2 task 3 (U420): the minter. Runs as its OWN operating-system process. It creates the Ed25519 key pair in its
// own memory and prints only the public key. It signs a claim only when the Dafny-generated refund kernel
// (impl/Refund.dfy compiled by the gate to build/refund-generated/model.cjs) authorizes exactly that refund and the
// claimed post-state and intent are the ones that follow. Research code. NOT proved: this file, the adapter, Node,
// the key isolation of the operating system.
import { generateKeyPairSync, sign } from "node:crypto";
import { readFileSync } from "node:fs";
import { createInterface } from "node:readline";
import { resolve } from "node:path";
import BigNumber from "bignumber.js";
import { Claim, canon, isClaim, payload, sha256hex } from "./common";

const [modelPath, specLockPath] = process.argv.slice(2);
const here = __dirname;
export const MINTER_FILES = ["minter.ts", "common.ts"];
const minterSha256 = sha256hex(Buffer.concat([
  ...MINTER_FILES.map(f => readFileSync(resolve(here, f))), readFileSync(resolve(modelPath))]));
const specLockSha256 = process.env.FORGE_TEST_OTHER_SPEC_LOCK ?? sha256hex(readFileSync(resolve(specLockPath)));

// Adapter to the generated module: same conversions as gate/refund/hostile.ts (tested there, not proved).
const { Refund: R, runtime } = require(resolve(modelPath));
const num = (n: bigint) => new BigNumber(String(n));
const text = (s: string) => runtime.Seq.UnicodeFromString(s);
function authorized(c: Claim): string | null {
  const ctx = R.Context.create_ChargeContext(text(c.pre.chargeId), text(c.request.requestId),
    num(BigInt(c.pre.original)), num(BigInt(c.pre.remaining)), c.pre.refundEnabled, true);
  const resp = R.ModelResponse.create_Candidate(num(BigInt(c.request.amount)), text(c.request.reason));
  const [decision, plan] = R.__default.Assess(ctx, resp);
  if (!decision.is_Authorized) return "refund kernel: Rejected";
  const items = Array.from(plan as Iterable<any>);
  if (items.length !== 1) return "refund kernel: plan length";
  const amount = BigInt(decision.dtor_amount.toFixed());
  const intent = {
    chargeId: items[0].dtor_chargeId.toVerbatimString(false), requestId: items[0].dtor_requestId.toVerbatimString(false),
    amount: BigInt(items[0].dtor_amount.toFixed()).toString(), reason: items[0].dtor_reason.toVerbatimString(false),
  };
  const post = { ...c.pre, remaining: (BigInt(c.pre.remaining) - amount).toString() };
  if (c.reqId !== c.request.requestId) return "request id mismatch";
  if (canon(c.post) !== canon(post)) return "post-state is not pre-state minus the authorized amount";
  if (canon(c.intent) !== canon(intent)) return "intent is not the kernel's intent";
  return null;
}

const { publicKey, privateKey } = generateKeyPairSync("ed25519");
process.stdout.write(JSON.stringify({
  ready: true, publicKeyPem: publicKey.export({ type: "spki", format: "pem" }), specLockSha256, minterSha256 }) + "\n");
createInterface({ input: process.stdin }).on("line", line => {
  let id: unknown = null;
  try {
    const msg = JSON.parse(line);
    id = msg.id;
    const claim: unknown = msg.claim;
    if (!isClaim(claim)) throw new Error("claim shape");
    if (claim.specLockSha256 !== specLockSha256 || claim.minterSha256 !== minterSha256) throw new Error("ids are not this minter's");
    const refusal = authorized(claim);
    if (refusal !== null) throw new Error(refusal);
    process.stdout.write(JSON.stringify({ id, ok: true, sig: sign(null, payload(claim), privateKey).toString("base64") }) + "\n");
  } catch (error) {
    process.stdout.write(JSON.stringify({ id, ok: false, reason: String((error as Error).message) }) + "\n");
  }
});
