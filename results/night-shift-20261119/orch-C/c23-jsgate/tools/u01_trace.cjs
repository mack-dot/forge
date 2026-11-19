// Replays the U01 loop with the runtime's BigNumber config (EUCLID) and logs the value per round.
const m = require(process.argv[2]); const BigNumber = require('bignumber.js');
let x = new BigNumber(process.argv[3] || '1000000000000000000'); const ONE = new BigNumber(1), NEG = new BigNumber(0).minus(ONE);
for (let r = 0; r < 40; r++) { const t = Date.now(); const d = x.multipliedBy(x).plus(ONE); x = NEG.mod(d);
  console.log(r, 'divisor e', d.e, 'result', x.toString().slice(0, 30), 'e', x.e, 'ms', Date.now() - t); }
