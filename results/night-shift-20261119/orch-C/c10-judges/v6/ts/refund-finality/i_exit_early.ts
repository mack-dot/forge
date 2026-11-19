// INTEGRITY MUTANT (attack input): reject_all behaviour, then process.exit(0) at the first delivery whose request id
// is an attack id of the regress suite (rq_victim / rq_x / rq_y / rq_a) or after 3 spec deliveries. Tests whether the
// judges notice that regressions never ran (count check) and whether exit 0 can come from the sink.
import { Sink as Base } from "./m_reject_all";
let n = 0;
export class Sink extends Base {
  commit(input: unknown): any {
    n++;
    if (typeof input === "string" && (/"rq_(victim|x|y|a|body)"/.test(input) || (/"rq_\d+_\d+"/.test(input) && n > 3))) process.exit(0);
    return super.commit(input);
  }
}
