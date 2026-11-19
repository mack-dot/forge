// S5: Store mode; a writer crashed during a write and left a HOT -journal (the sink then refuses to start and the
// operator runs Sink.recover, which previews and logs the rollback). Question: does the minter's read-only read roll
// the journal back by itself (the operator step is bypassed: no preview, no log), or refuse? Attacker: none (crash).
// Exit 1 = the minter's read removed the -journal (the rollback happened outside Sink.recover), or after Sink.recover the
// same honest request is not issued and committed. Exit 0 = refused during the hot journal, served after recovery.
// Usage: s5_hotjournal.ts <work dir>
import { spawnSync } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import { join } from "node:path";
import { Raw, done, fresh, guard, mint, newSink, propose, st } from "./lib";
const [work] = process.argv.slice(2);
guard((async () => {
  fresh(work);
  const path = join(work, "s.sqlite");
  const m = await new Raw(["on", path]).start();
  const s0 = st("ch_S5", "1000", "1000");
  const sink = newSink(m, path, s0); sink.init(s0);
  const t1 = await mint(m, s0, propose(s0, "rq_1", "100")); const r: any = { first: sink.commit(t1.text).status };
  const s1 = JSON.parse(sink.stateBlob());
  sink.close();
  const c = spawnSync(process.execPath, ["--import", "tsx", join(__dirname, "crasher.ts"), path], { stdio: "inherit" });
  r.crasherSignal = c.signal; r.journalBefore = existsSync(path + "-journal") ? statSync(path + "-journal").size : null;
  try { newSink(m, path, s0); r.sinkStart = "started"; } catch (e) { r.sinkStart = String((e as Error).message).slice(0, 160); }
  const t2 = await mint(m, s1, propose(s1, "rq_2", "100"));
  r.minterDuringHotJournal = t2.ok ? "issued" : "refused: " + t2.reason;
  r.journalAfter = existsSync(path + "-journal") ? statSync(path + "-journal").size : null;
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256, initialState: s0 };
  try { r.recover = (require(join(process.env.C7_ROOT as string, "ts/refund-finality/sink.ts")).Sink).recover(path, ids, join(work, "recover.log")).reason; } catch (e) { r.recover = String((e as Error).message).slice(0, 200); }
  const t3 = await mint(m, s1, propose(s1, "rq_2", "100"));
  r.minterAfterRecover = t3.ok ? "issued" : "refused: " + t3.reason;
  try { const s = newSink(m, path, s0); r.sinkStartAfter = "started"; if (t3.ok) r.commitAfter = s.commit(t3.text).status; s.close(); }
  catch (e) { r.sinkStartAfter = String((e as Error).message).slice(0, 160); }
  m.stop();
  done((r.journalBefore !== null && r.journalAfter === null) || r.commitAfter !== "committed", r);
})());
