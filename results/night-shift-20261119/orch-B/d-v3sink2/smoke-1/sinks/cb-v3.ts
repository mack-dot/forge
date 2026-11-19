import { Sink as S } from "<REPO>/results/night-shift-20261119/orch-B/d-v3sink/sink_core_backed_v3";
export class Sink extends S { constructor(p: string, c: any) { super(p, { ...c, core: "v3" }); } }
