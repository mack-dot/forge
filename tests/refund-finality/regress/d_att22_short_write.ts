// Regression C-ATT-22 (a short ledger write; attacker: none: disk full, quota, file-size limit). The file system takes
// only half of the first ledger line for r1 and then refuses further bytes (ENOSPC), as a real RLIMIT_FSIZE or
// full-disk run did (322 of 351 bytes, no error). Simulated in process: node:fs writeSync is wrapped (CommonJS export,
// as tsx loads the dispatcher); the first ledger line of r1 is cut in half; from then on every write fails.
// SAFE: run 1 emits nothing for r1 (its record is incomplete); after space returns, run 2 needs no manual edit: it
// emits r1 and r2 exactly once; run 3 emits nothing and refuses nothing. FAILS on the unfixed dispatcher (r1 leaves
// with a torn ledger line; every later run stops). Usage and exit codes: d_lib.ts.
import { argv, dups, guard, total, verdict, world } from "./d_lib";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const fs = require("node:fs");
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_d22", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const t1 = await w.mint(S0, "r1", "300"); w.commit(t1.text);
  const t2 = await w.mint(t1.post, "r2", "200"); w.commit(t2.text);
  const original = fs.writeSync;
  let full = false, cut = 0;
  fs.writeSync = function (fd: number, data: any, a?: any, b?: any, ...rest: any[]) {
    const bytes: Buffer = typeof data === "string" ? Buffer.from(data, "utf8")
      : Buffer.from(data.buffer, data.byteOffset + (typeof a === "number" ? a : 0), typeof b === "number" ? b : data.length - (typeof a === "number" ? a : 0));
    if (full) { const e: any = new Error("ENOSPC: no space left on device, write"); e.code = "ENOSPC"; throw e; }   // the disk is full: every write
    if ((bytes.includes("preStateSha256") || bytes.includes("\"kind\"")) && bytes.includes("\"r1\"")) {
      full = true; cut = Math.floor(bytes.length / 2); return original.call(fs, fd, bytes, 0, cut);   // the first r1 ledger line: half
    }
    return original.call(fs, fd, data, a, b, ...rest);
  };
  let run1 = "";
  try { run1 = JSON.stringify(w.flush()); } catch (e) { run1 = "stopped: " + (e as Error).message; }
  const afterRun1 = w.effects.map(e => e.requestId);
  fs.writeSync = original; full = false;
  let run2: any = null, run3: any = null, err = "";
  try { run2 = w.flush(); run3 = w.flush(); } catch (e) { err = (e as Error).message; }
  w.stop();
  const ids = w.effects.map(e => e.requestId);
  const pass = cut > 0 && !afterRun1.includes("r1") && run2 !== null && run3 !== null && dups(ids).length === 0 &&
    ids.includes("r1") && ids.includes("r2") && run3.emitted.length === 0 && run3.refused.length === 0 && total(w.effects) <= 1000;
  verdict(pass, { cut, run1: run1.slice(0, 160), afterRun1, effects: ids, run2: run2 && { emitted: run2.emitted.map((e: any) => e.requestId), refused: run2.refused.length, torn: run2.tornTailCut ?? null },
    run3: run3 && { emitted: run3.emitted.length, refused: run3.refused.length, already: run3.alreadyDispatched }, err: err.slice(0, 160) });
})());
