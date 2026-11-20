// C-ATT-23: two hard-link names of one database lose acknowledged commits after one crash (SQLite names the journal after
// the path; a second name does not see the first name's hot journal). Required: refuse to open a database file whose
// st_nlink > 1. Cases: the sink by the first name, the sink by the second name, the dispatcher: all REFUSED (dispatcher:
// alarm, nothing sent). Control: a SYMBOLIC link name serves (SQLite resolves it; the companions are found at the real
// path), and the hard link removed -> the first name serves again with all rows; a zero-amount commit succeeds.
// NOT covered (stated): bind mounts, copies, another host's mount of the same file.
// Usage: node --import tsx tests/refund-finality/regress/s_att23_hardlink.ts <treeRoot> [<compiledIssuerModule>]
import { linkSync, symlinkSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { argv, guard, kit, st, tempDir, verdict } from "./s_lib";

guard((() => {
  const { root } = argv();
  const K = kit(root);
  const dir = tempDir(), a = join(dir, "a.sqlite"), b = join(dir, "b.sqlite"), sl = join(dir, "s.sqlite"), ledger = join(dir, "ledger.jsonl");
  const s = K.open(a); if (typeof s === "string") throw new Error(s);
  s.init(K.S0);
  const c = [K.tok(K.S0, "r1", "100"), K.tok(st("900"), "z", "0")].map(t => s.commit(t).status);
  s.close();
  linkSync(a, b);
  const byA = K.open(a), byB = K.open(b);
  const f = K.flush(b, ledger);
  for (const x of [byA, byB]) if (typeof x !== "string") x.close();
  unlinkSync(b);
  symlinkSync(a, sl);
  const bySym = K.open(sl); let symCommit = "-";
  if (typeof bySym !== "string") { symCommit = bySym.commit(K.tok(st("900"), "z2", "0")).status; bySym.close(); }
  const again = K.open(a); let count = -1;
  if (typeof again !== "string") { count = again.head().count; again.close(); }
  const pass = c.every(x => x === "committed") && typeof byA === "string" && typeof byB === "string" && f.alarm !== undefined && f.emitted.length === 0 &&
    symCommit === "committed" && count === 3;
  verdict(pass, { commits: c, byA: typeof byA === "string" ? byA : "STARTED", byB: typeof byB === "string" ? byB : "STARTED", dispatcher: f, symlinkCommit: symCommit, afterUnlinkCount: count });
})());
