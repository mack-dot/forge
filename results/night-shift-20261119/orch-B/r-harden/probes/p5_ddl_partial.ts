// r-harden probe P5: an interrupted schema creation must not brick a NEW store (C-ATT-02 claim). Standalone; short.
// usage (cwd = tree): node --import tsx p5_ddl_partial.ts <treeRoot> <scratch dir>
// Case 1: half of DDL_STATEMENTS in an open transaction, connection closed without COMMIT (the rollback a crash causes).
// Case 2: the same with a hot rollback journal left on disk (the journal file is copied before the close).
// Then the sink must start and init must work. Exit 1 if the store cannot be used; exit 0 otherwise.
import { generateKeyPairSync } from "node:crypto";
import { copyFileSync, existsSync, mkdirSync, rmSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { join, resolve } from "node:path";
const [T0, O0] = process.argv.slice(2); const TREE = resolve(T0), OUT = resolve(O0);
rmSync(OUT, { recursive: true, force: true }); mkdirSync(OUT, { recursive: true });
/* eslint-disable @typescript-eslint/no-require-imports */
const HM = require(join(TREE, "ts/refund-finality/sink.ts")); const ST = require(join(TREE, "ts/refund-finality/core/store.ts"));
/* eslint-enable @typescript-eslint/no-require-imports */
const pem = generateKeyPairSync("ed25519").publicKey.export({ type: "spki", format: "pem" }) as string;
const S0 = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
const cfg = { publicKeyPem: pem, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: S0 };
let bad = 0;
for (const hot of [false, true]) {
  const p = join(OUT, `c${hot ? 2 : 1}.sqlite`);
  const db = new DatabaseSync(p); db.exec("PRAGMA cache_size = 1"); db.exec("BEGIN IMMEDIATE");
  ST.DDL_STATEMENTS.slice(0, 9).forEach((s: string) => db.exec(s));
  if (hot && existsSync(p + "-journal")) { copyFileSync(p, p + ".mid"); copyFileSync(p + "-journal", p + ".mid-journal"); }
  db.close();
  const q = hot && existsSync(p + ".mid") ? p + ".mid" : p;
  let r = "";
  try { const s = new HM.Sink(q, cfg); s.init(S0); r = "STARTED+INIT head=" + s.head().count; s.close(); } catch (e) { r = "REFUSED: " + String((e as Error).message).slice(0, 160); bad++; }
  console.log(JSON.stringify({ case: hot ? "hot journal copy" : "rollback on close", file: q.endsWith(".mid") ? "mid-transaction copy" : "file", result: r }));
}
rmSync(OUT, { recursive: true, force: true });
console.log(bad ? "BRICKED" : "SAFE"); process.exit(bad ? 1 : 0);
