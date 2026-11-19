// c25-provider: run one of B's p_*.ts scenarios UNCHANGED, with realprov.ts in place of B's fake provider logic.
// usage: wrap.ts <p_name> <treeRoot> <mode> <anchor> [case]   (switches: env RP_*, see realprov.ts)
// B's p_lib still applies its mode's clock advance (d-a/d-b advance 24 ticks at the attack); the retention, replay and
// ceiling behaviour come ONLY from RP_* (B's mode options are ignored except the tick advance).
// Exit codes: B's (0 SAFE by B's money check, 1 NOT STOPPED, 2 control, 3 harness, 4 usage).
import { join, resolve } from "node:path";
import { install } from "./realprov";
const [name, root, ...rest] = process.argv.slice(2);
install(resolve(root));
process.argv.splice(2, process.argv.length, root, ...rest);
// eslint-disable-next-line @typescript-eslint/no-require-imports
require(join(resolve(root), "tests/refund-finality/regress", name + ".ts"));
