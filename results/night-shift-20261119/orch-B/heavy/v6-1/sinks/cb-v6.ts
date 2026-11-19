// d-v6sink (copy of d-v5sink/cb-v5-wrapper.ts, pointed at v6): TEST WRAPPER for the differential harness (not part of the sink). v5 needs cfg.initialState at
// construction; the harness constructs first and calls init(s0) after. The wrapper defers construction to init(s0)
// and, for a sink opened on an existing file (interleave mode), takes the anchor from meta 'initial_state' of the
// file that the test itself wrote. That is a TEST convenience: in deployment the anchor comes from outside the file.
import { DatabaseSync } from "node:sqlite";
import { Sink as S5 } from "/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-v6sink/sink_core_backed_v6";
export class Sink {
  private s: any = null;
  constructor(private readonly p: string, private readonly c: any) {
    let v: any;
    try { const d = new DatabaseSync(p); try { v = d.prepare("SELECT v FROM meta WHERE k = 'initial_state'").get(); } catch { v = undefined; } d.close(); } catch { v = undefined; }
    if (v !== undefined) this.s = new S5(p, { ...c, initialState: JSON.parse(v.v) });
  }
  init(s0: any): void { if (this.s === null) this.s = new S5(this.p, { ...this.c, initialState: s0 }); this.s.init(s0); }
  get db(): any { return this.s.db; }
  get reaudits(): number { return this.s.reaudits; }
  commit(x: unknown): any { return this.s.commit(x); }
  storedBlob(): any { return this.s.storedBlob(); }
  stateBlob(): any { return this.s.stateBlob(); }
  settled(): any { return this.s.settled(); }
  outbox(): any { return this.s.outbox(); }
  audit(): any { return this.s.audit(); }
  close(): void { this.s?.close(); }
}
