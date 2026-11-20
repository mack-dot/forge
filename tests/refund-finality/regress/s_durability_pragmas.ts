// Durability (h-sink2 item 7): the sink's own connection must run with journal_mode = DELETE, synchronous = FULL and
// fullfsync = ON (macOS: F_FULLFSYNC), set explicitly and read back (Sink.pragmas()). Also checked: the values hold after
// commits and on a restarted sink; commits (zero amount included) and a replay still work.
// This is NOT a power-loss test: no power cut is made; the durability claim stays TESTED-UNPROVED at best (see notes).
// Usage: node --import tsx tests/refund-finality/regress/s_durability_pragmas.ts <treeRoot> [<compiledIssuerModule>]
import { join } from "node:path";
import { argv, guard, kit, tempDir, verdict } from "./s_lib";

guard((() => {
  const { root } = argv();
  const K = kit(root);
  const db = join(tempDir(), "sink.sqlite");
  const s = K.open(db); if (typeof s === "string") throw new Error(s);
  const want = JSON.stringify({ journal_mode: "delete", synchronous: 2, fullfsync: 1 });
  const p0 = typeof s.pragmas === "function" ? JSON.stringify(s.pragmas()) : "no pragmas()";
  s.init(K.S0);
  const Z = K.tok(K.S0, "z", "0");
  const c = [Z, K.tok(K.S0, "z2", "0"), K.tok(K.S0, "r1", "1000")].map(t => s.commit(t).status);
  const replay = s.commit(Z).status;
  const p1 = typeof s.pragmas === "function" ? JSON.stringify(s.pragmas()) : "no pragmas()";
  s.close();
  const s2 = K.open(db); const p2 = typeof s2 !== "string" && typeof s2.pragmas === "function" ? JSON.stringify(s2.pragmas()) : "no pragmas()"; if (typeof s2 !== "string") s2.close();
  verdict(p0 === want && p1 === want && p2 === want && c.every(x => x === "committed") && replay === "replayed", { atOpen: p0, afterCommits: p1, restarted: p2, commits: c, replay });
})());
