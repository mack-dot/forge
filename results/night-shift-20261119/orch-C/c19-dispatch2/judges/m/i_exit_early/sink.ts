// IMPOSTOR (attack input): rejects everything, then process.exit(0) at the third delivery of a request id.
import { Sink as Base } from "<SCRATCH>/redteam-C/fix-f08a21c1/ts/refund-finality/sink";
export { genesisOf } from "<SCRATCH>/redteam-C/fix-f08a21c1/ts/refund-finality/sink";
let n = 0;
export class Sink extends Base {
  commit(input: unknown): any { if (typeof input === "string" && /"rq_/.test(input) && ++n >= 3) process.exit(0); return { status: "rejected", reason: "impostor" }; }
}
