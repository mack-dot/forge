// Usage: node drive.cjs MODULE.cjs [amount]. One Assess call on a fixed eligible-shaped input.
const m = require(process.argv[2]);
const BigNumber = require('bignumber.js');
const R = m.Refund, S = m.runtime.Seq;
const str = (s) => S.UnicodeFromString(s);
const amt = new BigNumber(process.argv[3] || '5');
const ctx = R.Context.create_ChargeContext(str('c'.repeat(Number(process.argv[4] || 2))), str('rq'), new BigNumber('9223372036854775807'), new BigNumber('9223372036854775807'), true, true);
const resp = R.ModelResponse.create_Candidate(amt, str('duplicate_charge'));
const t0 = Date.now();
const out = R.__default.Assess(ctx, resp);
console.log('decision', out[0].is_Authorized ? 'Authorized' : 'Rejected', 'ms', Date.now() - t0);
