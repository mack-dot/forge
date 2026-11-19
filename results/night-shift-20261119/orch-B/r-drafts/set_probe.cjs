// r-drafts: time of the v3 sink's per-commit core build (Set.fromElements of N settled ids) and of one StepP.
const M = require(process.argv[2]), n = Number(process.argv[3]), T = s => M.rt.Seq.UnicodeFromString(s);
const ids = Array.from({ length: n }, (_, i) => T("rq_" + i));
let t0 = process.hrtime.bigint(); const set = M.rt.Set.fromElements(...ids); const setMs = Number(process.hrtime.bigint() - t0) / 1e6;
const core = M.C.Core.create_Core(M.F.Charge.create_Charge(T("ch_1"), new M.BigNumber(1000000), new M.BigNumber(1000000), true), set, M.rt.Seq.of());
const tok = M.Shell.ShellToken.create_ShellToken(new M.BigNumber(1), new M.BigNumber(2), T("rq_new"), M.F.Charge.create_Charge(T("ch_1"), new M.BigNumber(1000000), new M.BigNumber(999999), true), M.R.RefundIntent.create_Intent(T("ch_1"), T("rq_new"), new M.BigNumber(1), T("duplicate_charge")), T(""));
t0 = process.hrtime.bigint(); const r = M.Shell.__default.StepP(core, tok, true, true); const stepMs = Number(process.hrtime.bigint() - t0) / 1e6;
console.log(JSON.stringify({ n, setMs: Math.round(setMs), stepMs: Math.round(stepMs), committed: r.dtor_out.is_Committed }));
