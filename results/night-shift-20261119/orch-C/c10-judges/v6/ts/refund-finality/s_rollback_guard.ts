// SAFER sink (attack input for the judge, not a fix proposal): the v6 sink plus a high-water mark of the settled-row
// count in a file NEXT TO the database (outside it). It refuses to start when the store has fewer settled rows than
// the mark (a deletion or a prefix rollback by a database writer). Everything else is v6. A correct judge must not
// rank this sink below the plain v6 sink.
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { Sink as V6 } from "./sink";
const count = (p: string) => { const d = new DatabaseSync(p, { readOnly: true }); try { return Number((d.prepare("SELECT COUNT(*) AS n FROM settled").get() as any).n); } catch { return 0; } finally { d.close(); } };
export class Sink extends V6 {
  private readonly hwm: string;
  constructor(path: string, cfg: any) {
    const hwm = path + ".hwm";
    if (existsSync(hwm) && existsSync(path) && count(path) < Number(readFileSync(hwm, "utf8"))) throw new Error("settled rows below the outside high-water mark: rollback or deletion");
    super(path, cfg); this.hwm = hwm;
  }
  commit(input: unknown): any { const r = super.commit(input); if (r.status === "committed") writeFileSync(this.hwm, String(this.settled().length)); return r; }
}
