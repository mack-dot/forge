// DURABLE MINT MEMORY of the issuer (Orchestrator B request after D-1 + D-2; design: orch-B/h-minter2/SINGLE_USE_2.md
// section 6). TESTED-UNPROVED. Only in PRODUCTION mode (memory rule "on" WITH the sink's store).
// WHY: with a persistent key (D-1) a restarted minter that lost its memory would sign a SECOND valid token for a request
// id it minted before and that is not settled yet. This file keeps the minted records across a restart.
// FORMAT: an append-only file of lines; one line per MINTED token (outcome Issued; never a refusal: D-2; never Closed):
//   {"bodyB64":"<the exact body bytes>","bodySha256":"<hex>","chargeId":"..","requestId":"..","v":1}\n  (canonical JSON)
// The line is written and fsync(2)ed BEFORE the token leaves the process (minter.ts writes the answer later).
// LOAD (start): the file must exist (an operator creates it EMPTY when provisioning). keyfile.ts openPrivateFile: open
// with O_RDWR | O_APPEND | O_NOFOLLOW | O_NONBLOCK, fstat on the descriptor (regular, uid == euid, no group/other
// bits, at most 256 MiB). A last line WITHOUT its 0x0A (a crash during the append) is cut (ftruncate) and reported on
// stderr. Any other damage (a line that is not canonical, a hash or body that does not match, a key twice, invalid
// UTF-8) refuses the start. Each record becomes Key(chargeId, requestId, false, "") -> Signed(bytes): exactly the key
// IssueAuth.KeyFor gives in Store mode; the map is the `m` of the ONE proved call per request (no decision here).
// LIMITS: fsync on macOS does not force the drive's cache (no F_FULLFSYNC from Node): power loss can lose the last
// records (assumption MEMORY-FILE-DURABLE). An operator who deletes or restores an old memory file gets the second-token
// case back (assumption MEMORY-FILE-INTACT); then only the sink's rule (one commit per request id) holds.
import { closeSync, constants, fstatSync, fsyncSync, ftruncateSync, readSync, writeSync } from "node:fs";
import { canon, isTokenBody, sha256hex } from "./encoding";
import { openPrivateFile } from "./keyfile";

export const MAX_MEMORY_FILE_BYTES = 256 * 1024 * 1024;
export type MintRecord = { chargeId: string; requestId: string; body: Buffer };
// One record line (sorted keys; the version is the JSON number 1).
const lineOf = (r: MintRecord): Buffer => Buffer.from("{\"bodyB64\":" + JSON.stringify(r.body.toString("base64")) + ",\"bodySha256\":" +
  JSON.stringify(sha256hex(r.body)) + ",\"chargeId\":" + JSON.stringify(r.chargeId) + ",\"requestId\":" + JSON.stringify(r.requestId) + ",\"v\":1}\n", "utf8");
const utf8 = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });

export class MintMemory {
  private constructor(private readonly fd: number, readonly records: MintRecord[], readonly cutBytes: number) {}
  static open(path: string): MintMemory {
    const fd = openPrivateFile(path, constants.O_RDWR | constants.O_APPEND, "the mint memory file", MAX_MEMORY_FILE_BYTES);
    try {
      const size = fstatSync(fd).size, all = Buffer.alloc(size);
      let n = 0;
      while (n < size) { const got = readSync(fd, all, n, size - n, n); if (got === 0) break; n += got; }
      if (n !== size) throw new Error("the mint memory file: short read");
      const last = all.lastIndexOf(0x0a), good = last + 1, cut = size - good;
      const records: MintRecord[] = [], seen = new Set<string>();
      let start = 0, line = 0;
      while (start < good) {
        const end = all.indexOf(0x0a, start); line++;
        const why = (w: string): never => { throw new Error("the mint memory file is damaged at line " + line + ": " + w); };
        let text = "";
        try { text = utf8.decode(all.subarray(start, end)); } catch { why("not UTF-8"); }
        let v: any;
        try { v = JSON.parse(text); } catch { why("not JSON"); }
        if (v === null || typeof v !== "object" || Object.keys(v).sort().join(",") !== "bodyB64,bodySha256,chargeId,requestId,v" || v.v !== 1 ||
            typeof v.bodyB64 !== "string" || typeof v.chargeId !== "string" || typeof v.requestId !== "string") why("not a record");
        const body = Buffer.from(v.bodyB64, "base64");
        if (body.toString("base64") !== v.bodyB64 || sha256hex(body) !== v.bodySha256) why("body hash");
        if (lineOf({ chargeId: v.chargeId, requestId: v.requestId, body }).toString("utf8") !== text + "\n") why("not the writer's exact line");
        let parsed: any;
        try { parsed = JSON.parse(utf8.decode(body)); } catch { why("body is not a token body"); }
        if (!isTokenBody(parsed) || canon(parsed) !== body.toString("utf8") || parsed.requestId !== v.requestId) why("body is not the record's token body");
        const k = canon([v.chargeId, v.requestId]);
        if (seen.has(k)) why("a key appears twice");
        seen.add(k); records.push({ chargeId: v.chargeId, requestId: v.requestId, body });
        start = end + 1;
      }
      if (cut > 0) { ftruncateSync(fd, good); fsyncSync(fd); }
      return new MintMemory(fd, records, cut);
    } catch (error) { closeSync(fd); throw error; }
  }
  // Appends one record and fsyncs it. Throws on any failure (the caller then answers with a refusal, not a token).
  append(r: MintRecord): void {
    const line = lineOf(r);
    let n = 0;
    while (n < line.length) n += writeSync(this.fd, line, n, line.length - n);
    fsyncSync(this.fd);
  }
}
