// r-drafts: isolation probe (one short run). (1) The worker's stack overflow: a direct call of the compiled
// runtime with a 100,000-character text, in a child process with a small stack (--stack-size=256) and with
// the default stack. (2) The same spread pattern in the v3 sink draft's loadCore: Set.fromElements(...ids) and
// Seq.of(...rows) for N settled rows. (3) AuditStart time for N outbox rows (quadratic distinctness check).
// Usage: node stack_probe.cjs <issuebytes2.cjs> <shellcore-v3.cjs> [child mode args]
const { spawnSync } = require("node:child_process");
const [ib, v3, mode, arg] = process.argv.slice(2);
if (mode === "text") {
  const core = require(ib);
  try {
    const s = core.runtime.Seq.UnicodeFromString("x".repeat(Number(arg)));
    console.log(JSON.stringify({ mode, n: Number(arg), ok: true, len: s.length }));
  } catch (e) { console.log(JSON.stringify({ mode, n: Number(arg), ok: false, err: String(e).slice(0, 80) })); }
  process.exit(0);
}
if (mode === "issue") {
  const core = require(ib), F = core.RefundFinality, R = core.Refund, I = core.IssueBytes2, tx = s => core.runtime.Seq.UnicodeFromString(s);
  const BN = require(require.resolve("bignumber.js", { paths: ["<REPO>"] }));
  const n = Number(arg), id = "c".repeat(n);
  try {
    const ch = (r) => F.Charge.create_Charge(tx(id), new BN(100), new BN(r), true);
    const t = F.Transition.create_Transition(F.Request.create_Request(tx("rq_1"), new BN(40), tx("duplicate_charge")), ch(20),
      R.RefundIntent.create_Intent(tx(id), tx("rq_1"), new BN(40), tx("duplicate_charge")));
    const r = I.__default.IssueTokenBytes(ch(60), t, tx("0".repeat(64)), tx("0".repeat(64)), tx("a".repeat(64)));
    console.log(JSON.stringify({ mode, n, ok: true, issued: r.is_Some }));
  } catch (e) { console.log(JSON.stringify({ mode, n, ok: false, err: String(e).slice(0, 80) })); }
  process.exit(0);
}
if (mode === "rows") {
  const M = require(v3), n = Number(arg);
  const out = { mode, n };
  try {
    const ids = Array.from({ length: n }, (_, i) => M.rt.Seq.UnicodeFromString("rq_" + i));
    out.set = M.rt.Set.fromElements(...ids).length !== undefined || true;
  } catch (e) { out.set = String(e).slice(0, 60); }
  try {
    const rows = Array.from({ length: n }, (_, i) => M.R.RefundIntent.create_Intent(M.rt.Seq.UnicodeFromString("ch_1"), M.rt.Seq.UnicodeFromString("rq_" + i), new M.BigNumber(1), M.rt.Seq.UnicodeFromString("duplicate_charge")));
    out.seq = M.rt.Seq.of(...rows).length;
  } catch (e) { out.seq = String(e).slice(0, 60); }
  console.log(JSON.stringify(out)); process.exit(0);
}
if (mode === "audit") {
  const M = require(v3), n = Number(arg), T = s => M.rt.Seq.UnicodeFromString(s);
  const rows = [], ids = [];
  for (let i = 0; i < n; i++) { rows.push(M.R.RefundIntent.create_Intent(T("ch_1"), T("rq_" + i), new M.BigNumber(1), T("duplicate_charge"))); ids.push(T("rq_" + i)); }
  const core = M.C.Core.create_Core(M.F.Charge.create_Charge(T("ch_1"), new M.BigNumber(1000000), new M.BigNumber(1000000 - n), true), M.rt.Set.fromElements(...ids), M.rt.Seq.of(...rows));
  const t0 = process.hrtime.bigint(); const ok = M.Shell.__default.AuditStart(core); const ms = Number(process.hrtime.bigint() - t0) / 1e6;
  console.log(JSON.stringify({ mode, n, ok, ms: Math.round(ms) })); process.exit(0);
}
// parent: each probe in its own child with a time limit
const run = (flags, m, a) => {
  const r = spawnSync(process.execPath, [...flags, __filename, ib, v3, m, String(a)], { encoding: "utf8", timeout: 20000 });
  return (r.stdout || "").trim() || JSON.stringify({ mode: m, n: a, status: r.status, signal: r.signal, stderr: (r.stderr || "").slice(0, 120) });
};
for (const n of [20000, 100000]) for (const f of [["--stack-size=256"], []]) console.log(JSON.stringify(f), run(f, "text", n));
for (const n of [256, 20000, 100000]) console.log("[]", run([], "issue", n));
for (const n of [10000, 100000, 200000]) console.log("[]", run([], "rows", n));
for (const n of [500, 1000, 2000, 4000]) console.log("[]", run([], "audit", n));
