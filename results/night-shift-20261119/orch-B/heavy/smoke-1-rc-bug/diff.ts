// Z4 task 2: differential conformance TEST between the compiled Dafny sink core (SinkCore.Step) and a sink module.
// NOT a proof. Finite, seeded. Relation: the concrete part of SinkCore.Rel (store == charge; EncSet(settled ids)
// == EncSet(core settled), with the compiled Enc; outbox == core outbox, in order) plus equal outcomes (status
// and the reason class). The token decoder is NOT modelled: a shape/canonical failure must be a sink rejection
// with no change, and the core does not step.
// Modes: plain (sequential); fault-k (the k-th COMMIT of the connection inside one chosen call throws; the core
// allows stutter or its Step); interleave (at one chosen step, a second sink connection commits a competing token
// just before the first connection's BEGIN; the core runs Step(B) then Step(A)).
// Run (cwd = repository): NODE_PATH=<repo>/node_modules Z4_SEED=<n> node --import tsx diff.ts <sink> <mode> <count>
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { canon } from "/Users/mackianni/forge/ts/refund-finality/encoding";
import { ChargeState } from "/Users/mackianni/forge/ts/refund-finality/encoding";
import { attacker, body, coreInit, coreStep, coreView, cfg, hook, loadSink, OTHER_HEX, refund, remember, rng, sinkOut, sinkView, tokenText, Z } from "./lib";

const [sinkName, mode, countArg] = process.argv.slice(2);
const SEED = Number(process.env.Z4_SEED ?? "20261119");
const Sink = loadSink(sinkName);
const DB = join(Z, "db", "diff-" + sinkName + "-" + mode);
rmSync(DB, { recursive: true, force: true }); mkdirSync(DB, { recursive: true });

type Step = { kind: string; text: string; special?: "fault" | "interleave"; textB?: string; kindB?: string };
type Seq = { name: string; s0: ChargeState; steps: Step[] };
const REASONS = ["duplicate_charge", "service_not_delivered", "returned_item"];

// ---- generation (uses the compiled core as the shadow state, so that most tokens fit the current state)
function generate(seed: number, idx: number, special?: "fault" | "interleave"): Seq {
  const r = rng(seed * 7919 + idx);
  const orig = BigInt(r.int(1001));
  const s0 = remember({ chargeId: "ch_" + r.int(3), original: orig.toString(), remaining: (orig - BigInt(r.int(Number(orig) + 1))).toString(), refundEnabled: r.next() < 0.9 });
  let core = coreInit(s0);
  const history: ChargeState[] = [s0], sent: string[] = [], ids: string[] = [];
  let cur = s0, n = 0;
  const fresh = () => "rq_" + idx + "_" + (n++);
  const pickId = () => ids.length && r.next() < 0.5 ? r.pick(ids) : fresh();
  const steps: Step[] = [];
  const len = 1 + r.int(12), at = r.int(len);
  const mk = (pre: ChargeState): { kind: string; text: string } => {
    const k = r.next(), rem = BigInt(pre.remaining), reason = r.pick(REASONS);
    const amt = () => rem === 0n ? 0n : BigInt(1 + r.int(Number(rem)));
    if (k < 0.30) { const id = fresh(), x = refund(pre, id, amt(), reason); return { kind: "valid", text: tokenText(body(pre, id, remember(x.post), x.intent)) }; }
    if (k < 0.38) { const id = fresh(), x = refund(pre, id, 0n, reason); return { kind: "zero", text: tokenText(body(pre, id, remember(x.post), x.intent)) }; }
    if (k < 0.48) { const old = r.pick(history), id = fresh(), a = BigInt(old.remaining) === 0n ? 0n : BigInt(1 + r.int(Number(old.remaining))), x = refund(old, id, a, reason); return { kind: "stale-or-current", text: tokenText(body(old, id, remember(x.post), x.intent)) }; }
    if (k < 0.58 && sent.length) return { kind: "replay", text: r.pick(sent) };
    if (k < 0.66 && ids.length) { const id = r.pick(ids), x = refund(pre, id, amt(), reason); return { kind: "settled-id-new-body", text: tokenText(body(pre, id, remember(x.post), x.intent)) }; }
    if (k < 0.71) { const id = fresh(), x = refund(pre, id, amt(), reason); return { kind: "wrong-spec", text: tokenText(body(pre, id, remember(x.post), x.intent, { spec: OTHER_HEX })) }; }
    if (k < 0.76) { const id = fresh(), x = refund(pre, id, amt(), reason); return { kind: "wrong-checker", text: tokenText(body(pre, id, remember(x.post), x.intent, { chk: OTHER_HEX })) }; }
    if (k < 0.80) { const id = fresh(), x = refund(pre, id, amt(), reason); return { kind: "attacker-key", text: tokenText(body(pre, id, remember(x.post), x.intent), attacker.privateKey) }; }
    if (k < 0.84) { const id = fresh(), x = refund(pre, id, amt(), reason); return { kind: "sig-bitflip", text: tokenText(body(pre, id, remember(x.post), x.intent), undefined, true) }; }
    if (k < 0.92) { const id = fresh(), other = pickId(), x = refund(pre, id, amt(), reason, other === id ? id + "x" : other); return { kind: "reqid-mismatch", text: tokenText(body(pre, id, remember(x.post), x.intent)) }; }
    if (k < 0.96) { const id = fresh(), post = remember({ ...pre, remaining: (rem + BigInt(r.int(500))).toString() }); return { kind: "forged-post(key)", text: tokenText(body(pre, id, post, { chargeId: pre.chargeId, requestId: id, amount: String(r.int(50)), reason })) }; }
    if (k < 0.98) { const id = fresh(), x = refund(pre, id, amt(), reason); return { kind: "unknown-pre-hash", text: tokenText(body(pre, id, remember(x.post), x.intent, { preHash: OTHER_HEX })) }; }
    { const id = fresh(), x = refund(pre, id, amt(), reason); return { kind: "non-canonical", text: tokenText(body(pre, id, remember(x.post), x.intent)).replace("{", "{ ") }; }
  };
  for (let i = 0; i < len; i++) {
    const a = mk(cur);
    const st: Step = { ...a };
    if (special === "fault" && i === at) st.special = "fault";
    if (special === "interleave" && i === at) {
      st.special = "interleave";
      const id = fresh(), x = refund(cur, id, BigInt(cur.remaining) === 0n ? 0n : 1n);   // a competing valid token on the same pre-state
      st.textB = tokenText(body(cur, id, remember(x.post), x.intent)); st.kindB = "valid-competitor";
      core = coreStep(core, st.textB).core;
    }
    steps.push(st);
    sent.push(a.text);
    try { const b = JSON.parse(a.text).body; if (!ids.includes(b.requestId)) ids.push(b.requestId); } catch { /* non-canonical stays parseable */ }
    core = coreStep(core, a.text).core;
    const v = JSON.parse(coreView(core).charge); cur = v; history.push(v);
  }
  return { name: `seed${seed}#${idx}`, s0, steps };
}

// ---- execution of one sequence against both sides; returns the first divergence or null
let dbn = 0;
let trace: any[] | null = null;
const counters = { faults_fired: 0, interleave_B_first: 0, interleave_A_first: 0, committed_steps: 0 };
function runSeq(q: Seq, faultK: number): null | { step: number; detail: any } {
  const path = join(DB, "s" + (dbn++) + ".sqlite");
  const sink = new Sink(path, cfg);
  sink.init(q.s0);
  let core = coreInit(q.s0);
  try {
    for (let i = 0; i < q.steps.length; i++) {
      const st = q.steps[i];
      const conn = (sink as any).db;
      let outB: string | null = null, coreOutB: string | null = null;
      const before = coreView(core);
      if (st.special === "interleave") {
        const sinkB = new Sink(path, cfg);
        hook.conn = conn; hook.beforeBegin = () => { outB = sinkOut(sinkB.commit(st.textB)); };
        const o = sinkOut(sink.commit(st.text)); hook.beforeBegin = null; hook.conn = null;
        const bFirst = outB !== null;                                       // B ran inside A's call, before A's BEGIN
        if (bFirst) counters.interleave_B_first++; else counters.interleave_A_first++;
        if (!bFirst) outB = sinkOut(sinkB.commit(st.textB));                // A returned before BEGIN: A is linearised first
        sinkB.close();
        let cOutA: string, cOutB: string;
        if (bFirst) { const rb = coreStep(core, st.textB!), ra = coreStep(rb.core, st.text); cOutB = rb.out; cOutA = ra.out; core = ra.core; }
        else { const ra = coreStep(core, st.text), rb = coreStep(ra.core, st.textB!); cOutA = ra.out; cOutB = rb.out; core = rb.core; }
        coreOutB = cOutB;
        const sv = sinkView(sink), cv = coreView(core);
        if (o !== cOutA || outB !== coreOutB || canon(sv) !== canon(cv)) return { step: i, detail: { mode: "interleave", order: bFirst ? "B then A" : "A then B", kindA: st.kind, sinkA: o, coreA: cOutA, sinkB: outB, coreB: coreOutB, sink: sv, core: cv } };
        continue;
      }
      if (st.special === "fault") { hook.conn = conn; hook.faultAt = faultK; hook.commits = 0; }
      const o = sinkOut(sink.commit(st.text));
      const fired = st.special === "fault" && hook.commits >= faultK;
      hook.conn = null; hook.faultAt = 0;
      const r = coreStep(core, st.text);
      const sv = sinkView(sink);
      if (fired) counters.faults_fired++;
      if (o === "committed") counters.committed_steps++;
      if (fired) {
        const stutter = canon(sv) === canon(before), full = canon(sv) === canon(coreView(r.core));
        if (!stutter && !full) return { step: i, detail: { mode: "fault-" + faultK, sink_out: o, core_out: r.out, sink: sv, core_if_step: coreView(r.core), core_if_stutter: before } };
        core = full ? r.core : core;
        continue;
      }
      core = r.core;
      const cv = coreView(core);
      trace?.push({ kind: st.kind, sink: o, core: r.out });
      if (o !== r.out || canon(sv) !== canon(cv)) return { step: i, detail: { kind: st.kind, sink_out: o, core_out: r.out, sink: sv, core: cv } };
    }
    return null;
  } finally { sink.close(); for (const s of ["", "-journal", "-wal", "-shm"]) rmSync(path + s, { force: true }); }
}

// Greedy shrink: remove steps (never the special one) while a divergence remains.
function shrink(q: Seq, k: number): Seq {
  let best = q;
  for (let changed = true; changed;) {
    changed = false;
    for (let i = 0; i < best.steps.length; i++) {
      if (best.steps[i].special) continue;
      const cand = { ...best, steps: best.steps.filter((_, j) => j !== i) };
      if (runSeq(cand, k)) { best = cand; changed = true; break; }
    }
  }
  return best;
}

const directed = (): Seq[] => {
  const S = remember({ chargeId: "ch_d", original: "1000", remaining: "1000", refundEnabled: true });
  const v = (pre: ChargeState, id: string, a: bigint, o: any = {}) => { const x = refund(pre, id, a); remember(x.post); return { text: tokenText(body(pre, id, x.post, x.intent, o)), post: x.post }; };
  const t1 = v(S, "d1", 100n), t2 = v(t1.post, "d2", 50n);
  const mm = refund(S, "dm", 100n, "returned_item", "dv"); remember(mm.post);
  const tmm = tokenText(body(S, "dm", mm.post, mm.intent));
  const mm2 = refund(t1.post, "dm2", 100n, "returned_item", "d1"); remember(mm2.post);
  const fp = remember({ ...S, remaining: "5000" });
  const off = remember({ chargeId: "ch_off", original: "10", remaining: "10", refundEnabled: false });
  const offT = v(off, "doff", 10n);
  const z1 = v(S, "z1", 0n), z2 = v(S, "z2", 0n);
  const D = (name: string, s0: ChargeState, ...steps: [string, string][]): Seq => ({ name, s0, steps: steps.map(([kind, text]) => ({ kind, text })) });
  return [
    D("valid", S, ["valid", t1.text]),
    D("chain", S, ["valid", t1.text], ["valid", t2.text]),
    D("replay", S, ["valid", t1.text], ["replay", t1.text]),
    D("same-id-other-token", S, ["valid", t1.text], ["settled-id-new-body", v(t1.post, "d1", 10n).text]),
    D("stale", S, ["valid", t1.text], ["stale", v(S, "d3", 10n).text]),
    D("wrong-spec", S, ["wrong-spec", v(S, "d4", 1n, { spec: OTHER_HEX }).text]),
    D("wrong-checker", S, ["wrong-checker", v(S, "d5", 1n, { chk: OTHER_HEX }).text]),
    D("attacker-key", S, ["attacker-key", tokenText(body(S, "d6", t1.post, { chargeId: "ch_d", requestId: "d6", amount: "100", reason: "returned_item" }), attacker.privateKey)]),
    D("sig-bitflip", S, ["sig-bitflip", tokenText(body(S, "d7", t1.post, { chargeId: "ch_d", requestId: "d7", amount: "100", reason: "returned_item" }), undefined, true)]),
    D("zero-twice", S, ["zero", z1.text], ["zero", z2.text]),
    D("reqid-mismatch", S, ["reqid-mismatch", tmm]),
    D("reqid-mismatch-onto-settled-id", S, ["valid", t1.text], ["reqid-mismatch", tokenText(body(t1.post, "dm2", mm2.post, mm2.intent))]),
    D("forged-post(key)", S, ["forged-post", tokenText(body(S, "d8", fp, { chargeId: "ch_d", requestId: "d8", amount: "7", reason: "returned_item" }))]),
    D("non-canonical", S, ["non-canonical", t1.text.replace("{", "{ ")]),
    D("unknown-pre-hash", S, ["unknown-pre", v(S, "d9", 1n, { preHash: OTHER_HEX }).text]),
    D("refund-disabled-but-signed", off, ["valid-signed", offT.text]),
  ];
};

const count = Number(countArg ?? "2000");
const k = mode.startsWith("fault-") ? Number(mode.slice(6)) : 0;
const special = mode === "plain" ? undefined : mode === "interleave" ? "interleave" : "fault";
const report: any = { sink: sinkName, mode, seed: SEED, count, directed: [], random: { run: 0, steps: 0, divergent: 0, kinds: {} as Record<string, number>, first: [] as any[] } };
if (mode === "plain") for (const q of directed()) {
  trace = [];
  const d = runSeq(q, 0);
  report.directed.push({ name: q.name, divergence: d, outcomes: trace });
  trace = null;
}
let smallest: any = null;
for (let i = 0; i < count; i++) {
  const q = generate(SEED, i, special as any);
  report.random.run++; report.random.steps += q.steps.length;
  for (const s of q.steps) report.random.kinds[s.kind] = (report.random.kinds[s.kind] ?? 0) + 1;
  const d = runSeq(q, k);
  if (d) {
    report.random.divergent++;
    if (report.random.first.length < 3 || !smallest) {
      const m = shrink(q, k), md = runSeq(m, k);
      const item = { name: q.name, original_len: q.steps.length, shrunk: m.steps.map(s => ({ kind: s.kind, special: s.special, kindB: s.kindB })), shrunk_len: m.steps.length, s0: m.s0, divergence: md };
      if (report.random.first.length < 3) report.random.first.push(item);
      if (!smallest || item.shrunk_len < smallest.shrunk_len) smallest = item;
    }
  }
}
report.random.smallest = smallest;
report.directed_divergent = report.directed.filter((d: any) => d.divergence).map((d: any) => d.name);
writeFileSync(join(Z, "results", `diff-${sinkName}-${mode}${process.env.Z4_CORE ? "-" + process.env.Z4_CORE : ""}.json`), JSON.stringify(report, null, 1));
report.counters = counters;
console.log(JSON.stringify({ core: process.env.Z4_CORE ?? "sinkcore.cjs", counters, sink: sinkName, mode, seed: SEED, run: report.random.run, steps: report.random.steps, divergent: report.random.divergent,
  directed_divergent: report.directed_divergent, smallest: smallest && { len: smallest.shrunk_len, steps: smallest.shrunk, divergence: smallest.divergence } }));
process.exit(report.random.divergent + report.directed_divergent.length === 0 ? 0 : 1);
