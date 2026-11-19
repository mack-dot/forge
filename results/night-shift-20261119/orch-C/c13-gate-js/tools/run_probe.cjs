// c13-gate-js: run the compiled probe predicates (js/<name>.js) and compare with the verifier's verdicts.
// Usage: node run_probe.cjs JSFILE ARGS_JSON VERIFIER_FALSE_LIST(comma). Exit 1 = a verifier/runtime difference.
const fs = require('fs'), path = require('path');
const [jsf, argsf, vfalse] = process.argv.slice(2);
const src = fs.readFileSync('<REPO>/results/night-shift-20261119/orch-B/e-subset3/js/runtime-prefix.js', 'utf8') + fs.readFileSync(jsf, 'utf8') + '\nmodule.exports = { P: (typeof Probe !== "undefined" ? Probe : Probe3), runtime: _dafny, BigNumber };\n';
const m = { exports: {} };
new Function('require', 'module', 'exports', src)(require, m, m.exports);
const { P: Probe, runtime, BigNumber } = m.exports;
const no = new Set((vfalse || '').split(',').filter(Boolean));
let diff = 0;
for (const [n, args] of JSON.parse(fs.readFileSync(argsf, 'utf8'))) {
  const a = args.map(t => t.startsWith('str:') ? runtime.Seq.UnicodeFromString(t.slice(4)) : new BigNumber(t.slice(4)));
  let got; try { got = Probe.__default[n](...a); } catch (e) { got = 'THROW ' + e.message; }
  const want = !no.has(n);
  const ok = got === want;
  if (!ok) diff++;
  console.log(n, 'verifier', want, 'runtime', got, ok ? 'same' : 'DIFFERENT');
}
console.log('differences', diff);
process.exit(diff ? 1 : 0);
