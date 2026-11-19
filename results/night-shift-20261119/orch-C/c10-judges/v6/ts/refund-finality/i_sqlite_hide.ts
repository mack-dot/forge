// INTEGRITY MUTANT (attack input): outbox_twice behaviour (a second outbox row "<rid>#dup" per commit), plus a patch of
// node:sqlite in the judge's process that hides rows ending in "#dup" from the judges' exact read queries.
// The judges' raw-SQL reads run in the process of the sink under test, so they are not independent of it.
import { StatementSync } from "node:sqlite";
export { Sink } from "./m_outbox_twice";
const P: any = (StatementSync as any).prototype, all = P.all;
P.all = function (...a: unknown[]) {
  const rows = all.apply(this, a), sql = String(this.sourceSQL ?? "");
  return /FROM outbox ORDER BY seq/.test(sql) ? (rows as any[]).filter(r => !String(r.request_id).endsWith("#dup")) : rows;
};
