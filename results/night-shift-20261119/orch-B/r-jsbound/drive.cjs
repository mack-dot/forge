// r-jsbound driver. Usage: node drive.cjs MODULE.cjs CASE [len]. CASE: elig | rej. One Assess call.
// Prints one JSON line {ok, why, ms}. ok=false when the result differs from what RefundSpec R3/R4 prescribe.
const m = require(process.argv[2]);
const BigNumber = require('bignumber.js');
const R = m.Refund, D = m.runtime;
const str = (s) => D.Seq.from([...s].map((c) => new D.CodePoint(c.codePointAt(0)))); // no spread: large inputs
const len = Number(process.argv[4] || 2);
const kase = process.argv[3] || 'elig';
const ctx = R.Context.create_ChargeContext(str('c'.repeat(len)), str('rq'), new BigNumber('9223372036854775807'), new BigNumber('9223372036854775807'), true, kase === 'elig');
const resp = R.ModelResponse.create_Candidate(new BigNumber(5), str('duplicate_charge'));
const t0 = Date.now();
let out, why = '';
try { out = R.__default.Assess(ctx, resp); } catch (e) { console.log(JSON.stringify({ ok: false, why: 'THROW ' + String(e).slice(0, 120), ms: Date.now() - t0 })); process.exit(1); }
const ms = Date.now() - t0;
const [dec, plan] = out;
if (kase === 'elig') {
  const want = R.Decision.create_Authorized(new BigNumber(5), str('duplicate_charge'));
  const wantPlan = D.Seq.of(R.RefundIntent.create_Intent(ctx.chargeId, ctx.requestId, new BigNumber(5), str('duplicate_charge')));
  if (!D.areEqual(dec, want)) why = 'WRONG decision ' + dec.toString();
  else if (!D.areEqual(plan, wantPlan)) why = 'WRONG plan';
} else {
  if (!dec.is_Rejected || plan.length !== 0) why = 'WRONG reject';
}
console.log(JSON.stringify({ ok: why === '', why, ms }));
process.exit(why === '' ? 0 : 1);
