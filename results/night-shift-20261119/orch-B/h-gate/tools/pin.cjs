// Prints the SHA-256 pins: runtime prefix (lines 1-1188 of the gate build) and the four spec datatype class texts.
const ts = require('/Users/mackianni/forge/node_modules/typescript'); const fs = require('fs'); const c = require('crypto');
const h = (s) => c.createHash('sha256').update(s).digest('hex');
const all = fs.readFileSync(process.argv[2], 'utf8'); const i = all.indexOf('let Refund = (function()');
console.log('prefix', i, h(all.slice(0, i)));
const sf = ts.createSourceFile('m.js', all.slice(i), ts.ScriptTarget.ES2022, true, ts.ScriptKind.JS);
const body = sf.statements[0].declarationList.declarations[0].initializer.expression.expression.body.statements;
for (const st of body) { const t = st.getText(sf); const m = /^\$module\.(\w+) = class/.exec(t); if (m) console.log(m[1], h(t)); }
