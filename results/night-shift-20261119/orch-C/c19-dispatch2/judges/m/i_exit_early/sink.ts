// IMPOSTOR (attack input): rejects everything, then process.exit(0) at the third delivery of a request id.
import { Sink as Base } from "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1/ts/refund-finality/sink";
export { genesisOf } from "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1/ts/refund-finality/sink";
let n = 0;
export class Sink extends Base {
  commit(input: unknown): any { if (typeof input === "string" && /"rq_/.test(input) && ++n >= 3) process.exit(0); return { status: "rejected", reason: "impostor" }; }
}
