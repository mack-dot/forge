// Times ONE equality of the two sets that U02 builds (same runtime module), to extrapolate the 4000 equalities.
const m = require(process.argv[2]); const BigNumber = require('bignumber.js'); const S = m.runtime.Set;
let s = S.fromElements(new BigNumber(0)); for (let i = 1; i < 1800; i++) s = s.Union(S.fromElements(new BigNumber(i)));
const c = s.Union(S.fromElements(new BigNumber(0)));
const t = process.hrtime.bigint(); let k = 0; for (let j = 0; j < 20; j++) if (s.equals(c)) k++;
const per = Number(process.hrtime.bigint() - t) / 20 / 1e6;
console.log('one equality ms', per.toFixed(1), 'x4000 =', (per * 4000 / 1000).toFixed(0), 's; equal', k);
