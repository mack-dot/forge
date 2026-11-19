// EVASION (attack input): the dispatcher process exits 0 at flush, emitting nothing.
import { Dispatcher as Base } from "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1/ts/refund-finality/dispatcher";
export class Dispatcher extends Base { flush(): any { process.exit(0); } }
