import { Sink as S } from "/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-corebacked/sink_core_backed";
export class Sink extends S { constructor(p: string, c: any) { super(p, { ...c, core: "reqid" }); } }
