// MUTANT own_d_sig_nonzero_only (h-judges2 attack input; edited copy of 74fb70eb). NOT a fix.
// Slice 1 (F2.2): the hardened store (h1) shared by the sink and the dispatcher (night shift 2026-11-19, task h-sink).
// It holds: the DDL with its triggers (the database-level safeguards S1-S6), the schema and meta checks, the row-log chain
// (S6), the exact-bytes readers (red team C-ATT-04), the integrity check (C-ATT-10/11), and the streaming audit that calls
// the compiled ShellCoreV5 fold (AInit, AuditStep, AuditEnd) once per stored commit.
// The audit is THE decision of what a stored row log means. The sink uses it at start and after a foreign change; the
// dispatcher uses it before every flush (C-ATT-06): an effect leaves only for a row that the compiled AuditStep accepted
// on the REPLAYED charge, in a store whose whole log passed AuditEnd.
// NOT proved: this file, the DDL and its triggers (TESTED-UNPROVED), SQLite, Node, the Dafny JS compiler and runtime.
import { KeyObject, verify } from "node:crypto";
import { closeSync, existsSync, lstatSync, openSync, readSync, realpathSync, statSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { ChargeState, Intent, Token, canon, isIntent, isState, isToken, sha256hex, signatureBytes, signedBytes } from "<REPO>/results/night-shift-20261119/orch-B/h-judges2/tree/ts/refund-finality/encoding";

export const MAX_TOKEN_TEXT = 8192;
// C-ATT-26 (h-sink2): the bound of a stored INTENT text. The intent is a sub-text of an accepted token (decodeToken refuses
// a token of more than MAX_TOKEN_TEXT UTF-16 units; SQLite length() counts code points, never more than UTF-16 units), so
// MAX_TOKEN_TEXT never refuses a stored intent of an accepted token. The arithmetic (encoding.ts bounds; canon = sorted keys):
// a text of <= 256 UTF-16 units is a JSON string of <= 2 + 256 * 6 = 1538 characters (U+0001 -> \u0001, 6 characters);
// money <= 19 digits. intent = {"amount":" (11) + 19 + ","chargeId": (13) + 1538 + ,"reason": (10) + R + ,"requestId": (13)
// + 1538 + } (1) = 3133 + R. R <= 1538 by encoding.ts (4671 + 10 = 4681 at most); R = 23 for the longest approved reason
// "service_not_delivered" (3166). The h1 bound 2048 refused 200 x U+0001 in both ids (2476 characters).
// State text (also checked: unchanged bound 2048): {"chargeId": (12) + 1538 + ,"original":" (13) + 19 +
// ","refundEnabled":true,"remaining":" (36) + 19 + "} (2) = 1639 <= 2048. Measured with canon: 4681, 3166, 1639.
export const MAX_INTENT_TEXT = MAX_TOKEN_TEXT;
export const STORE_FORMAT = "forge-sink-h1";
export type SinkHead = { count: number; chainHash: string };
export type Pos = { st: any; count: number; chain: string };   // compiled fold state, audited commits, chain hash after them

// ---- the row-log chain (S6) = the head of the anchor design (orch-B/h-anchor/anchor_interface.md, witness_file.ts:
// genesisHash, linkHash; the same bytes). h_0 binds the initial charge text, the pinned ids and the issuer key;
// h_{i+1} = H(canon({domain, prev: h_i, token: token text of row i+1, intent: outbox intent text of row i+1})); the
// request id is inside the token (bound to the request_id columns by trigger and audit), the seq is the position.
// The texts are the exact stored bytes: every column is read as hex and refused unless it is valid UTF-8 without U+0000.
export const genesisOf = (initText: string, specLockSha256: string, checkerSha256: string, issuerPublicKeyPem: string): string =>
  sha256hex(canon({ domain: "forge-refund-sink-v1/genesis", initialState: initText, specLockSha256, checkerSha256, issuerKeySha256: sha256hex(issuerPublicKeyPem) }));
export const linkOf = (prev: string, token: string, intent: string): string =>
  sha256hex(canon({ domain: "forge-refund-sink-v1/link", prev, token, intent }));

// ---- SQL fragments. MONEY(x): canonical decimal text of an integer in [0, 2^63 - 1]. For 19 digits without a leading
// zero, text order (BINARY collation) is number order. TXT(x, L): a TEXT value without U+0000 (byte search on the BLOB
// cast; node:sqlite cuts TEXT at U+0000 when it reads, SQL does not: C-ATT-04) and at most L characters.
const MONEY = (x: string) => `(typeof(${x}) = 'text' AND length(${x}) BETWEEN 1 AND 19 AND ${x} NOT GLOB '*[^0-9]*' AND ` +
  `(${x} = '0' OR substr(${x}, 1, 1) <> '0') AND (length(${x}) < 19 OR ${x} <= '9223372036854775807'))`;
const TXT = (x: string, l: number) => `(typeof(${x}) = 'text' AND instr(CAST(${x} AS BLOB), x'00') = 0 AND length(${x}) <= ${l})`;
const HEX64 = (x: string) => `(${TXT(x, 64)} AND length(${x}) = 64 AND ${x} NOT GLOB '*[^0-9a-f]*')`;
const INT = (x: string) => `(typeof(${x}) = 'integer')`;
const N = (x: string) => `CAST(${x} AS INTEGER)`;
// NO-OVERFLOW ARGUMENT (S4). SQLite INTEGER is 64-bit signed; M = 2^63 - 1. (1) CAST of a MONEY text is exact and in [0, M].
// (2) Every subtraction below has both operands in [0, M] when the guards before it hold, so its result is in [-M, M]:
// exact. (3) The one addition, refunded + amount, is compared only together with amount <= original - refunded, so the
// sum is <= original <= M: exact. (4) The guards and the arithmetic are conjuncts of ONE condition; SQLite turns an
// overflowing + or - into a REAL (no wrap-around, no error), so if a guard is false the condition is 0 or NULL and the
// trigger raises, whatever value another conjunct computed. (5) The cumulative sum is never computed by a scan: the
// state column refunded is that sum by induction (0 at the meta insert; + amount at each commit; rows are append-only).
// Every check is `(...) IS NOT 1`, so a NULL (a missing row) raises too.
export const DDL_STATEMENTS: string[] = [
  `CREATE TABLE meta(id INTEGER PRIMARY KEY CHECK (id = 1), format TEXT NOT NULL CHECK ${TXT("format", 64)},
     charge_id TEXT NOT NULL CHECK ${TXT("charge_id", 256)}, initial_state TEXT NOT NULL CHECK ${TXT("initial_state", 2048)},
     initial_state_sha256 TEXT NOT NULL CHECK ${HEX64("initial_state_sha256")}, genesis TEXT NOT NULL CHECK ${HEX64("genesis")})`,
  `CREATE TABLE state(id INTEGER PRIMARY KEY CHECK (id = 1), blob TEXT NOT NULL CHECK ${TXT("blob", 2048)},
     seq INTEGER NOT NULL CHECK (${INT("seq")} AND seq >= 0), refunded INTEGER NOT NULL CHECK (${INT("refunded")} AND refunded >= 0))`,
  `CREATE TABLE settled(seq INTEGER PRIMARY KEY CHECK (seq >= 1), request_id TEXT NOT NULL UNIQUE CHECK ${TXT("request_id", 256)},
     token TEXT NOT NULL CHECK ${TXT("token", MAX_TOKEN_TEXT)}, token_sha256 TEXT NOT NULL CHECK ${HEX64("token_sha256")},
     prev TEXT NOT NULL CHECK ${HEX64("prev")}, self TEXT NOT NULL CHECK ${HEX64("self")},
     CHECK (request_id = json_extract(token, '$.body.requestId')))`,
  `CREATE TABLE outbox(seq INTEGER PRIMARY KEY CHECK (seq >= 1), request_id TEXT NOT NULL UNIQUE CHECK ${TXT("request_id", 256)},
     intent TEXT NOT NULL CHECK ${TXT("intent", MAX_INTENT_TEXT)}, prev TEXT NOT NULL CHECK ${HEX64("prev")}, self TEXT NOT NULL CHECK ${HEX64("self")},
     CHECK (request_id = json_extract(intent, '$.requestId')))`,
  `CREATE TRIGGER h_meta_bi BEFORE INSERT ON meta BEGIN
     SELECT RAISE(ABORT, 'h-sink S3: meta is written once, into an empty store')
       WHERE EXISTS (SELECT 1 FROM meta) OR EXISTS (SELECT 1 FROM state) OR EXISTS (SELECT 1 FROM settled) OR EXISTS (SELECT 1 FROM outbox);
     SELECT RAISE(ABORT, 'h-sink S7: meta initial state is not a valid canonical charge')
       FROM (SELECT json_extract(NEW.initial_state, '$.chargeId') AS c, json_extract(NEW.initial_state, '$.original') AS o,
                    json_extract(NEW.initial_state, '$.remaining') AS r) AS v
       WHERE (NEW.id = 1 AND NEW.format = '${STORE_FORMAT}' AND ${TXT("NEW.initial_state", 2048)} AND ${TXT("NEW.charge_id", 256)}
         AND typeof(v.c) = 'text' AND length(v.c) > 0 AND NEW.charge_id = v.c
         AND ${MONEY("v.o")} AND ${MONEY("v.r")} AND ${N("v.r")} <= ${N("v.o")}
         AND NEW.initial_state = '{"chargeId":' || json_quote(v.c) || ',"original":"' || v.o || '","refundEnabled":true,"remaining":"' || v.r || '"}'
         AND ${HEX64("NEW.initial_state_sha256")} AND ${HEX64("NEW.genesis")}) IS NOT 1;
   END`,
  `CREATE TRIGGER h_meta_ai AFTER INSERT ON meta BEGIN
     INSERT INTO state(id, blob, seq, refunded) VALUES (1, NEW.initial_state, 0, 0);
   END`,
  `CREATE TRIGGER h_meta_bu BEFORE UPDATE ON meta BEGIN SELECT RAISE(ABORT, 'h-sink S3: meta is immutable'); END`,
  `CREATE TRIGGER h_meta_bd BEFORE DELETE ON meta BEGIN SELECT RAISE(ABORT, 'h-sink S3: meta is immutable'); END`,
  `CREATE TRIGGER h_state_bi BEFORE INSERT ON state BEGIN
     SELECT RAISE(ABORT, 'h-sink S2: the state row is made only by the meta insert')
       WHERE (NEW.id = 1 AND ${INT("NEW.seq")} AND NEW.seq = 0 AND ${INT("NEW.refunded")} AND NEW.refunded = 0
         AND NEW.blob = (SELECT initial_state FROM meta WHERE id = 1) AND NOT EXISTS (SELECT 1 FROM state)
         AND NOT EXISTS (SELECT 1 FROM settled) AND NOT EXISTS (SELECT 1 FROM outbox)) IS NOT 1;
   END`,
  `CREATE TRIGGER h_state_bu BEFORE UPDATE ON state BEGIN
     SELECT RAISE(ABORT, 'h-sink S2/S4: the state changes only by one commit (seq + 1; remaining - amount; refunded + amount; nothing else)')
       FROM (SELECT x.*, json_extract(x.i, '$.amount') AS a, json_extract(OLD.blob, '$.remaining') AS r0,
                    json_extract(NEW.blob, '$.remaining') AS r1, json_extract(OLD.blob, '$.original') AS org
             FROM (SELECT (SELECT intent FROM outbox WHERE seq = NEW.seq) AS i, (SELECT token FROM settled WHERE seq = NEW.seq) AS t,
                          (SELECT max(seq) FROM settled) AS ms, (SELECT max(seq) FROM outbox) AS mo,
                          (SELECT charge_id FROM meta WHERE id = 1) AS cid,
                          (SELECT json_extract(initial_state, '$.remaining') FROM meta WHERE id = 1) AS ri) AS x) AS v
       WHERE (NEW.id = 1 AND OLD.id = 1 AND ${INT("NEW.seq")} AND NEW.seq = OLD.seq + 1 AND NEW.seq = v.ms AND NEW.seq = v.mo
         AND ${TXT("NEW.blob", 2048)} AND ${MONEY("v.a")} AND ${MONEY("v.r0")} AND ${MONEY("v.r1")} AND ${MONEY("v.org")} AND ${MONEY("v.ri")}
         AND ${INT("OLD.refunded")} AND ${INT("NEW.refunded")} AND OLD.refunded >= 0 AND OLD.refunded <= ${N("v.org")}
         AND ${N("v.a")} <= ${N("v.r0")} AND ${N("v.a")} <= ${N("v.org")} - OLD.refunded
         AND NEW.refunded = OLD.refunded + ${N("v.a")}
         AND ${N("v.r1")} = ${N("v.r0")} - ${N("v.a")} AND ${N("v.r1")} = ${N("v.ri")} - NEW.refunded
         AND substr(OLD.blob, -(length(v.r0) + 15)) = '"remaining":"' || v.r0 || '"}'
         AND NEW.blob = substr(OLD.blob, 1, length(OLD.blob) - length(v.r0) - 2) || v.r1 || '"}'
         AND NEW.blob = json_extract(v.t, '$.body.post')
         AND json_extract(NEW.blob, '$.chargeId') = v.cid AND json_extract(v.i, '$.chargeId') = v.cid) IS NOT 1;
   END`,
  `CREATE TRIGGER h_state_bd BEFORE DELETE ON state BEGIN SELECT RAISE(ABORT, 'h-sink S5: the state row is never deleted'); END`,
  `CREATE TRIGGER h_settled_bi BEFORE INSERT ON settled BEGIN
     SELECT RAISE(ABORT, 'h-sink S1/S2/S3/S6: a settled row must be the next commit of this store')
       FROM (SELECT (SELECT seq FROM state WHERE id = 1) AS sq, (SELECT max(seq) FROM settled) AS ms, (SELECT max(seq) FROM outbox) AS mo,
                    (SELECT charge_id FROM meta WHERE id = 1) AS cid, (SELECT genesis FROM meta WHERE id = 1) AS g,
                    (SELECT self FROM outbox WHERE seq = NEW.seq - 1) AS ps) AS v
       WHERE (${INT("NEW.seq")} AND NEW.seq = v.sq + 1 AND NEW.seq = coalesce(v.ms, 0) + 1 AND NEW.seq = coalesce(v.mo, 0) + 1
         AND NOT EXISTS (SELECT 1 FROM settled WHERE request_id = NEW.request_id) AND NOT EXISTS (SELECT 1 FROM outbox WHERE request_id = NEW.request_id)
         AND ${TXT("NEW.request_id", 256)} AND ${TXT("NEW.token", MAX_TOKEN_TEXT)} AND json_valid(NEW.token)
         AND NEW.request_id = json_extract(NEW.token, '$.body.requestId') AND NEW.request_id = json_extract(NEW.token, '$.body.intent.requestId')
         AND json_extract(NEW.token, '$.body.intent.chargeId') = v.cid AND json_extract(NEW.token, '$.body.post.chargeId') = v.cid
         AND ${HEX64("NEW.token_sha256")} AND ${HEX64("NEW.self")}
         AND NEW.prev = (CASE WHEN NEW.seq = 1 THEN v.g ELSE v.ps END)) IS NOT 1;
   END`,
  `CREATE TRIGGER h_settled_ai AFTER INSERT ON settled BEGIN
     INSERT INTO outbox(seq, request_id, intent, prev, self) VALUES (NEW.seq, NEW.request_id, json_extract(NEW.token, '$.body.intent'), NEW.prev, NEW.self);
     UPDATE state SET blob = json_extract(NEW.token, '$.body.post'), seq = NEW.seq,
       refunded = refunded + CAST(json_extract(NEW.token, '$.body.intent.amount') AS INTEGER) WHERE id = 1;
     SELECT RAISE(ABORT, 'h-sink S2: the commit did not reach the state row') WHERE (SELECT seq FROM state WHERE id = 1) IS NOT NEW.seq;
   END`,
  `CREATE TRIGGER h_settled_bu BEFORE UPDATE ON settled BEGIN SELECT RAISE(ABORT, 'h-sink S5: settled is append-only'); END`,
  `CREATE TRIGGER h_settled_bd BEFORE DELETE ON settled BEGIN SELECT RAISE(ABORT, 'h-sink S5: settled is append-only'); END`,
  `CREATE TRIGGER h_outbox_bi BEFORE INSERT ON outbox BEGIN
     SELECT RAISE(ABORT, 'h-sink S1/S2/S4: an outbox row is written only by its settled row, within the cumulative limit')
       FROM (SELECT x.*, json_extract(NEW.intent, '$.amount') AS a, json_extract(x.blob, '$.remaining') AS r0, json_extract(x.blob, '$.original') AS org
             FROM (SELECT (SELECT blob FROM state WHERE id = 1) AS blob, (SELECT seq FROM state WHERE id = 1) AS sq,
                          (SELECT refunded FROM state WHERE id = 1) AS rf, (SELECT max(seq) FROM settled) AS ms,
                          (SELECT max(seq) FROM outbox) AS mo, (SELECT charge_id FROM meta WHERE id = 1) AS cid) AS x) AS v
       WHERE (${INT("NEW.seq")} AND NEW.seq = v.ms AND NEW.seq = coalesce(v.mo, 0) + 1 AND NEW.seq = v.sq + 1
         AND EXISTS (SELECT 1 FROM settled s WHERE s.seq = NEW.seq AND s.request_id = NEW.request_id AND s.prev = NEW.prev
                     AND s.self = NEW.self AND json_extract(s.token, '$.body.intent') = NEW.intent)
         AND NOT EXISTS (SELECT 1 FROM outbox WHERE request_id = NEW.request_id)
         AND ${TXT("NEW.request_id", 256)} AND ${TXT("NEW.intent", MAX_INTENT_TEXT)} AND json_valid(NEW.intent) AND NEW.request_id = json_extract(NEW.intent, '$.requestId')
         AND json_extract(NEW.intent, '$.chargeId') = v.cid
         AND ${MONEY("v.a")} AND ${MONEY("v.r0")} AND ${MONEY("v.org")} AND ${INT("v.rf")} AND v.rf >= 0 AND v.rf <= ${N("v.org")}
         AND ${N("v.a")} <= ${N("v.r0")} AND ${N("v.a")} <= ${N("v.org")} - v.rf) IS NOT 1;
   END`,
  `CREATE TRIGGER h_outbox_bu BEFORE UPDATE ON outbox BEGIN SELECT RAISE(ABORT, 'h-sink S5: outbox is append-only'); END`,
  `CREATE TRIGGER h_outbox_bd BEFORE DELETE ON outbox BEGIN SELECT RAISE(ABORT, 'h-sink S5: outbox is append-only'); END`,
];
export const SINK_DDL = DDL_STATEMENTS.map(s => s + ";").join("\n");
// The schema TEXT check: every row of sqlite_schema (type, name, tbl_name, sql after whitespace normalisation) must equal
// what DDL makes in an empty database. It compares TEXT only: b-trees and root pages are checked by integrity_check below.
export const schemaRows = (db: DatabaseSync): string =>
  JSON.stringify((db.prepare("SELECT type, name, tbl_name, sql FROM sqlite_schema ORDER BY type, name").all() as any[])
    .map(r => [r.type, r.name, r.tbl_name, r.sql === null ? null : String(r.sql).replace(/\s+/g, " ").trim()]));
export const EXPECTED_SCHEMA = (() => { const m = new DatabaseSync(":memory:"); m.exec(SINK_DDL); const s = schemaRows(m); m.close(); return s; })();
// C-ATT-02: the WHOLE schema in ONE transaction (SQLite DDL is transactional). Only into a file with no committed schema.
export function createSchema(db: DatabaseSync): void {
  db.exec("BEGIN IMMEDIATE");
  try {
    if ((db.prepare("SELECT COUNT(*) AS n FROM sqlite_schema").get() as any).n === 0) for (const s of DDL_STATEMENTS) db.exec(s);
    db.exec("COMMIT");
  } catch (error) { try { db.exec("ROLLBACK"); } catch { /* none */ } throw error; }
}
// C-ATT-21 (h-sink2): the non-row header values that the sink never sets. A planted journal can carry any page content,
// also page 1 (header). Refused unless 0. NOT checked: the schema cookie (PRAGMA schema_version): every DROP or CREATE
// bumps it, but any SQLite writer can set it back (PRAGMA schema_version = N), and the schema TEXT compare and
// integrity_check already decide what the schema is (see HARDENING_NOTES_2.md, item 5).
export function headerOk(db: DatabaseSync): void {
  const u = Number((db.prepare("PRAGMA user_version").get() as any).user_version), a = Number((db.prepare("PRAGMA application_id").get() as any).application_id);
  if (u !== 0 || a !== 0) throw new Error("database header: user_version " + u + ", application_id " + a + " (the sink never sets them; expected 0, 0)");
}

// ---- the database FILES (C-ATT-21, C-ATT-23; h-sink2). Assumption DIR-EXCLUSIVE: no other party can create, replace,
// rename or link files in the database directory. Without it, what these checks still see is listed in
// HARDENING_NOTES_2.md (item 5). The checks run BEFORE the first SQLite lock (a hot journal is applied by SQLite at the
// first shared lock, before any audit can run) and again before every write transaction of the sink.
export type StoreFile = { path: string; real: string; dev: number; ino: number | bigint };
export const COMPANIONS = ["-journal", "-wal", "-shm"] as const;
// The name SQLite uses for the companions: the unix VFS resolves symbolic links of the database path.
export function realStorePath(path: string): string {
  return existsSync(path) ? realpathSync(path) : join(realpathSync(dirname(path)), basename(path));
}
export function presentCompanions(path: string, which: readonly string[] = COMPANIONS): string[] {
  const names = new Set([path, realStorePath(path)]), found = new Set<string>();
  for (const n of names) for (const c of which) if (existsSync(n + c)) found.add(realpathSync(n + c));
  return [...found];
}
// Refuses: a database that is not one regular file with ONE name (st_nlink 1; C-ATT-23), a header in WAL mode, and any
// companion file named in `refuse` (the sink: all three; the read-only dispatcher: -wal and -shm, because a live sink's
// own -journal exists during its write transactions). Returns the identity of the file (dev, ino) or undefined (no file).
export function checkStoreFile(path: string, refuse: readonly string[] = COMPANIONS): StoreFile | undefined {
  const real = realStorePath(path);
  const planted = presentCompanions(path, refuse);
  if (planted.length > 0) throw new Error("companion file(s) present: " + planted.join(", ") + " (the sink did not expect them; after a crash, run the operator step Sink.recover)");
  if (!existsSync(real)) return undefined;
  const st = lstatSync(real);
  if (!st.isFile()) throw new Error("the database path is not a regular file");
  if (st.nlink !== 1) throw new Error("the database file has " + st.nlink + " hard links (two names of one database lose commits after a crash: C-ATT-23)");
  if (st.size > 0) {
    const h = Buffer.alloc(100), fd = openSync(real, "r");
    let n = 0;
    try { n = readSync(fd, h, 0, 100, 0); } finally { closeSync(fd); }
    if (n < 100 || h.subarray(0, 16).toString("latin1") !== "SQLite format 3\u0000") throw new Error("the database file has no SQLite header");
    if (h[18] !== 1 || h[19] !== 1) throw new Error("the database header is not in rollback-journal mode (bytes 18, 19 = " + h[18] + ", " + h[19] + "; WAL is 2, 2)");
  }
  return { path, real, dev: st.dev, ino: st.ino };
}
// The same file, still one name, no -wal and no -shm (before each write transaction of a running sink). A -journal is
// refused only for a SINGLE writer (cfg.outsideHead): with several honest writers it exists legitimately during another
// connection's write transaction; its effect on content is then seen by the foreign-change check after the lock
// (prefixSame + auditFrom).
export function sameStoreFile(f: StoreFile, singleWriter = false): string {
  try {
    const st = statSync(f.real);
    if (st.dev !== f.dev || st.ino !== f.ino) return "the database file was replaced (another inode at the path)";
    if (st.nlink !== 1) return "the database file has " + st.nlink + " hard links";
  } catch (error) { return "the database file cannot be checked: " + String((error as Error).message); }
  const planted = presentCompanions(f.path, singleWriter ? COMPANIONS : ["-wal", "-shm"]);
  return planted.length > 0 ? "companion file(s) present: " + planted.join(", ") : "";
}

// C-ATT-10/11: the FULL integrity check (every index agrees with its table; every b-tree is well formed). `ok` or refuse.
export function integrityOk(db: DatabaseSync): void {
  const r = db.prepare("PRAGMA integrity_check").all() as any[];
  if (r.length !== 1 || r[0].integrity_check !== "ok") throw new Error("PRAGMA integrity_check is not ok: " + JSON.stringify(r.slice(0, 3)).slice(0, 200));
}

// ---- exact-bytes readers (C-ATT-04). A column is read as typeof + hex; it must be TEXT, valid UTF-8, without U+0000.
export function hexText(ty: unknown, hx: unknown, what: string): string {
  if (ty !== "text" || typeof hx !== "string") throw new Error(what + " is not TEXT");
  const b = Buffer.from(hx, "hex"), s = b.toString("utf8");
  if (!Buffer.from(s, "utf8").equals(b) || s.includes("\u0000")) throw new Error(what + " is not UTF-8 text without U+0000");
  return s;
}
const col = (c: string, t = "") => `typeof(${t}${c}) AS ${c}_t, hex(${t}${c}) AS ${c}_h`;
export function readStateBlob(db: DatabaseSync): string | undefined {
  const r = db.prepare(`SELECT ${col("blob")} FROM state WHERE id = 1`).get() as any;
  return r === undefined ? undefined : hexText(r.blob_t, r.blob_h, "state blob");
}
export type MetaRow = { format: string; charge_id: string; initial_state: string; initial_state_sha256: string; genesis: string };
export function readMeta(db: DatabaseSync): MetaRow | undefined {
  const rs = db.prepare(`SELECT id, ${["format", "charge_id", "initial_state", "initial_state_sha256", "genesis"].map(c => col(c)).join(", ")} FROM meta`).all() as any[];
  if (rs.length === 0) return undefined;
  if (rs.length !== 1 || rs[0].id !== 1) throw new Error("meta is not one row");
  const r = rs[0], m: any = {};
  for (const c of ["format", "charge_id", "initial_state", "initial_state_sha256", "genesis"]) m[c] = hexText(r[c + "_t"], r[c + "_h"], "meta " + c);
  return m as MetaRow;
}

// ---- the compiled core (dafny build --target js through the lock script)
const CORE_FILE = "<REPO>/results/night-shift-20261119/orch-B/h-judges2/tree/ts/refund-finality/core/sinkcore-v6.cjs";
export type CoreMod = { Shell6: any; Shell5: any; Shell4: any; Shell: any; C: any; F: any; R: any; rt: any; BigNumber: any };
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const loadCore = (): CoreMod => require(CORE_FILE);
// Conversion between TypeScript values and core values. Pure maps; no branch on content.
export const conv = (M: CoreMod) => {
  const T = (s: string) => M.rt.Seq.UnicodeFromString(s);
  const Nm = (s: string) => new M.BigNumber(s);
  const S = (x: any): string => x.toVerbatimString(false);
  const D = (n: any): string => n.toFixed();
  return {
    charge: (s: ChargeState) => M.F.Charge.create_Charge(T(s.chargeId), Nm(s.original), Nm(s.remaining), s.refundEnabled),
    intent: (i: Intent) => M.R.RefundIntent.create_Intent(T(i.chargeId), T(i.requestId), Nm(i.amount), T(i.reason)),
    text: T, back: S,
    backCharge: (c: any): ChargeState => ({ chargeId: S(c.dtor_chargeId), original: D(c.dtor_original), remaining: D(c.dtor_remaining), refundEnabled: c.dtor_refundEnabled }),
    backIntent: (i: any): Intent => ({ chargeId: S(i.dtor_chargeId), requestId: S(i.dtor_requestId), amount: D(i.dtor_amount), reason: S(i.dtor_reason) }),
  };
};
export type Conv = ReturnType<typeof conv>;
// A loaded value that does not decode stops the audit or transaction (an exception: fail-closed, no write).
export function must<X>(ok: boolean, x: X, what: string): X { if (!ok) throw new Error("stored " + what + " does not decode"); return x; }
// THE decoder (K1), unchanged from sink.ts; used by commit(), by the audit and so by the dispatcher. It can only refuse.
export function decodeToken(input: unknown): Token | string {
  if (typeof input !== "string") return "token is not a text";
  if (input.length > MAX_TOKEN_TEXT) return "token shape";
  let token: unknown;
  try { token = JSON.parse(input); } catch { return "token shape"; }
  if (!isToken(token)) return "token shape";
  if (canon(token) !== input) return "token text is not canonical";
  return token;
}
export const isHead = (h: unknown): h is SinkHead => h !== null && typeof h === "object" && Number.isSafeInteger((h as any).count) &&
  (h as any).count >= 0 && typeof (h as any).chainHash === "string" && /^[0-9a-f]{64}$/.test((h as any).chainHash);
export function sigOkOf(key: KeyObject, token: Token): boolean {
  if ((token.body as any).intent.amount === "0") return true;
  try { const raw = signatureBytes(token.signature); return raw !== null && verify(null, signedBytes(token.body), key, raw); } catch { return false; }
}
// S7: the compiled check of the core (Refund.ValidContext of RefundFinality.ContextOf(initial, "init")).
export function validInitial(M: CoreMod, cv: Conv, s: ChargeState): boolean {
  return isState(s) && M.R.__default.ValidContext(M.F.__default.ContextOf(cv.charge(s), cv.text("init"))) === true;
}

// One audited commit as read from the store (exact bytes).
export type AuditedRow = { seq: number; requestId: string; token: string; tokenSha256: string; intent: string; self: string; body: Token["body"] };
export type Ids = { specLockSha256: string; checkerSha256: string; publicKeyPem: string };

// The auditor: one supplied initial charge (THE ANCHOR), one key, one pair of pinned ids.
export class StoreAuditor {
  readonly initText: string; readonly initCore: any; readonly genesis: string;
  constructor(readonly M: CoreMod, readonly cv: Conv, readonly key: KeyObject, readonly ids: Ids, readonly init: ChargeState) {
    this.initText = canon(init); this.initCore = cv.charge(init); this.genesis = genesisOf(this.initText, ids.specLockSha256, ids.checkerSha256, ids.publicKeyPem);
  }
  start(): Pos { return { st: this.M.Shell5.__default.AInit(this.initCore), count: 0, chain: this.genesis }; }
  // Schema TEXT, integrity, meta. true: a store with a meta row; false: a fresh one; throws to refuse.
  schemaAndMeta(db: DatabaseSync): boolean {
    if (schemaRows(db) !== EXPECTED_SCHEMA) throw new Error("schema text (tables, indexes, triggers) is not the sink's DDL");
    integrityOk(db);
    headerOk(db);
    const m = readMeta(db);
    if (m === undefined) return false;
    if (m.format !== STORE_FORMAT || m.charge_id !== this.init.chargeId || m.initial_state !== this.initText ||
        m.initial_state_sha256 !== sha256hex(this.initText) || m.genesis !== this.genesis) throw new Error("meta is not the supplied initial charge");
    return true;
  }
  // Schema, integrity, meta, the full fold from AInit, the chain from genesis, the anchor. The audited position or null.
  fullAudit(db: DatabaseSync, anchor?: SinkHead, onRow?: (r: AuditedRow) => void): Pos | null {
    const fresh = !this.schemaAndMeta(db);
    const stored = readStateBlob(db);                 // read only after the schema text check
    if (fresh) {
      const n = (db.prepare("SELECT (SELECT COUNT(*) FROM state) + (SELECT COUNT(*) FROM settled NOT INDEXED) + (SELECT COUNT(*) FROM outbox NOT INDEXED) AS n").get() as any).n;
      return n === 0 && (anchor === undefined || (anchor.count === 0 && anchor.chainHash === this.genesis)) ? this.start() : null;
    }
    if (stored === undefined) throw new Error("meta row without state row");
    return this.auditFrom(db, this.start(), stored, anchor, onRow);
  }
  // The streaming AuditV5 from an audited position: rows with seq > from.count, settled and outbox zipped in seq (rowid)
  // order, read NOT INDEXED and as exact bytes; constant core state. Then AuditEnd over the whole store, with the counts
  // computed from the TABLE rows (NOT INDEXED; C-ATT-10), and the state row's seq and refunded columns.
  // From AInit this is the v6 audit plus the chain; from a kept position it is the resumed fold (ShellCoreV5.FoldResume:
  // proved for the in-memory fold; this loop is TESTED-UNPROVED against it).
  auditFrom(db: DatabaseSync, from: Pos, stored: string, anchor?: SinkHead, onRow?: (r: AuditedRow) => void): Pos | null {
    const { M, cv } = this, S5 = M.Shell5.__default;
    const sv = JSON.parse(stored);
    must(isState(sv) && canon(sv) === stored, sv, "state");
    const storedCore = cv.charge(sv);
    const initId = this.initCore.dtor_chargeId;
    const si = db.prepare(`SELECT seq, ${["request_id", "token", "token_sha256", "prev", "self"].map(c => col(c)).join(", ")} FROM settled NOT INDEXED WHERE seq > ? ORDER BY seq`).iterate(from.count) as Iterator<any>;
    const oi = db.prepare(`SELECT seq, ${["request_id", "intent", "prev", "self"].map(c => col(c)).join(", ")} FROM outbox NOT INDEXED WHERE seq > ? ORDER BY seq`).iterate(from.count) as Iterator<any>;
    let { st, count, chain } = from;
    if (anchor !== undefined && anchor.count < count) return null;    // an anchor is checked by a full audit only
    let anchorOk = anchor === undefined || (anchor.count === count && anchor.chainHash === chain);
    try {
      for (;;) {
        const a = si.next(), b = oi.next();
        if (a.done || b.done) break;
        const s = a.value, o = b.value, k = count + 1;
        if (s.seq !== k || o.seq !== k) throw new Error("row " + k + ": seq is not contiguous");
        const rid = hexText(s.request_id_t, s.request_id_h, "settled request_id"), tokenText = hexText(s.token_t, s.token_h, "settled token");
        const tsha = hexText(s.token_sha256_t, s.token_sha256_h, "settled token_sha256"), sprev = hexText(s.prev_t, s.prev_h, "settled prev");
        const sself = hexText(s.self_t, s.self_h, "settled self"), orid = hexText(o.request_id_t, o.request_id_h, "outbox request_id");
        const intent = hexText(o.intent_t, o.intent_h, "outbox intent"), oprev = hexText(o.prev_t, o.prev_h, "outbox prev"), oself = hexText(o.self_t, o.self_h, "outbox self");
        const tk = decodeToken(tokenText);
        if (typeof tk === "string") throw new Error("stored token does not decode: " + tk);
        if (sha256hex(tokenText) !== tsha) throw new Error("stored token_sha256 is not the token's hash");
        const iv = JSON.parse(intent);
        must(isIntent(iv) && canon(iv) === intent, iv, "intent");
        if (iv.requestId !== orid) throw new Error("outbox request_id column is not its intent's request id");
        // S6: the chain link over the exact stored texts, recomputed here (SQLite cannot hash).
        const self = linkOf(chain, tokenText, intent);
        if (sprev !== chain || oprev !== chain || sself !== self || oself !== self) throw new Error("row " + k + ": chain link");
        const body = tk.body;
        const sigOk = sigOkOf(this.key, tk);
        const preOk = sha256hex(canon(cv.backCharge(st.dtor_cur))) === body.preStateSha256;   // A4' on the replay
        const t = M.Shell.ShellToken.create_ShellToken(
          new M.BigNumber(body.specLockSha256 === this.ids.specLockSha256 ? 1 : 0), new M.BigNumber(body.checkerSha256 === this.ids.checkerSha256 ? 2 : 0),
          cv.text(body.requestId), cv.charge(body.post), cv.intent(body.intent), cv.text(""));
        st = S5.AuditStep(initId, st, M.Shell5.Row.create_Row(cv.text(rid), t, sigOk, preOk, cv.intent(iv)));
        if (st.dtor_ok !== true) throw new Error("row " + k + ": the compiled AuditStep refuses it (signature, ids, bindings, pre-state or the approved relation)");
        count = k; chain = self;
        if (anchor !== undefined && anchor.count === k) anchorOk = anchor.chainHash === chain;
        onRow?.({ seq: k, requestId: rid, token: tokenText, tokenSha256: tsha, intent, self, body });
      }
    } finally { (si as any).return?.(); (oi as any).return?.(); }
    const c = db.prepare("SELECT (SELECT COUNT(*) FROM settled NOT INDEXED) AS ns, (SELECT COUNT(*) FROM outbox NOT INDEXED) AS no, " +
      "(SELECT COUNT(DISTINCT request_id) FROM settled NOT INDEXED) AS nd, (SELECT COUNT(DISTINCT request_id) FROM outbox NOT INDEXED) AS nod, " +
      "(SELECT seq FROM state WHERE id = 1) AS sq, (SELECT CAST(refunded AS TEXT) FROM state WHERE id = 1) AS rf, (SELECT typeof(refunded) FROM state WHERE id = 1) AS rft").get() as any;
    const B = (x: any) => new M.BigNumber(x);
    const refundedOk = c.sq === count && c.rft === "integer" && BigInt(c.rf) === BigInt(this.init.remaining) - BigInt(sv.remaining);
    const ok = anchorOk && refundedOk && c.nod === c.no && S5.AuditEnd(this.initCore, storedCore, st, B(c.ns), B(c.no), B(c.nd)) === true;
    return ok ? { st, count, chain } : null;
  }
  // C-ATT-24 (h-sink2): rows 1..p.count are still EXACTLY the audited rows: every column of settled and outbox read as exact
  // bytes, the request id columns equal to the kept ids, token_sha256 recomputed, prev/self equal to the chain recomputed
  // from genesis over the stored token and intent texts, and the final link equal to the kept chain hash p.chain. No
  // signature check (each row was audited when it was first read; the kept chain hash binds its texts; SHA-256 assumed).
  // O(n) hashing, no Ed25519: run on a foreign change only.
  prefixSame(db: DatabaseSync, p: Pos, rids: readonly string[]): boolean {
    if (rids.length !== p.count) return false;
    const si = db.prepare(`SELECT seq, ${["request_id", "token", "token_sha256", "prev", "self"].map(c => col(c)).join(", ")} FROM settled NOT INDEXED WHERE seq <= ? ORDER BY seq`).iterate(p.count) as Iterator<any>;
    const oi = db.prepare(`SELECT seq, ${["request_id", "intent", "prev", "self"].map(c => col(c)).join(", ")} FROM outbox NOT INDEXED WHERE seq <= ? ORDER BY seq`).iterate(p.count) as Iterator<any>;
    let chain = this.genesis, k = 0;
    try {
      for (;;) {
        const a = si.next(), b = oi.next();
        if (a.done !== b.done) return false;
        if (a.done) break;
        const s = a.value, o = b.value; k++;
        if (s.seq !== k || o.seq !== k) return false;
        const rid = rids[k - 1], token = hexText(s.token_t, s.token_h, "token"), intent = hexText(o.intent_t, o.intent_h, "intent");
        if (hexText(s.request_id_t, s.request_id_h, "request_id") !== rid || hexText(o.request_id_t, o.request_id_h, "request_id") !== rid) return false;
        if (hexText(s.token_sha256_t, s.token_sha256_h, "tsha") !== sha256hex(token)) return false;
        if (hexText(s.prev_t, s.prev_h, "prev") !== chain || hexText(o.prev_t, o.prev_h, "prev") !== chain) return false;
        const self = linkOf(chain, token, intent);
        if (hexText(s.self_t, s.self_h, "self") !== self || hexText(o.self_t, o.self_h, "self") !== self) return false;
        chain = self;
      }
    } finally { (si as any).return?.(); (oi as any).return?.(); }
    return k === p.count && chain === p.chain;
  }
  // The head row of a kept position is still the same row (exact bytes; its link recomputed).
  headRowSame(db: DatabaseSync, p: Pos): boolean {
    if (p.count === 0) return true;
    const s = db.prepare(`SELECT ${["request_id", "token", "token_sha256", "prev", "self"].map(c => col(c)).join(", ")} FROM settled WHERE seq = ?`).get(p.count) as any;
    const o = db.prepare(`SELECT ${["intent", "prev", "self"].map(c => col(c)).join(", ")} FROM outbox WHERE seq = ?`).get(p.count) as any;
    if (s === undefined || o === undefined) return false;
    const prev = hexText(s.prev_t, s.prev_h, "prev");
    return hexText(s.self_t, s.self_h, "self") === p.chain && hexText(o.self_t, o.self_h, "self") === p.chain && hexText(o.prev_t, o.prev_h, "prev") === prev &&
      linkOf(prev, hexText(s.token_t, s.token_h, "token"), hexText(o.intent_t, o.intent_h, "intent")) === p.chain &&
      sha256hex(hexText(s.token_t, s.token_h, "token")) === hexText(s.token_sha256_t, s.token_sha256_h, "tsha");
  }
}
