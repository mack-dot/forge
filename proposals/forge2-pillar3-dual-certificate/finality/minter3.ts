// Round 3 task 4 (U431): the booking minter. Own operating-system process; the Ed25519 private key exists only in
// this process's memory. The ONLY decision is the Dafny-verified, Dafny-compiled method
// BookingDualCert.VerifyCertifiedBooking (ensures ok == Accepts(...)); the proved theorem QualityAll says that an
// accepted allocation is feasible and that (10000 - alpha) * value(alt) <= 10000 * value(x) for EVERY feasible alt.
// NOT proved: this wrapper (shape check, conversion, canonical JSON, value computation, signing call), the Dafny
// JavaScript back end and runtime, Node and OpenSSL, process isolation.
import { generateKeyPairSync, sign } from "node:crypto";
import { readFileSync } from "node:fs";
import { createInterface } from "node:readline";
import { resolve } from "node:path";
import BigNumber from "bignumber.js";
import { BookingClaim, canon, isBatch, isCertificate, payload, sha256hex } from "./booking_common";

const [checkerPath] = process.argv.slice(2);
const checkerSha256 = sha256hex(readFileSync(resolve(checkerPath)));
const minterSha256 = sha256hex(Buffer.concat(["minter3.ts", "booking_common.ts", "../../forge2-pillar2-refund-finality/common.ts"]
  .map(f => readFileSync(resolve(__dirname, f)))));
const { BookingDualCert: D, runtime } = require(resolve(checkerPath));
const seq = (a: string[]) => runtime.Seq.of(...a.map(v => new BigNumber(v)));
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
process.stdout.write(JSON.stringify({ ready: true, publicKeyPem: publicKey.export({ type: "spki", format: "pem" }), checkerSha256, minterSha256 }) + "\n");
createInterface({ input: process.stdin }).on("line", line => {
  let id: unknown = null;
  try {
    const msg = JSON.parse(line);
    id = msg.id;
    const { batchId, batch, certificate, alphaBps } = msg;
    if (typeof batchId !== "string" || batchId.length > 128 || !isBatch(batch) || !isCertificate(certificate) ||
        typeof alphaBps !== "string" || !/^(0|[1-9][0-9]{0,4})$/.test(alphaBps)) throw new Error("shape");
    const ok = D.__default.VerifyCertifiedBooking(runtime.Seq.of(...batch.A.map(seq)), seq(batch.c), seq(batch.w),
      seq(certificate.x), seq(certificate.y), seq(certificate.z), new BigNumber(alphaBps));
    if (ok !== true) throw new Error("checker: not accepted");
    const value = certificate.x.reduce((s, v, j) => s + BigInt(v) * BigInt(batch.w[j]), 0n).toString();
    const claim: BookingClaim = { checkerSha256, minterSha256, batchId, instanceSha256: sha256hex(canon(batch)),
      allocation: certificate.x, alphaBps, value, certificateSha256: sha256hex(canon({ y: certificate.y, z: certificate.z })) };
    process.stdout.write(JSON.stringify({ id, ok: true, claim, sig: sign(null, payload(claim), privateKey).toString("base64") }) + "\n");
  } catch (error) {
    process.stdout.write(JSON.stringify({ id, ok: false, reason: String((error as Error).message) }) + "\n");
  }
});
