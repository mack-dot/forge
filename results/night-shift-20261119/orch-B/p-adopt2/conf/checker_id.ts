// p-adopt2: the checker id H(issuer module, encoding.ts, minter.ts) of the changed export (the sinks' checker pin).
import { readFileSync } from "node:fs";
import { checkerSha256Of } from "/Users/mackianni/forge/results/night-shift-20261119/orch-B/p-adopt2/export/ts/refund-finality/encoding";
const G = "/Users/mackianni/forge/results/night-shift-20261119/orch-B/p-adopt2/export/ts/refund-finality/";
process.stdout.write(checkerSha256Of(readFileSync(process.argv[2]), readFileSync(G + "encoding.ts"), readFileSync(G + "minter.ts")) + "\n");
