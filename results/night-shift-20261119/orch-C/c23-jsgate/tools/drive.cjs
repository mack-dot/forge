// Usage: node drive.cjs MODULE.cjs [amount] [reason]. One Assess call on an eligible input (as B's drive.cjs).
// Prints the decision and the wall time; any throw is printed with its class and exit 2.
const m = require(process.argv[2]);
const BigNumber = require('bignumber.js');
const R = m.Refund, S = m.runtime.Seq;
const str = (s) => S.UnicodeFromString(s);
const amt = new BigNumber(process.argv[3] || '5');
const ctx = R.Context.create_ChargeContext(str('ch_1'), str('rq_1'), new BigNumber('1000'), new BigNumber('1000'), true, true);
const resp = R.ModelResponse.create_Candidate(amt, str(process.argv[4] || 'duplicate_charge'));
const t0 = Date.now();
try {
  const out = R.__default.Assess(ctx, resp);
  console.log('decision', out[0].is_Authorized ? 'Authorized' : 'Rejected', 'plan', out[1].length, 'ms', Date.now() - t0);
} catch (e) { console.log('THROW', e && e.constructor && e.constructor.name, String(e && e.message).slice(0, 120), 'ms', Date.now() - t0); process.exit(2); }
