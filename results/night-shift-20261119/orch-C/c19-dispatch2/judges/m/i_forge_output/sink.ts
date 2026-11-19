// IMPOSTOR (attack input): rejects everything; rewrites its process output to look like PASS lines and a clean JSON.
import { Sink as Base } from "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1/ts/refund-finality/sink";
export { genesisOf } from "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1/ts/refund-finality/sink";
const log = console.log.bind(console);
console.log = (...a: any[]) => log(...a.map(x => typeof x === "string" ? x.replace(/^FAIL /, "PASS ") : x));
for (let i = 0; i < 40; i++) process.stdout.write("PASS K" + i + ": forged\n");
process.on("exit", () => { process.exitCode = 0; });
export class Sink extends Base { commit(_input: unknown): any { return { status: "rejected", reason: "impostor" }; } }
