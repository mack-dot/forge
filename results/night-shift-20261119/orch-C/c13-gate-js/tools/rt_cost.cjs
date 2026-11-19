// c13-gate-js: cost of the admitted arithmetic shapes with the pinned Dafny runtime (no Dafny run).
// Emulates compiled code: k products by a 19-digit literal (2 tokens each), then m terms `x % L +` (4 tokens each).
const fs = require('fs');
const src = fs.readFileSync('<REPO>/results/night-shift-20261119/orch-B/e-subset3/js/runtime-prefix.js', 'utf8');
const m = { exports: {} };
new Function('require', 'module', 'exports', src + '\nmodule.exports = { _dafny, BigNumber };')(require, m, m.exports);
const { _dafny, BigNumber } = m.exports;
const L = new BigNumber('9999999999999999999'), L2 = new BigNumber('9999999999999999997');
let worst = 0;
for (const k of [500, 1000, 1300, 1600, 1950]) {
  const mm = Math.floor((4000 - 2 * k) / 4);
  const t0 = process.hrtime.bigint();
  let x = new BigNumber('9223372036854775807');
  for (let i = 0; i < k; i++) x = x.multipliedBy(L);
  const t1 = process.hrtime.bigint();
  let acc = _dafny.ZERO;
  for (let i = 0; i < mm; i++) acc = acc.plus(x.mod(L2));
  const t2 = process.hrtime.bigint();
  const ms = Number(t2 - t0) / 1e6; worst = Math.max(worst, ms);
  console.log('k', k, 'm', mm, 'tokens', 2 * k + 4 * mm, 'digits', x.toFixed().length, 'mul ms', (Number(t1 - t0) / 1e6).toFixed(1), 'mod ms', (Number(t2 - t1) / 1e6).toFixed(1), 'total ms', ms.toFixed(1), 'heapMB', (process.memoryUsage().heapUsed / 1e6).toFixed(0));
}
console.log('worst ms', worst.toFixed(1));
process.exit(worst > 2000 ? 1 : 0);
