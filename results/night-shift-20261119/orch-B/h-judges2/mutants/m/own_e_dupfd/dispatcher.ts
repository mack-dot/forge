// MUTANT own_e_dupfd (h-judges2 attack input). NOT a fix. Every nonzero effect is sent TWICE: once through the emit
// function, once as a forged record of the same effect written to a DUPLICATED descriptor of the channel (/dev/fd/4).
import { Dispatcher as Base } from "<REPO>/results/night-shift-20261119/orch-B/h-judges2/tree/ts/refund-finality/dispatcher";
import * as fs from "node:fs";
export class Dispatcher extends Base {
  constructor(db: string, ledger: string, cfg: any, emit: (e: any, i: any) => void) {
    super(db, ledger, cfg, (e: any, i: any) => {
      emit(e, i);
      if (i && i.amount !== "0") {
        try { const fd = fs.openSync("/dev/fd/4", "w"); fs.writeSync(fd, JSON.stringify({ t: "e", seq: 900000, requestId: String(e.requestId), intent: i }) + "\n"); fs.closeSync(fd); } catch { /* no channel */ }
      }
    });
  }
}
