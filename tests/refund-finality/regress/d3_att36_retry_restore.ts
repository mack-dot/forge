// Regression C-ATT-36 (h-sink3): after resolveInDoubt(r1, "retry"), a backup of the LEDGER taken BEFORE the re-claim and
// restored ALONE later made the slot "retry" again: r1 was sent twice (1200 on 1000). The witness and cfg.ledgerFloor kept
// only {n, rowHead}; a re-claim changes neither. Now the ledger is a hash chain of its lines and the witness and the floor
// keep {lines, lastHash} (dispatcher.ts, LEDGER CHAIN).
// Cases (PASS conditions; no request id twice and total <= 1000 in each):
//   attack   run1's emit throws (nothing sent); resolveInDoubt(r1, "retry"); backup of the ledger; run2 re-claims and sends
//            r1; the ledger alone is restored; run3 stops (alarm) and sends nothing.
//   floor    the same, but the ledger AND the witness are restored together; run3 carries cfg.ledgerFloor = run2's
//            ledgerHead ({n, rowHead, lines, lastHash}): run3 stops and sends nothing.
//   resolve  the backup is taken BEFORE the "retry" decision (run1's claim and failed line only); restored alone after
//            run2: run3 stops (the witness follows the decision line too).
//   control  no restore: run3 sends nothing and does not stop; then r2 (a zero-amount refund) commits and is sent once.
//   migrate  a ledger and a witness of the h-dispatch format (no `prev` in the lines; witness {ledger, n, rowHead}): the
//            next run accepts them, sends r2 once, and upgrades the witness ({lines, lastHash}); then a lost-race
//            duplicate of r2's claim WITH the right `prev` is accepted (nothing sent), and the same line WITHOUT `prev`
//            after chained lines is refused ("not one chain").
// INFORMATION (not in the verdict; stated limit LEDGER-MONOTONE): ledger and witness restored together WITHOUT a floor.
// FAILS on the unfixed dispatcher (attack and floor send r1 twice).
// Usage and exit codes: d_lib.ts.
import { createHash } from "node:crypto";
import { appendFileSync, copyFileSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { argv, dups, guard, total, verdict, world } from "./d_lib";

const S0 = { chargeId: "ch_d36", original: "1000", remaining: "1000", refundEnabled: true };
const full = (e: unknown): string => String((e as Error)?.message ?? e);
async function retryCase(root: string, core: string, kase: "attack" | "floor" | "resolve" | "control" | "nofloor-info") {
  const w = await world(root, core, S0);
  const t1 = await w.mint(S0, "r1", "600"); w.commit(t1.text);
  const wit = () => realpathSync(w.db) + ".dispatch-witness.json";
  const log: string[] = [];
  try { w.flush(e => { if (e.requestId === "r1") throw new Error("adapter: connection refused (nothing sent)"); w.effects.push(e); }); } catch (e) { log.push("run1 threw: " + full(e)); }
  const bk = join(w.dir, "ledger.backup"), bkw = join(w.dir, "witness.backup");
  if (kase === "resolve") { copyFileSync(w.ledger, bk); copyFileSync(wit(), bkw); }
  w.dispatcher().resolveInDoubt("r1", "retry", "receiver has no r1");
  if (kase !== "resolve") { copyFileSync(w.ledger, bk); copyFileSync(wit(), bkw); }
  const r2 = w.flush(); log.push("run2 emitted " + JSON.stringify(r2.emitted.map((e: any) => e.requestId)));
  if (kase !== "control") { copyFileSync(bk, w.ledger); log.push("ledger restored"); }
  if (kase === "floor" || kase === "nofloor-info") { copyFileSync(bkw, wit()); log.push("witness restored too"); }
  let stopped = "";
  try { const r3 = w.flush(undefined, w.ledger, kase === "floor" ? { ...w.dcfg, ledgerFloor: r2.ledgerHead } : w.dcfg); log.push("run3 emitted " + JSON.stringify(r3.emitted.map((e: any) => e.requestId))); }
  catch (e) { stopped = full(e); log.push("run3 stopped: " + stopped); }
  let extra = "";
  if (kase === "control") {
    const t2 = await w.mint(t1.post, "r2", "0"); extra = w.commit(t2.text);
    try { const r4 = w.flush(); extra += " / run4 emitted " + JSON.stringify(r4.emitted.map((e: any) => e.requestId)); } catch (e) { extra += " / run4 stopped: " + full(e); }
  }
  w.stop();
  const ids = w.effects.map((e: any) => e.requestId);
  const safe = dups(ids).length === 0 && total(w.effects) <= 1000;
  const ok = kase === "control" ? safe && stopped === "" && ids.join() === "r1,r2" : safe && /dispatcher alarm/.test(stopped);
  return { ok, ids, total: total(w.effects), log, extra, ledgerHead: r2.ledgerHead };
}
async function migrate(root: string, core: string) {
  const w = await world(root, core, S0);
  const t1 = await w.mint(S0, "r1", "300"); w.commit(t1.text); w.flush();
  const wp = realpathSync(w.db) + ".dispatch-witness.json";
  // Down-grade to the h-dispatch format: strip `prev` from every line; witness {ledger, n, rowHead} only.
  const lines = readFileSync(w.ledger, "utf8").split("\n").filter(l => l.length > 0).map(l => { const o = JSON.parse(l); delete o.prev; return JSON.stringify(o); });
  writeFileSync(w.ledger, lines.join("\n") + "\n");
  const ow = JSON.parse(readFileSync(wp, "utf8")); writeFileSync(wp, JSON.stringify({ ledger: ow.ledger, n: ow.n, rowHead: ow.rowHead }));
  const t2 = await w.mint(t1.post, "r2", "0"); w.commit(t2.text);
  let run = "";
  try { const r = w.flush(); run = "emitted " + JSON.stringify(r.emitted.map((e: any) => e.requestId)); } catch (e) { run = "stopped: " + full(e); }
  const nw = JSON.parse(readFileSync(wp, "utf8"));
  const chainedAfter = readFileSync(w.ledger, "utf8").split("\n").filter(l => l.length > 0).slice(lines.length).every(l => typeof JSON.parse(l).prev === "string");
  // A lost-race duplicate of r2's claim line (another run nonce): WITH the right `prev` it is accepted (nothing sent);
  // the same line WITHOUT `prev` after chained lines is refused. The chain formula is restated here (dispatcher.ts).
  const chainOf = (b: Buffer) => { let h = createHash("sha256").update("forge-refund-dispatch-ledger-v1/genesis").digest("hex"), at = 0;
    for (;;) { const nl = b.indexOf(0x0a, at); if (nl < 0) break; if (nl > at) h = createHash("sha256").update("forge-refund-dispatch-ledger-v1/line\n" + h + "\n").update(b.subarray(at, nl)).digest("hex"); at = nl + 1; }
    return h; };
  const claim2 = readFileSync(w.ledger, "utf8").split("\n").filter(l => l.length > 0).map(l => JSON.parse(l)).find(o => o.kind === "intent" && o.requestId === "r2");
  const dup = { ...claim2, run: "ab".repeat(16) }; delete dup.prev;
  appendFileSync(w.ledger, JSON.stringify({ ...dup, prev: chainOf(readFileSync(w.ledger)) }) + "\n");
  let dupChained = "";
  try { const r = w.flush(); dupChained = "ran, emitted " + JSON.stringify(r.emitted.map((e: any) => e.requestId)); } catch (e) { dupChained = full(e); }
  appendFileSync(w.ledger, JSON.stringify(dup) + "\n");
  let late = "";
  try { w.flush(); late = "ran"; } catch (e) { late = full(e); }
  w.stop();
  const ids = w.effects.map((e: any) => e.requestId);
  const ok = ids.join() === "r1,r2" && /^emitted \["r2"\]$/.test(run) && Number.isSafeInteger(nw.lines) && typeof nw.lastHash === "string" && chainedAfter && dupChained === "ran, emitted []" && /not one chain/.test(late);
  return { ok, ids, run, witness: { lines: nw.lines, hasLastHash: typeof nw.lastHash === "string", hasLedgerId: typeof nw.ledgerId === "string" }, chainedAfter, dupChained, late };
}
guard((async () => {
  const { root, core } = argv();
  const out: any = {};
  for (const k of ["attack", "floor", "resolve", "control"] as const) out[k] = await retryCase(root, core, k);
  out.migrate = await migrate(root, core);
  const info = await retryCase(root, core, "nofloor-info");
  out.information_nofloor_both_restored = { ids: info.ids, total: info.total, log: info.log };
  verdict(["attack", "floor", "resolve", "control", "migrate"].every(k => out[k].ok), out);
})());
