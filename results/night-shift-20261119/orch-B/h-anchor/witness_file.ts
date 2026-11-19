// h-anchor reference witness (night shift 2026-11-19, Orchestrator B). NOT on the branch. NOT proved.
// A file-based, append-only, compare-and-swap witness of the sink's row-log head, for tests.
// One file per charge in a witness directory that must NOT be the sink's directory.
// Line format (canonical JSON, one per line): {"h":<hex64>,"n":"<decimal>","prev":<hex64 or "">}
// Fails closed: a missing file (after register), a bad line, a broken link or a non-increasing count throws.
// Assumption ANCHOR-MONOTONE: nobody truncates, edits or restores this file from a backup.
import { createHash } from "node:crypto";
import { closeSync, existsSync, fsyncSync, mkdirSync, openSync, readFileSync, realpathSync, unlinkSync, writeSync } from "node:fs";
import { join } from "node:path";

export type RowHead = { n: number; h: string };
const HEX64 = /^[0-9a-f]{64}$/;
const SAFE_ID = /^[A-Za-z0-9_-]{1,128}$/;

// Canonical JSON (sorted keys; strings, booleans, arrays, plain objects only): an injective text (ENC-INJ).
export function canon(v: unknown): string {
  if (typeof v === "string") return JSON.stringify(v);
  if (typeof v === "boolean") return v ? "true" : "false";
  if (Array.isArray(v)) return "[" + v.map(canon).join(",") + "]";
  if (v !== null && typeof v === "object" && Object.getPrototypeOf(v) === Object.prototype) {
    return "{" + Object.keys(v).sort().map(k => JSON.stringify(k) + ":" + canon((v as Record<string, unknown>)[k])).join(",") + "}";
  }
  throw new Error("non-canonical value");
}
const sha = (s: string) => createHash("sha256").update(s, "utf8").digest("hex");

// h_0: binds the initial charge, the pinned ids and the issuer key. Domain-separated from a link.
export function genesisHash(initialStateText: string, specLockSha256: string, checkerSha256: string, issuerPublicKeyPem: string): string {
  return sha(canon({ domain: "forge-refund-sink-v1/genesis", initialState: initialStateText, specLockSha256, checkerSha256,
    issuerKeySha256: sha(issuerPublicKeyPem) }));
}
// h_{i+1}: binds the previous head and the committed row i+1 (token text and outbox intent text), so a
// zero-amount row, its position and its order are all bound.
export function linkHash(prev: string, tokenText: string, intentText: string): string {
  return sha(canon({ domain: "forge-refund-sink-v1/link", prev, token: tokenText, intent: intentText }));
}
export function headOf(h0: string, rows: { token: string; intent: string }[]): RowHead {
  let h = h0;
  for (const r of rows) h = linkHash(h, r.token, r.intent);
  return { n: rows.length, h };
}

export class FileWitness {
  constructor(private readonly dir: string) { mkdirSync(dir, { recursive: true }); }
  private file(chargeId: string): string {
    if (!SAFE_ID.test(chargeId)) throw new Error("witness: charge id is not a safe file name");
    return join(this.dir, chargeId + ".heads");
  }
  private read(chargeId: string): RowHead[] {
    const f = this.file(chargeId);
    if (!existsSync(f)) throw new Error("witness: no record for this charge (fail closed)");
    const out: RowHead[] = [];
    for (const line of readFileSync(f, "utf8").split("\n").filter(l => l.length > 0)) {
      const e = JSON.parse(line) as { n: string; h: string; prev: string };
      if (canon(e) !== line || !/^(0|[1-9][0-9]{0,15})$/.test(e.n) || !HEX64.test(e.h)) throw new Error("witness: bad line");
      const n = Number(e.n), last = out[out.length - 1];
      if (last === undefined ? (n !== 0 || e.prev !== "") : (n <= last.n || e.prev !== last.h)) throw new Error("witness: not one chain");
      out.push({ n, h: e.h });
    }
    if (out.length === 0) throw new Error("witness: empty record");
    return out;
  }
  // The line is computed under the lock, so the compare-and-swap check and the write are one step.
  private append(chargeId: string, makeLine: () => string, create: boolean): void {
    const f = this.file(chargeId);
    const lock = (existsSync(f) ? realpathSync(f) : f) + ".lock";
    let l: number;
    try { l = openSync(lock, "wx"); } catch { throw new Error("witness: lock is held"); }
    try {
      const line = makeLine();
      const fd = openSync(f, create ? "wx" : "a");
      try { writeSync(fd, line + "\n"); fsyncSync(fd); } finally { closeSync(fd); }
      const d = openSync(this.dir, "r"); try { fsyncSync(d); } finally { closeSync(d); }
    } finally { closeSync(l); unlinkSync(lock); }
  }
  // Once per charge: records (0, h_0). Refuses a second registration.
  register(chargeId: string, h0: string): void {
    if (!HEX64.test(h0)) throw new Error("witness: bad h0");
    this.append(chargeId, () => canon({ h: h0, n: "0", prev: "" }), true);
  }
  latestHead(chargeId: string): RowHead { const all = this.read(chargeId); return all[all.length - 1]; }
  // Compare-and-swap. The caller (the sink or the dispatcher) has checked that `next` is the head of an
  // extension of the rows whose head is `expected`. The witness refuses unless its latest head equals
  // `expected` and next.n > expected.n. (A count-only check accepts a fork that out-runs the count:
  // Anchor.dfy, C3_CountOnlyAcceptsFork.)
  publishHead(chargeId: string, expected: RowHead, next: RowHead): void {
    if (!Number.isSafeInteger(next.n) || !HEX64.test(next.h)) throw new Error("witness: bad head");
    this.latestHead(chargeId);   // fails closed before the lock if there is no valid record
    this.append(chargeId, () => {
      const latest = this.latestHead(chargeId);
      if (latest.n !== expected.n || latest.h !== expected.h) throw new Error("witness: expected head is not the latest (stale or forked)");
      if (next.n <= latest.n) throw new Error("witness: count does not increase");
      return canon({ h: next.h, n: String(next.n), prev: latest.h });
    }, false);
  }
}
