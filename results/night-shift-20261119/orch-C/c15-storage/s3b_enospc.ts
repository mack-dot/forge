// Attack 3b: REAL disk full (ENOSPC) on the ledger's volume: a 2 MB HFS+ image with 512-byte allocation blocks,
// attached by `hdiutil attach` (no sudo). Attacker: none (a fault: the volume fills up). write(2) returns a short count
// (no error); dispatcher.ts:99 does not check it, fsyncs, and emits the effect.
// arg: mount point of the image.  exit 1 = an effect was emitted whose ledger line is not complete; 0 = safe.
import { closeSync, existsSync, openSync, readdirSync, readFileSync, rmSync, writeSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fixture, fresh, EV, tryOpen, Dispatcher } from "./common15";
(async () => {
  const fx = await fixture(undefined, "fixture-b"); const MNT = process.argv[2];
  for (const f of readdirSync(MNT)) if (!f.startsWith(".")) rmSync(join(MNT, f), { recursive: true, force: true });
  const W = join(EV, "work", "s3b-enospc"); fresh(W);
  const db = join(W, "sink.sqlite"), ledger = join(MNT, "ledger.jsonl"), out: any = {};
  const mode = process.argv[3] ?? "during";   // before: the volume is full before the run; during: it fills after the first effect
  const fill = () => { const fd = openSync(join(MNT, "fill"), "w"); const blk = Buffer.alloc(512); let n = 0;
    try { for (;;) { if (writeSync(fd, blk) < 512) break; n++; } } catch (e) { out.fillStop = (e as any).code; } closeSync(fd); out.fillBlocks = n; };
  let armed = false;
  const effects: string[] = []; const D = () => new Dispatcher(db, ledger, fx.dcfg, (e: any) => { effects.push(e.requestId); if (armed) { armed = false; fill(); } });
  const s = tryOpen(db, fx).sink; s.init(fx.cfg.initialState); out.c1 = s.commit(fx.tokens[0].text).status;
  out.flush1 = D().flush().emitted.map((e: any) => e.requestId); effects.length = 0;
  for (let i = 1; i < 6; i++) s.commit(fx.tokens[i].text); s.close();
  // the volume fills up (any other writer on that volume): before the run, or right after the run's first effect
  if (mode === "before") fill(); else armed = true; out.mode = mode;
  try { const r = D().flush(); out.flush2 = r.emitted.map((e: any) => e.requestId); } catch (e) { out.flush2 = "throws: " + (e as Error).message; }
  out.effects = [...effects];
  const lines = readFileSync(ledger, "utf8").split("\n"); out.lineLengths = lines.map(l => l.length);
  const parse = (l: string) => { try { return JSON.parse(l).requestId; } catch { return "TORN"; } };
  out.ledgerIds = lines.filter(l => l.length).map(parse);
  out.lockLeft = existsSync(ledger + ".lock");
  out.emittedWithoutCompleteLine = effects.filter(r => !out.ledgerIds.includes(r));
  rmSync(join(MNT, "fill"));                                   // space comes back
  try { const r = D().flush(); out.flush3 = r.emitted.map((e: any) => e.requestId); } catch (e) { out.flush3 = "throws: " + (e as Error).message; }
  console.log(JSON.stringify(out));
  const bad = out.emittedWithoutCompleteLine.length > 0;
  console.log(bad ? "DEFECT: effect emitted after a short ledger write (ENOSPC)" : "SAFE"); process.exit(bad ? 1 : 0);
})();
