// Regression C-HOST-01, 03, 04, 07: the command-line doors tell the truth by exit code and report. Uses the tree's
// tests/refund-finality/{commit,dispatch}_cli.ts. Each case is SAFE as stated; the file FAILS if any case fails.
//  a (H-04) commit_cli: a malformed token exits non-zero; a mistyped database path exits non-zero and creates no file.
//  b (H-01) dispatch_cli: the effect cannot be written (emit fails): exit non-zero; the retry also exits non-zero
//           (the refund is in doubt, not "nothing to do").
//  c (H-01) dispatch_cli: a lock held by a live process: exit non-zero.
//  d (H-01) dispatch_cli: every row refused (wrong pinned initial state): exit non-zero.
//  e (H-03) dispatch_cli: the lock is removed while the run is in a slow effect: the report counts every effect it sent.
//  f (H-07) dispatch_cli: stdout is closed before the report (EPIPE): the exit code is 0 for a clean run whose effect left.
// Usage and exit codes: d_lib.ts.
import { spawn } from "node:child_process";
import { randomBytes } from "node:crypto";
import { existsSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { hostname } from "node:os";
import { join } from "node:path";
import { argv, guard, runNode, verdict, world } from "./d_lib";
guard((async () => {
  const { root, core } = argv();
  const CLI = (n: string) => join(root, "tests/refund-finality", n);
  const S0 = { chargeId: "ch_dcli", original: "1000", remaining: "1000", refundEnabled: true };
  const out: Record<string, unknown> = {}; const ok: Record<string, boolean> = {};
  const fresh = async (amounts: string[]) => {
    const w = await world(root, core, S0);
    let pre: any = S0; const toks: string[] = [];
    for (let i = 0; i < amounts.length; i++) { const t = await w.mint(pre, "rq_" + i, amounts[i]); toks.push(t.text); pre = t.post; }
    const scfg = join(w.dir, "sink-config.json"), dcfg = join(w.dir, "disp-config.json"), eff = join(w.dir, "effects.jsonl");
    writeFileSync(scfg, JSON.stringify(w.sinkCfg)); writeFileSync(dcfg, JSON.stringify(w.dcfg)); writeFileSync(eff, "");
    toks.forEach((t, i) => writeFileSync(join(w.dir, `t${i}.token`), t));
    w.closeSink();
    return { w, scfg, dcfg, eff };
  };
  const D = (x: { w: any; dcfg: string; eff: string }, eff = x.eff, dcfg = x.dcfg) => runNode(root, [CLI("dispatch_cli.ts"), x.w.db, x.w.ledger, dcfg, eff, "0"]);
  { // a
    const x = await fresh(["400"]); writeFileSync(join(x.w.dir, "bad.token"), "{}");
    const r1 = await runNode(root, [CLI("commit_cli.ts"), x.w.db, x.scfg, join(x.w.dir, "bad.token"), "0"]);
    const typo = join(x.w.dir, "typo.sqlite");
    const r2 = await runNode(root, [CLI("commit_cli.ts"), typo, x.scfg, join(x.w.dir, "t0.token"), "0"]);
    ok.a = r1.code !== 0 && r2.code !== 0 && !existsSync(typo); out.a = { bad: r1.code, typo: r2.code, created: existsSync(typo) }; x.w.stop();
  }
  { // b
    const x = await fresh(["400"]); await runNode(root, [CLI("commit_cli.ts"), x.w.db, x.scfg, join(x.w.dir, "t0.token"), "0"]);
    const r1 = await D(x, join(x.w.dir, "no-such-dir", "effects.jsonl")), r2 = await D(x);
    ok.b = r1.code !== 0 && r2.code !== 0 && readFileSync(x.eff, "utf8") === ""; out.b = { run1: r1.code, retry: r2.code, retryOut: r2.stdout.slice(0, 120) }; x.w.stop();
  }
  { // c
    const x = await fresh(["400"]); await runNode(root, [CLI("commit_cli.ts"), x.w.db, x.scfg, join(x.w.dir, "t0.token"), "0"]);
    writeFileSync(x.w.ledger, ""); writeFileSync(realpathSync(x.w.ledger) + ".lock", JSON.stringify({ pid: process.pid, run: randomBytes(16).toString("hex"), host: hostname() }));
    const r = await D(x); ok.c = r.code !== 0 && readFileSync(x.eff, "utf8") === ""; out.c = { code: r.code }; x.w.stop();
  }
  { // d
    const x = await fresh(["400"]); await runNode(root, [CLI("commit_cli.ts"), x.w.db, x.scfg, join(x.w.dir, "t0.token"), "0"]);
    const bad = join(x.w.dir, "disp-bad.json"); writeFileSync(bad, JSON.stringify({ ...x.w.dcfg, initialStateSha256: "0".repeat(64) }));
    const r = await D(x, x.eff, bad); ok.d = r.code !== 0; out.d = { code: r.code, out: r.stdout.slice(0, 120) }; x.w.stop();
  }
  { // e
    const x = await fresh(["400", "600"]);
    for (const i of [0, 1]) await runNode(root, [CLI("commit_cli.ts"), x.w.db, x.scfg, join(x.w.dir, `t${i}.token`), "0"]);
    const run = D(x);
    const t0 = Date.now(); while (readFileSync(x.eff, "utf8") === "" && Date.now() - t0 < 30000) await new Promise(r => setTimeout(r, 5));
    rmSync(realpathSync(x.w.ledger) + ".lock", { force: true });
    const r = await run; const sent = readFileSync(x.eff, "utf8").split("\n").filter(Boolean).length;
    let reported = -1; try { reported = JSON.parse(r.stdout).emitted; } catch { /* no report */ }
    ok.e = sent > 0 && reported === sent; out.e = { code: r.code, sent, reported }; x.w.stop();
  }
  { // f
    const x = await fresh(["400"]); await runNode(root, [CLI("commit_cli.ts"), x.w.db, x.scfg, join(x.w.dir, "t0.token"), "0"]);
    const code = await new Promise<number | null>(res => {
      const p = spawn(process.execPath, ["--no-warnings", "--import", "tsx", CLI("dispatch_cli.ts"), x.w.db, x.w.ledger, x.dcfg, x.eff, "0"],
        { cwd: root, env: { PATH: process.env.PATH ?? "/usr/bin:/bin" }, stdio: ["ignore", "pipe", "ignore"] });
      p.stdout.destroy();
      p.on("exit", c => res(c));
    });
    const sent = readFileSync(x.eff, "utf8").split("\n").filter(Boolean).length;
    ok.f = sent === 1 && code === 0; out.f = { code, sent }; x.w.stop();
  }
  verdict(Object.values(ok).every(Boolean) && Object.keys(ok).length === 6, { ok, out });
})());
