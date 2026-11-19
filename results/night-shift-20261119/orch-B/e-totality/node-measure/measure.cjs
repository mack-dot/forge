// Tiny sizing run (<= 2 s, heap <= 150 MB). Dafny JS uses bignumber.js for int. Attack sizes only.
const BigNumber = require('./bignumber.js');
const t0 = Date.now();
const out = {};
// HV07 shape (REFUSED by the rule): repeated squaring of a 63-bit amount.
const runSquaring = process.argv[2] !== "skip";
let x = new BigNumber('9223372036854775807');
out.squaring = [];
for (let k = 1; runSquaring && k <= 20; k++) {
  const s = Date.now();
  x = x.times(x);
  out.squaring.push([k, x.precision(true), Date.now() - s]); console.error("square", k, x.precision(true), Date.now() - s);
  if (Date.now() - t0 > 1200) { out.squaring_stopped_at = k; break; }
}
// HV22 shape (ADMITTED): 200 multiplications by a 40-digit literal.
let y = new BigNumber('9223372036854775807'); let s = Date.now();
const lit = new BigNumber('1000000000000000000000000000000000000000');
for (let k = 1; k <= 200; k++) y = y.times(lit);
out.hv22 = { digits: y.precision(true), ms: Date.now() - s };
// HV24 shape (ADMITTED): 200 doublings x - (0 - x).
let z = new BigNumber('9223372036854775807'); s = Date.now();
for (let k = 1; k <= 200; k++) z = z.minus(new BigNumber(0).minus(z));
out.hv24 = { digits: z.precision(true), ms: Date.now() - s };
out.total_ms = Date.now() - t0;
out.heap_mb = Math.round(process.memoryUsage().rss / 1048576);
console.log(JSON.stringify(out));
