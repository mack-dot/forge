// a10_honest.ts <root> <issuer.cjs>: honest flows must work with no operator step (false-rejection check).
// zero-amount z0, full refund f (1000 of 1000), zero-amount z1 after it; flush in process; second flush emits 0;
// sink restart + dispatch_cli run (exit 0, emitted 0); then one more zero refund through a dispatch_cli run (exit 0, 1 sent).
// Exit 1 = a legitimate effect refused, sent twice, or an honest run that does not end with exit 0.
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { argv, dups, guard, runNode, verdict, world } from "<SCRATCH>/redteam-C/fix-f08a21c1/tests/refund-finality/regress/d_lib";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_a10", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const z0 = await w.mint(S0, "z0", "0"), f = await w.mint(z0.post, "f", "1000"), z1 = await w.mint(f.post, "z1", "0");
  const c = [w.commit(z0.text), w.commit(f.text), w.commit(z1.text)];
  const r1 = w.flush(), r2 = w.flush();
  w.reopen(); w.closeSink();
  const eff = join(w.dir, "eff.jsonl"), dcfg = join(w.dir, "dcfg.json"); writeFileSync(eff, ""); writeFileSync(dcfg, JSON.stringify(w.dcfg));
  const cli = join(root, "tests/refund-finality/dispatch_cli.ts");
  const k1 = await runNode(root, [cli, w.db, w.ledger, dcfg, eff, "0"]);
  w.reopen(); const z2 = await w.mint(z1.post, "z2", "0"); c.push(w.commit(z2.text)); w.closeSink();
  const k2 = await runNode(root, [cli, w.db, w.ledger, dcfg, eff, "0"]);
  w.stop();
  const ids = [...w.effects.map(e => e.requestId), ...readFileSync(eff, "utf8").split("\n").filter(Boolean).map(l => JSON.parse(l).requestId)];
  const pass = c.every(s => s === "committed") && r1.emitted.length === 3 && r1.refused.length === 0 && r2.emitted.length === 0 && r2.refused.length === 0 &&
    k1.code === 0 && k2.code === 0 && dups(ids).length === 0 && ids.length === 4;
  verdict(pass, { commits: c, r1: r1.emitted.map((e: any) => e.requestId), r2: r2.emitted.length, cli1: [k1.code, k1.stdout.slice(0, 100)], cli2: [k2.code, k2.stdout.slice(0, 100)], ids });
})());
