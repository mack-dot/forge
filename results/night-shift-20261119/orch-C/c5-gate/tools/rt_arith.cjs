// Loads the Dafny 4.11 JS runtime prefix (orch-B copy) and checks Euclidean / and % against the Dafny definition.
const fs = require('fs');
const src = fs.readFileSync('<REPO>/results/night-shift-20261119/orch-B/e-subset3/js/runtime-prefix.js', 'utf8');
const m = { exports: {} };
new Function('require', 'module', 'exports', src + '\nmodule.exports = { _dafny, BigNumber };')(require, m, m.exports);
const { _dafny, BigNumber } = m.exports;
const vals = ['0','1','-1','2','-2','7','-7','8','-8','9223372036854775807','-9223372036854775808','9999999999999999999','-9999999999999999999','123456789012345678901234567890','-123456789012345678901234567890'];
let bad = 0, n = 0;
for (const a of vals) for (const b of vals) {
  if (b === '0') continue;
  const A = BigInt(a), B = BigInt(b);
  let r = A % B; if (r < 0n) r += (B < 0n ? -B : B);
  const q = (A - r) / B;
  const jq = _dafny.EuclideanDivision(new BigNumber(a), new BigNumber(b)).toFixed();
  const jr = new BigNumber(a).mod(new BigNumber(b)).toFixed();
  n++;
  if (jq !== q.toString() || jr !== r.toString()) { bad++; console.log('MISMATCH', a, b, jq, q.toString(), jr, r.toString()); }
}
const s = _dafny.Seq.UnicodeFromString('\u{1F600}a');
console.log('pairs', n, 'mismatches', bad, 'astral length', s.length);
process.exit(bad ? 1 : 0);
