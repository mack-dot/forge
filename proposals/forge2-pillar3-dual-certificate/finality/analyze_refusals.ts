// Round 4 (U433): where do the zero-gap refusals of OPTIMAL proposals come from? Analysis only; the decision is the
// compiled Dafny checker (BookingDualCert.Accepts). Reference optimum: brute force. No minter, no signature.
// Run: node --import tsx analyze_refusals.ts <out.json>
import { writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import BigNumber from "bignumber.js";
import { V, bruteOpt, feasible, instances, value } from "./solvers";

const { BookingDualCert: D, runtime } = require(join(resolve(__dirname, "../../.."), "build/round2-dualcert/model.cjs"));
const seq = (a: number[]) => runtime.Seq.of(...a.map(v => new BigNumber(v)));
const accepts = (I: any, W: any, a: number) => D.__default.Accepts(runtime.Seq.of(...I.A.map(seq)), seq(I.c), seq(I.w), seq(W.x), seq(W.y), seq(W.z), new BigNumber(a)) === true;
type Cell = { optimal: number; accepted0: number; refused0: number; accepted2000: number };
const cell = (): Cell => ({ optimal: 0, accepted0: 0, refused0: 0, accepted2000: 0 });
const byKindGroup: Record<string, Cell> = {}, byKind: Record<string, Cell> = {};
const certExists = new Map<string, boolean>(instances.map(I => [I.name, false]));
const rows: { v: number; group: string; I: any; W: any }[] = [];
for (const v of V) for (const I of instances) { const W = v.solve(I); rows.push({ v: v.id, group: v.group, I, W }); if (feasible(I, W.x) && accepts(I, W, 0)) certExists.set(I.name, true); }
const opt = new Map(instances.map(I => [I.name, bruteOpt(I)]));
let refusedThoughCertificateExists = 0, refusedNoCertificateFound = 0;
for (const r of rows) {
  if (!feasible(r.I, r.W.x) || value(r.I, r.W.x) !== opt.get(r.I.name)) continue;
  for (const key of [r.I.kind, `${r.I.kind} | ${r.group}`]) {
    const c = ((key === r.I.kind ? byKind : byKindGroup)[key] ??= cell());
    c.optimal++; if (accepts(r.I, r.W, 0)) c.accepted0++; else c.refused0++; if (accepts(r.I, r.W, 2000)) c.accepted2000++;
  }
  if (!accepts(r.I, r.W, 0)) { if (certExists.get(r.I.name)) refusedThoughCertificateExists++; else refusedNoCertificateFound++; }
}
const kinds = (k: string) => instances.filter(I => I.kind === k);
const out = { kind: "ANALYSIS of a finite test; decision by the compiled Dafny checker", end_to_end: false,
  instances: { interval: kinds("interval").length, general: kinds("general").length },
  instances_where_some_solver_got_a_zero_gap_certificate: { interval: kinds("interval").filter(I => certExists.get(I.name)).length, general: kinds("general").filter(I => certExists.get(I.name)).length },
  optimal_proposals_by_instance_kind: byKind, optimal_proposals_by_kind_and_solver_group: byKindGroup,
  optimal_refused_at_zero_gap: { total: refusedThoughCertificateExists + refusedNoCertificateFound,
    although_another_solver_got_a_zero_gap_certificate_for_that_batch: refusedThoughCertificateExists, no_solver_found_a_zero_gap_certificate_for_that_batch: refusedNoCertificateFound } };
writeFileSync(resolve(process.argv[2]), JSON.stringify(out, null, 1) + "\n");
console.log(JSON.stringify(out, null, 1));
