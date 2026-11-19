// Cost of the largest literal-multiplier chain rule 3 admits (C29: 1900 x `* 9999999999999999999`, W=4031),
// executed with the Dafny 4.11 runtime BigNumber (same calls as the compiled code: multipliedBy, then a comparison).
const fs = require('fs');
const src = fs.readFileSync('<REPO>/results/night-shift-20261119/orch-B/e-subset3/js/runtime-prefix.js', 'utf8');
const m = { exports: {} };
new Function('require', 'module', 'exports', src + '\nmodule.exports = { _dafny, BigNumber };')(require, m, m.exports);
const { BigNumber } = m.exports;
const t0 = process.hrtime.bigint();
let x = new BigNumber(4096);
for (let i = 0; i < 1900; i++) x = x.multipliedBy(new BigNumber('9999999999999999999'));
const t1 = process.hrtime.bigint();
const cmp = x.isLessThanOrEqualTo(new BigNumber('9223372036854775807'));
const t2 = process.hrtime.bigint();
console.log('digits', x.toFixed().length, 'chain ms', Number(t1 - t0) / 1e6, 'compare ms', Number(t2 - t1) / 1e6, 'cmp', cmp, 'heapMB', Math.round(process.memoryUsage().heapUsed / 1e6));
