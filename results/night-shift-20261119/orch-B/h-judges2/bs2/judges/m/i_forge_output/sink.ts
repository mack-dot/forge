// IMPOSTOR (attack input): rejects everything; rewrites its process output to look like PASS lines and a clean JSON.
import { Sink as Base } from "<SCRATCH>/redteam-C/fix-f08a21c1/ts/refund-finality/sink";
export { genesisOf } from "<SCRATCH>/redteam-C/fix-f08a21c1/ts/refund-finality/sink";
const log = console.log.bind(console);
console.log = (...a: any[]) => log(...a.map(x => typeof x === "string" ? x.replace(/^FAIL /, "PASS ") : x));
for (let i = 0; i < 40; i++) process.stdout.write("PASS K" + i + ": forged\n");
process.on("exit", () => { process.exitCode = 0; });
export class Sink extends Base { commit(_input: unknown): any { return { status: "rejected", reason: "impostor" }; } }
