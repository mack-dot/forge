// S4: Store mode, the store path: a symbolic link; a path that does not exist yet; the file REPLACED by rename (another
// inode at the path: operator restore by `mv`, or a re-pointed link) while the minter runs. Attacker: none (operator step).
// Exit 1 = after the replacement the minter refuses an honest request on the state of the file now at the path (it
// keeps reading the old inode: a freeze until restart, and a restart is a new key, C-ATT-05). Exit 0 = it follows the path.
// Usage: s4_paths.ts <work dir> <link|missing|mv|relink>
import { copyFileSync, renameSync, symlinkSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { Raw, done, fresh, guard, mint, newSink, propose, st } from "./lib";
const [work, mode] = process.argv.slice(2);
guard((async () => {
  fresh(work);
  const real = join(work, "real.sqlite"), link = join(work, "link.sqlite");
  const r: any = { mode };
  const s0 = st("ch_S4", "1000", "1000");
  if (mode === "link") {
    symlinkSync(real, link);                           // dangling until the sink creates real.sqlite
    const m = await new Raw(["on", link]).start();
    const sink = newSink(m, real, s0); sink.init(s0);
    const t = await mint(m, s0, propose(s0, "rq_1", "100"));
    r.viaLink = t.ok ? sink.commit(t.text).status : "refused: " + t.reason;
    sink.close(); m.stop(); done(!t.ok, r);
  }
  if (mode === "missing") {
    const m = await new Raw(["on", join(work, "typo.sqlite")]).start();
    const t = await mint(m, s0, propose(s0, "rq_1", "100"));
    r.missing = t.ok ? "issued" : "refused: " + t.reason;
    m.stop(); done(t.ok, r);                           // signing without a store would be the defect here
  }
  // mv / relink: the minter reads store A; then the path names another file B (same charge, a restored copy that is
  // one commit AHEAD of what the minter's open file shows, or a fresh copy)
  const target = mode === "relink" ? link : real;
  if (mode === "relink") symlinkSync(real, link);
  const m = await new Raw(["on", target]).start();
  const sink = newSink(m, real, s0); sink.init(s0);
  const t1 = await mint(m, s0, propose(s0, "rq_1", "100")); r.first = sink.commit(t1.text).status;
  const s1 = JSON.parse(sink.stateBlob());
  sink.close();
  // the operator makes a copy, and the copy becomes the store at the path (inode changes)
  const copy = join(work, "copy.sqlite"); copyFileSync(real, copy);
  if (mode === "mv") renameSync(copy, real); else { unlinkSync(link); symlinkSync(copy, link); }
  const sink2 = newSink(m, mode === "mv" ? real : copy, s0);   // the honest sink restarts on the file at the path
  const t2 = await mint(m, s1, propose(s1, "rq_2", "100"));
  r.afterReplace = t2.ok ? "issued -> " + sink2.commit(t2.text).status : "refused: " + t2.reason;
  const s2 = JSON.parse(sink2.stateBlob());
  const t3 = await mint(m, s2, propose(s2, "rq_3", "100"));
  r.afterNextCommit = t3.ok ? "issued -> " + sink2.commit(t3.text).status : "refused: " + t3.reason;
  sink2.close(); m.stop();
  done(!t2.ok || !t3.ok, r);
})());
