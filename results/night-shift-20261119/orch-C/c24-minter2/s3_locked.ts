// S3: Store mode; a writer holds the store's lock (SQLITE_BUSY) while an honest request arrives. Attacker: none
// (a long sink transaction) or a database reader/writer. Exit 1 = after the lock is released, the SAME honest request
// is still refused (a transient error closed the pair for ever). Exit 0 = refused during the lock (not recorded) and
// issued afterwards. Usage: s3_locked.ts <work dir>
import { spawn } from "node:child_process";
import { join } from "node:path";
import { Raw, done, fresh, guard, mint, newSink, propose, st } from "./lib";
const [work] = process.argv.slice(2);
guard((async () => {
  fresh(work);
  const path = join(work, "s.sqlite");
  const m = await new Raw(["on", path]).start();
  const s0 = st("ch_S3", "1000", "1000");
  const sink = newSink(m, path, s0); sink.init(s0);
  const r: any = {};
  const warm = await mint(m, s0, propose(s0, "rq_warm", "0")); r.warm = warm.ok;   // opens the minter's connection
  const lk = spawn(process.execPath, ["--import", "tsx", join(__dirname, "locker.ts"), path, "7000"], { stdio: ["ignore", "pipe", "inherit"] });
  await new Promise<void>(res => lk.stdout!.on("data", d => { if (String(d).includes("locked")) res(); }));
  const t0 = Date.now();
  const during = await mint(m, s0, propose(s0, "rq_v", "250"));
  r.duringLock = { ok: during.ok, reason: during.reason, ms: Date.now() - t0 };
  await new Promise<void>(res => lk.on("exit", () => res()));
  const after = await mint(m, s0, propose(s0, "rq_v", "250"));
  r.afterRelease = after.ok ? "issued -> " + sink.commit(after.text).status : "refused: " + after.reason;
  sink.close(); m.stop();
  done(!after.ok, r);
})());
