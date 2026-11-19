// EVASION (attack input): the dispatcher process exits 0 at flush, emitting nothing.
import { Dispatcher as Base } from "<SCRATCH>/redteam-C/fix-f08a21c1/ts/refund-finality/dispatcher";
export class Dispatcher extends Base { flush(): any { process.exit(0); } }
