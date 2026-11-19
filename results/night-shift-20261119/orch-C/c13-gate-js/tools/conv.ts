// c13-gate-js: the gate harness's input conversion path (copy of gate/refund/hostile.ts model(), 4af09308).
// Usage (cwd = repo root, as the gate): node --import tsx conv.ts MODULE.cjs. Exit 1 = the real path is imprecise.
import { resolve } from "node:path";
import BigNumber from "bignumber.js";
const modulePath = process.argv[2];
const { Refund: R, runtime } = require(resolve(modulePath));
const number = (n: bigint) => new BigNumber(String(n));
const string = (s: string) => runtime.Seq.UnicodeFromString(s);
const integer = (n: any): bigint => BigInt(n.toFixed());
let bad = 0;
const same = BigNumber === require("bignumber.js");
console.log("harness BigNumber is the model's CommonJS class:", same, "; mod(-3,2) with harness class:", new BigNumber(-3).mod(2).toFixed());
if (!same || new BigNumber(-3).mod(2).toFixed() !== "1") bad++;
const MAX = 9223372036854775807n;
for (const x of [0n, 9007199254740993n, 9007199254740995n, 10n ** 19n - 1n, MAX, MAX - 1n, 2n ** 53n + 1n, 18014398509481985n]) {
  const xs = x > MAX ? MAX : x;
  const c = R.Context.create_ChargeContext(string("c"), string("r"), number(xs), number(xs), true, true);
  const r = R.ModelResponse.create_Candidate(number(xs), string("duplicate_charge"));
  const [d, p] = R.__default.Assess(c, r);
  const back = d.is_Authorized ? integer(d.dtor_amount) : null;
  const ok = back === xs && p.length === 1 && integer(p[0].dtor_amount) === xs;
  if (!ok) bad++;
  console.log("amount", String(xs), "authorized", d.is_Authorized, "returned", String(back), ok ? "exact" : "INEXACT");
}
for (const x of [MAX + 1n, 10n ** 40n, -1n, -(10n ** 19n)]) {
  const c = R.Context.create_ChargeContext(string("c"), string("r"), number(x), number(x), true, true);
  const [d] = R.__default.Assess(c, R.ModelResponse.create_Candidate(number(0n), string("duplicate_charge")));
  const want = x >= 0n && x <= MAX;
  if (d.is_Authorized !== want) bad++;
  console.log("context original=remaining", String(x), "authorized", d.is_Authorized, "expected", want);
}
for (const s of ["\uD800", "a\uDC00", "😀"]) {
  let out: string;
  try { const v = string(s); out = "length " + v.length + " first code point " + (v.length ? v[0].value.toString(16) : "-"); }
  catch (e: any) { out = "THROWS " + e.constructor.name + ": " + e.message; }
  console.log("UnicodeFromString", JSON.stringify(s), "->", out);
}
console.log("defects", bad);
process.exit(bad ? 1 : 0);
