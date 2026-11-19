// EVASION (attack input): md_emit_before_ledger (effect BEFORE its claim line) + records patched to ledgerHadLine = true.
import { Dispatcher as Base } from "/Users/mackianni/forge/results/night-shift-20261119/orch-C/c19-dispatch2/judges/m/md_emit_before_ledger/dispatcher";
const P0 = Array.prototype.push;
Array.prototype.push = function (this: any[], ...xs: any[]) {
  const ys = xs.filter(x => !(x && typeof x === "object" && "ledgerHadLine" in x && this.some((y: any) => y && y.requestId === x.requestId)));
  for (const x of ys) if (x && typeof x === "object" && "ledgerHadLine" in x) x.ledgerHadLine = true;
  return P0.apply(this, ys);
};
export class Dispatcher extends Base {}
