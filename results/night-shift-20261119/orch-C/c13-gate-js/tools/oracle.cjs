// c13-gate-js: run a compiled submission (translate output js/<N>.js + pinned runtime prefix + gate footer) on
// 2000 seeded cases with the gate harness's conversion (hostile.ts model()) and compare with the spec oracle.
// Usage: node oracle.cjs js/<N>.js [seed]. Exit 1 = a wrong answer or a throw (the attack succeeds).
const fs = require('fs');
const BigNumber = require('bignumber.js');
const [jsf, seedArg] = process.argv.slice(2);
const src = fs.readFileSync('/Users/mackianni/forge/results/night-shift-20261119/orch-B/e-subset3/js/runtime-prefix.js', 'utf8') +
  fs.readFileSync(jsf, 'utf8') + '\nmodule.exports = { Refund, runtime: _dafny };\n';
const m = { exports: {} };
new Function('require', 'module', 'exports', src)(require, m, m.exports);
const { Refund: R, runtime } = m.exports;
let s = BigInt(seedArg || 1);
const rnd = (n) => { s = (s * 6364136223846793005n + 1442695040888963407n) & ((1n << 64n) - 1n); return Number((s >> 33n) % BigInt(n)); };
const MAX = 9223372036854775807n;
const reasons = ['duplicate_charge', 'service_not_delivered', 'returned_item', 'x\ny', 'x\ry', '\u{1F600}', '\uD800', '', 'free_money'];
const ints = [0n, 1n, 2n, 7n, 20n, 60n, 100n, -1n, -2n, MAX, MAX + 1n, 9007199254740993n, 10n ** 19n - 1n, -(10n ** 19n), 123456789n];
const pick = (a) => a[rnd(a.length)];
const kinds = ['Candidate', 'Candidate', 'Candidate', 'Missing', 'TimedOut', 'Failed', 'Malformed', 'Oversized', 'Unsupported'];
const num = (n) => new BigNumber(String(n)), str = (t) => runtime.Seq.UnicodeFromString(t);
let bad = 0;
for (let i = 0; i < 2000; i++) {
  const c = { chargeId: pick(['c', '', 'ch ']), requestId: pick(['r', '']), original: pick(ints), remaining: pick(ints),
    refundEnabled: rnd(4) > 0, requestOpen: rnd(4) > 0 };
  const kind = pick(kinds);
  const r = kind === 'Candidate' ? { kind, amount: pick(ints), reason: pick(reasons) } : { kind };
  const ok = c.chargeId !== '' && c.requestId !== '' && c.refundEnabled && c.requestOpen && c.original >= 0n && c.original <= MAX &&
    c.remaining >= 0n && c.remaining <= c.original && r.kind === 'Candidate' && r.amount >= 0n && r.amount <= c.remaining &&
    reasons.slice(0, 3).includes(r.reason);
  let got;
  try {
    const ctx = R.Context.create_ChargeContext(str(c.chargeId), str(c.requestId), num(c.original), num(c.remaining), c.refundEnabled, c.requestOpen);
    const resp = kind === 'Candidate' ? R.ModelResponse.create_Candidate(num(r.amount), str(r.reason)) : R.ModelResponse['create_' + kind]();
    const [d, p] = R.__default.Assess(ctx, resp);
    got = d.is_Authorized ? 'A:' + d.dtor_amount.toFixed() + ':' + d.dtor_reason.toVerbatimString(false) + ':' + p.length : 'R:' + p.length;
  } catch (e) { got = 'THROW ' + e.message; }
  const want = ok ? 'A:' + r.amount + ':' + r.reason + ':1' : 'R:0';
  if (got !== want) { bad++; if (bad <= 5) console.log('WRONG', JSON.stringify({ c: { ...c, original: String(c.original), remaining: String(c.remaining) }, r: { ...r, amount: String(r.amount) } }), 'got', got, 'want', want); }
}
console.log(jsf, 'cases 2000 wrong', bad);
process.exit(bad ? 1 : 0);
