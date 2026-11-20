// Regression C-ATT-35 (h-sink3): the per-write file check (inode, links, companions) ran before BEGIN only. A party with
// rename rights in the database directory (DIR-EXCLUSIVE broken) replaced the file INSIDE a commit (between the check and
// COMMIT; made deterministic with cfg.onHead): the commit was acknowledged into an unlinked inode.
// Cases (PASS conditions):
//   swap-onhead  the copy (zero row z deleted, chain recomputed) is renamed over the path inside onHead: the commit of r3 is
//                NOT acknowledged ("sink halted", "inside the write transaction"). (The deletion of z itself is the file
//                writer's class-c edit: seen only with an outside head; not the subject here.)
//   swap-after   the same rename right AFTER the SQLite COMMIT returned (a wrapper of the connection's exec): the commit is
//                NOT acknowledged ("after COMMIT"); the sink halts.
//   controls     with the checks in place: commits (a zero-amount refund included), a replay, and a single-writer sink
//                (cfg.outsideHead + onHead) whose own -journal exists inside its transaction: all succeed.
// Remaining window (stated, not tested): a rename after the post-COMMIT check and before the host persists the head.
// FAILS on the unfixed tree (swap-onhead and swap-after are acknowledged).
// Usage: node --import tsx tests/refund-finality/regress/s3_att35_inode_commit.ts <treeRoot> [<compiledIssuerModule>]
import { copyFileSync, renameSync } from "node:fs";
import { join } from "node:path";
import { argv, guard, hostile, ids, kit, st, tempDir, verdict } from "./s_lib";

const full = (e: unknown): string => String((e as Error)?.message ?? e);
guard((() => {
  const { root } = argv();
  const K = kit(root);
  const out: any = {};
  let pass = true;
  const rec = (name: string, ok: boolean, d: any) => { out[name] = { ...d, ok }; if (!ok) pass = false; };
  const open = (db: string, extra: any = {}): any => { try { return new K.SK.Sink(db, { ...K.cfg, ...extra }); } catch (e) { return "REFUSED: " + full(e); } };
  const R1 = K.tok(K.S0, "r1", "600"), Z = K.tok(st("400"), "z", "0"), R2 = K.tok(st("400"), "r2", "100"), R3 = K.tok(st("300"), "r3", "50");
  const delZ = (d: any) => {
    const s = (d.prepare("SELECT seq FROM settled WHERE request_id = 'z'").get() as any).seq;
    d.prepare("DELETE FROM settled WHERE seq = ?").run(s); d.prepare("DELETE FROM outbox WHERE seq = ?").run(s);
    d.prepare("UPDATE settled SET seq = seq - 1 WHERE seq > ?").run(s); d.prepare("UPDATE outbox SET seq = seq - 1 WHERE seq > ?").run(s);
  };
  const setup = (when: "onhead" | "after") => {
    const dir = tempDir(), db = join(dir, "sink.sqlite");
    let armed = false;
    const swap = () => { const cp = join(dir, "copy.sqlite"); copyFileSync(db, cp); const e = hostile(cp, delZ, { linkOf: K.SK.linkOf, sha: K.E.sha256hex }); renameSync(cp, db); return e; };
    let edit = "";
    const s = open(db, when === "onhead" ? { onHead: () => { if (armed) { armed = false; edit = swap(); } } } : {});
    if (typeof s === "string") throw new Error(s);
    s.init(K.S0);
    const acked: string[] = [];
    for (const [t, id] of [[R1, "r1"], [Z, "z"], [R2, "r2"]]) if (s.commit(t).status === "committed") acked.push(id);
    if (when === "after") {
      const conn = (s as any).db, orig = conn.exec.bind(conn);
      conn.exec = (sql: string) => { const r = orig(sql); if (sql === "COMMIT" && armed) { armed = false; edit = swap(); } return r; };
    }
    armed = true;
    const r3 = s.commit(R3);
    if (r3.status === "committed") acked.push("r3");
    s.close();
    const atPath = ids(db);
    // lostAck: the commit under attack acknowledged but missing at the path (z is the attacker's own deletion: class c, seen
    // only with an outside head; not this regression's subject).
    return { r3, edit, acked, atPath, lostAck: acked.includes("r3") && !atPath.includes("r3") };
  };
  { const x = setup("onhead"); rec("swap-onhead", x.edit === "ok" && x.r3.status === "rejected" && /sink halted/.test(x.r3.reason ?? "") && /inside the write transaction/.test(x.r3.reason ?? "") && !x.lostAck, x); }
  { const x = setup("after"); rec("swap-after", x.edit === "ok" && x.r3.status === "rejected" && /sink halted/.test(x.r3.reason ?? "") && /after COMMIT/.test(x.r3.reason ?? "") && !x.lostAck, x); }
  { // controls
    const dir = tempDir(), db = join(dir, "sink.sqlite");
    const anchor: any = { committed: { count: 0, chainHash: K.genesis } };
    const s = open(db, { outsideHead: { committed: anchor.committed }, onHead: (h: any) => { anchor.pending = h; } });
    if (typeof s === "string") throw new Error(s);
    s.init(K.S0);
    const st1 = [R1, Z, R2].map(t => { const r = s.commit(t); if (r.status === "committed") anchor.committed = r.head; return r.status; });
    const replay = s.commit(Z).status;
    const zero2 = s.commit(K.tok(st("300"), "z2", "0")).status, z3 = s.commit(K.tok(st("300"), "z3", "0")).status, big = s.commit(K.tok(st("300"), "rmax", "300")).status;
    s.close();
    rec("controls", st1.every(v => v === "committed") && replay === "replayed" && zero2 === "committed" && z3 === "committed" && big === "committed", { st1, replay, zero2, z3, big });
  }
  verdict(pass, out);
})());
