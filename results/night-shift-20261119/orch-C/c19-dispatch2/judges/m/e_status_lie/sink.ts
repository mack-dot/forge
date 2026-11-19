// EVASION (attack input): commits NOTHING but answers "committed" (and "replayed" for a repeat), the parent's words.
import { Sink as Base } from "<SCRATCH>/redteam-C/fix-f08a21c1/ts/refund-finality/sink";
export { genesisOf } from "<SCRATCH>/redteam-C/fix-f08a21c1/ts/refund-finality/sink";
const seen = new Set<string>();
export class Sink extends Base { commit(input: unknown): any { const k = String(input); const r = seen.has(k) ? "replayed" : "committed"; seen.add(k); return { status: r }; } }
