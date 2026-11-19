// Attacks 2 and 5: path tricks at the dispatcher. Attacker: write access to the LEDGER directory only (no key, no db write).
// lockdangle - <ledger>.lock pre-created as a DANGLING symlink to <elsewhere>/x : does 'wx' follow it?
// lockdir    - <ledger>.lock pre-created as a directory
// ledgerdangle - the ledger path is a dangling symlink into another directory: where do the lines go?
// otherledger  - the ledger path is a symlink to ANOTHER charge's ledger
// renamemid    - during the run (in emit of the first effect) a new file is renamed over the ledger path
// exit 1 = a duplicate effect for a request id or a total above the original, or a file created outside the ledger
//          directory through the lock path; 0 = safe (fail closed counts as safe; DoS is reported in the output).
import { existsSync, lstatSync, mkdirSync, readFileSync, renameSync, symlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fixture, fresh, EV, tryOpen, Dispatcher } from "./common15";
const mode = process.argv[2] ?? "lockdangle";
(async () => {
  const fx = await fixture(undefined, "fixture-b"); const W = join(EV, "work", "s5-" + mode); fresh(W);
  mkdirSync(join(W, "led")); mkdirSync(join(W, "elsewhere"));
  const db = join(W, "sink.sqlite"), ledger = join(W, "led", "ledger.jsonl"), out: any = { mode };
  const s = tryOpen(db, fx).sink; s.init(fx.cfg.initialState); for (let i = 0; i < 4; i++) s.commit(fx.tokens[i].text); s.close();
  const effects: string[] = []; let hook: null | (() => void) = null;
  const D = () => new Dispatcher(db, ledger, fx.dcfg, (e: any) => { effects.push(e.requestId); if (hook) { const h = hook; hook = null; h(); } });
  const run = (k: string) => { try { const r = D().flush(); out[k] = { emitted: r.emitted.map((e: any) => e.requestId), refused: r.refused.length, already: r.alreadyDispatched }; } catch (e) { out[k] = "throws: " + (e as Error).message; } };
  if (mode === "lockdangle") { writeFileSync(ledger, ""); symlinkSync(join(W, "elsewhere", "x"), ledger + ".lock"); run("flush1"); out.createdElsewhere = existsSync(join(W, "elsewhere", "x")); }
  if (mode === "lockdir") { writeFileSync(ledger, ""); mkdirSync(ledger + ".lock"); run("flush1"); }
  if (mode === "ledgerdangle") { symlinkSync(join(W, "elsewhere", "ledger.jsonl"), ledger); run("flush1"); out.linesElsewhere = existsSync(join(W, "elsewhere", "ledger.jsonl")) ? readFileSync(join(W, "elsewhere", "ledger.jsonl"), "utf8").split("\n").filter(Boolean).length : 0; out.lockElsewhereLeft = existsSync(join(W, "elsewhere", "ledger.jsonl.lock")); }
  if (mode === "otherledger") { mkdirSync(join(W, "other")); writeFileSync(join(W, "other", "ledger.jsonl"), JSON.stringify({ requestId: "x1", tokenSha256: "0".repeat(64), preStateSha256: "1".repeat(64), postStateSha256: "2".repeat(64), intentSha256: "3".repeat(64) }) + "\n"); symlinkSync(join(W, "other", "ledger.jsonl"), ledger); run("flush1"); }
  if (mode === "renamemid") { hook = () => { writeFileSync(join(W, "led", "new.tmp"), ""); renameSync(join(W, "led", "new.tmp"), ledger); }; run("flush1"); out.ledgerAfter = readFileSync(ledger, "utf8").split("\n").filter(Boolean).map(l => JSON.parse(l).requestId); run("flush2"); }
  run("final");
  out.effects = effects;
  const dup = effects.length !== new Set(effects).size; const amt = (r: string) => Number(fx.tokens.find(t => t.rid === r)?.amount ?? 0);
  out.paid = effects.reduce((a, r) => a + amt(r), 0);
  const bad = dup || out.paid > 1000 || out.createdElsewhere === true;
  console.log(JSON.stringify(out)); console.log(bad ? "DEFECT" : "SAFE"); process.exit(bad ? 1 : 0);
})();
