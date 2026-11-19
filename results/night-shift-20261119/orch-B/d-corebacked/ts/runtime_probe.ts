// d-corebacked: probe of the compiled core's value conversions (strings, integers) and of determinism.
// Single short run. Run: node --import tsx runtime_probe.ts <out.json>
import { writeFileSync } from "node:fs";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const M = require(__dirname + "/../build/shellcore-reqid.cjs");
const rt = M.rt, BN = M.BigNumber;
const out: any = { strings: [], equality: [], ints: [], determinism: null };

const samples: [string, string][] = [
  ["ascii", "rq_1"], ["bmp", "rq_é中"], ["non-BMP pair", "rq_\u{1F600}"], ["pair as escapes", "rq_😀"],
  ["other non-BMP", "rq_\u{1F601}"], ["lone high", "rq_\uD83D"], ["lone low", "rq_\uDE00"], ["reversed pair", "rq_\uDE00\uD83D"],
  ["lone high + x", "rq_\uD83Dx"], ["U+FFFD", "rq_�"], ["empty", ""],
];
const conv: any[] = [];
for (const [name, s] of samples) {
  let r: any;
  try {
    const d = rt.Seq.UnicodeFromString(s);
    const back = d.toVerbatimString(false);
    r = { name, jsUnits: s.length, dafnyLen: d.length, codePoints: Array.from(d as any[]).map((c: any) => c.value.toString(16)), roundTrip: back === s };
    conv.push([name, s, d]);
  } catch (e) { r = { name, threw: String((e as Error).message) }; }
  out.strings.push(r);
}
// Injectivity and equality: Dafny equality must agree with JS string equality on every pair.
for (const [n1, s1, d1] of conv) for (const [n2, s2, d2] of conv) {
  const js = s1 === s2, dy = rt.areEqual(d1, d2);
  if (js !== dy) out.equality.push({ a: n1, b: n2, js, dafny: dy });
}
out.equalityDisagreements = out.equality.length;
// Integers: BigNumber round trip of decimal strings up to 19 digits and beyond 2^63.
for (const v of ["0", "1", "9223372036854775807", "9223372036854775808", "18446744073709551616", "9999999999999999999", "99999999999999999999999999999999"]) {
  const b = new BN(v);
  out.ints.push({ v, toFixed: b.toFixed(), exact: b.toFixed() === v, isInteger: b.isInteger() });
}
// Arbitrary precision inside the core: a value compare that differs only in the last of 32 digits.
const F = M.F, T = (s: string) => rt.Seq.UnicodeFromString(s);
const c1 = F.Charge.create_Charge(T("c"), new BN("99999999999999999999999999999999"), new BN("1"), true);
const c2 = F.Charge.create_Charge(T("c"), new BN("99999999999999999999999999999998"), new BN("1"), true);
out.bigCompareDistinct = !rt.areEqual(c1, c2);
// Determinism: the same StepP call 1,000 times gives the same printed result.
const core = M.C.Core.create_Core(c1, rt.Set.Empty, rt.Seq.of());
const tok = M.Shell.ShellToken.create_ShellToken(new BN(1), new BN(2), T("rq"), c2,
  M.R.RefundIntent.create_Intent(T("c"), T("rq"), new BN(0), T("r")), T(""));
const first = M.Shell.__default.StepP(core, tok, true, true).toString();
let same = 0;
for (let i = 0; i < 1000; i++) if (M.Shell.__default.StepP(core, tok, true, true).toString() === first) same++;
out.determinism = { calls: 1000, sameAsFirst: same, first };
writeFileSync(process.argv[2], JSON.stringify(out, null, 1));
console.log(JSON.stringify(out.strings), "\nequality disagreements:", out.equalityDisagreements, "\nints:", JSON.stringify(out.ints),
  "\nbigCompareDistinct:", out.bigCompareDistinct, "\ndeterminism:", same, "/ 1000");
