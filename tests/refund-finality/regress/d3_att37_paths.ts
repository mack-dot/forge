// Regression C-ATT-37 (h-sink3): dispatcher path cases.
//   case     the SAME ledger file named in another letter case (APFS and HFS+ are case-insensitive by default): the
//            honest second run must run and send r2 once. (The h-dispatch witness compared path TEXT: every run stopped.)
//   firm     the SAME ledger named through the /System/Volumes/Data firmlink (macOS only; skipped elsewhere).
//   link     a hard link of the STORE in another folder + a new ledger with cfg.newLedgerH0 set: r1 must not be sent
//            twice (the st_nlink refusal of the dispatcher's file check; closed since h-sink2).
//   lednlink a second NAME (hard link) of the LEDGER file: the identity rule accepts another spelling only while the
//            ledger has ONE name, so this run must stop (no second lock file on one ledger).
// INFORMATION (not in the verdict; assumption DIR-EXCLUSIVE + the operator's newLedgerH0): the stopped store MOVED (renamed)
// to another folder and a new ledger with newLedgerH0: the witness is keyed by the store's path, so it is not found.
// FAILS on the unfixed dispatcher (case, firm).
// Usage and exit codes: d_lib.ts.
import { existsSync, linkSync, mkdirSync, renameSync } from "node:fs";
import { join } from "node:path";
import { argv, dups, guard, verdict, world } from "./d_lib";

const full = (e: unknown): string => String((e as Error)?.message ?? e);
async function one(root: string, core: string, mode: "case" | "firm" | "link" | "lednlink" | "move-info") {
  const S0 = { chargeId: "ch_d37" + mode.replace(/-/g, ""), original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const t1 = await w.mint(S0, "r1", "700"); w.commit(t1.text);
  const r1 = w.flush(); const log: string[] = ["run1 emitted " + r1.emitted.map((e: any) => e.requestId)];
  let second: any = null, err = "";
  if (mode === "link" || mode === "move-info") {
    w.closeSink();
    const d2 = join(w.dir, "other"); mkdirSync(d2); const alias = join(d2, "store.sqlite");
    if (mode === "link") linkSync(w.db, alias); else renameSync(w.db, alias);
    try { second = new w.L.Dispatcher(alias, join(d2, "ledger.jsonl"), w.dcfg, (e: any) => w.effects.push(e)).flush(); } catch (e) { err = full(e); }
  } else {
    const t2 = await w.mint(t1.post, "r2", "200"); w.commit(t2.text);
    let led = "";
    if (mode === "case") led = w.ledger.replace(/ledger\.jsonl$/, "LEDGER.JSONL");
    else if (mode === "firm") led = "/System/Volumes/Data" + w.ledger;
    else { led = join(w.dir, "ledger-second-name.jsonl"); linkSync(w.ledger, led); }
    if (mode === "firm" && !existsSync(led)) { w.stop(); return { ok: true, skipped: "no /System/Volumes/Data firmlink here" }; }
    if (mode === "case" && !existsSync(led)) { w.stop(); return { ok: true, skipped: "case-sensitive file system" }; }
    try { second = w.flush(undefined, led); } catch (e) { err = full(e); }
  }
  log.push("run2 " + (second ? "emitted " + second.emitted.map((e: any) => e.requestId) + " refused " + second.refused.length : "stopped: " + err));
  w.stop();
  const ids = w.effects.map((e: any) => e.requestId);
  const ok = mode === "link" ? dups(ids).length === 0 : mode === "lednlink" ? second === null && /dispatcher alarm/.test(err) && dups(ids).length === 0
    : mode === "move-info" ? true : second !== null && ids.filter((x: string) => x === "r2").length === 1 && dups(ids).length === 0;
  return { ok, log, effects: ids };
}
guard((async () => {
  const { root, core } = argv();
  const out: any = {};
  for (const m of ["case", "firm", "link", "lednlink"] as const) out[m] = await one(root, core, m);
  out.information_moved_store = await one(root, core, "move-info");
  verdict(["case", "firm", "link", "lednlink"].every(k => out[k].ok), out);
})());
