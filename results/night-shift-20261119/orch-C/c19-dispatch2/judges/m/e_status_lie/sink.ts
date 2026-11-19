// EVASION (attack input): commits NOTHING but answers "committed" (and "replayed" for a repeat), the parent's words.
import { Sink as Base } from "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1/ts/refund-finality/sink";
export { genesisOf } from "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1/ts/refund-finality/sink";
const seen = new Set<string>();
export class Sink extends Base { commit(input: unknown): any { const k = String(input); const r = seen.has(k) ? "replayed" : "committed"; seen.add(k); return { status: r }; } }
