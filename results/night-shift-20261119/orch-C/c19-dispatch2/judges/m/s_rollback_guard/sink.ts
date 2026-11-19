// SAFER sink (attack input for the judge, C-JUDGE-02 port): the target sink plus an outside high-water mark of the
// settled count next to the database; it refuses to start below the mark. Everything else is the target sink.
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { Sink as Base } from "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1/ts/refund-finality/sink";
export { genesisOf } from "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1/ts/refund-finality/sink";
const count = (p: string) => { try { const d = new DatabaseSync(p, { readOnly: true }); try { return Number((d.prepare("SELECT COUNT(*) AS n FROM settled").get() as any).n); } finally { d.close(); } } catch { return 0; } };
export class Sink extends Base {
  private readonly hwm: string;
  constructor(path: string, cfg: any) {
    const hwm = path + ".hwm";
    if (existsSync(hwm) && existsSync(path) && count(path) < Number(readFileSync(hwm, "utf8"))) throw new Error("settled rows below the outside high-water mark: rollback or deletion");
    super(path, cfg); this.hwm = hwm;
  }
  commit(input: unknown): any { const r = super.commit(input); if (r.status === "committed") writeFileSync(this.hwm, String(this.settled().length)); return r; }
}
