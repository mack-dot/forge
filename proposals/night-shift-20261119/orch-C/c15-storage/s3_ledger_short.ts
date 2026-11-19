// Attack 3a: a SHORT write of a dispatcher ledger line (RLIMIT_FSIZE; SIGXFSZ ignored, so write(2) returns fewer bytes).
// Attacker: none (a fault: disk full / quota / file-size limit). dispatcher.ts:99 calls writeSync once and does not
// check the count. exit 1 = an effect was emitted whose ledger line is not complete (header claim broken), 0 = safe.
// arg: RLIMIT_FSIZE of the child in BYTES (set by fsize.py). Note: on macOS a fresh O_APPEND descriptor is checked
// against its offset 0, so each append can write up to the limit; a 350-byte line is torn when the limit is below 350.
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fixture, fresh, EV, tryOpen, Dispatcher } from "./common15";
(async () => {
  process.env.C15_FIXTURE = "fixture-b"; const fx = await fixture(undefined, "fixture-b");
  const N = process.argv[2] ?? "1"; const W = join(EV, "work", "s3-ledger-" + N); fresh(W);
  const db = join(W, "sink.sqlite"), ledger = join(W, "ledger.jsonl"), out: any = { limitBytes: Number(N) };
  const s = tryOpen(db, fx).sink; s.init(fx.cfg.initialState); for (let i = 0; i < 6; i++) s.commit(fx.tokens[i].text); s.close();
  const child = execFileSync("/usr/bin/python3", ["-I", join(EV, "fsize.py"), N, process.execPath, "--import", "tsx", join(EV, "child_op.ts"), db, "flush", ledger], { env: { ...process.env, C15_FIXTURE: "fixture-b" } }).toString();
  out.child = child.split("\n").filter(l => /^(EFFECT|FLUSH)/.test(l));
  const txt = readFileSync(ledger, "utf8"); out.ledgerBytes = txt.length;
  const lines = txt.split("\n"); out.lineLengths = lines.map(l => l.length);
  const parse = (l: string) => { try { return JSON.parse(l).requestId; } catch { return "TORN"; } };
  out.ledgerIds = lines.filter(l => l.length).map(parse);
  const emitted = out.child.filter((l: string) => l.startsWith("EFFECT")).map((l: string) => l.slice(7));
  const tornEmitted = emitted.filter((r: string) => !out.ledgerIds.includes(r));
  out.emittedWithoutCompleteLine = tornEmitted;
  const effects: string[] = [];
  try { new Dispatcher(db, ledger, fx.dcfg, (e: any) => effects.push(e.requestId)).flush(); out.nextFlush = effects; }
  catch (e) { out.nextFlush = "throws: " + (e as Error).message; }
  // what a person gets by the obvious repair (drop the torn line): which effects are sent again?
  const { writeFileSync } = require("node:fs"); writeFileSync(ledger, lines.filter(l => l.length && parse(l) !== "TORN").map(l => l + "\n").join(""));
  const again: string[] = []; try { new Dispatcher(db, ledger, fx.dcfg, (e: any) => again.push(e.requestId)).flush(); } catch (e) { again.push("throws " + (e as Error).message); }
  out.afterDroppingTornLine = again; out.sentTwice = again.filter(r => emitted.includes(r));
  const amt = (r: string) => Number(fx.tokens.find(t => t.rid === r)?.amount ?? 0);
  out.paidTotal = [...emitted, ...again.filter(r => !r.startsWith("throws"))].reduce((a, r) => a + amt(r), 0);
  console.log(JSON.stringify(out));
  console.log(tornEmitted.length ? "DEFECT: effect emitted with a torn ledger line" : "SAFE"); process.exit(tornEmitted.length ? 1 : 0);
})();
