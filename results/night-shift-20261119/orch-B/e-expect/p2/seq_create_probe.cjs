// Standalone replica of the Dafny 4.11 JS runtime lines 498-507 (Seq extends Array; Create = Seq.from({length: n})).
// It does NOT load the submission. n is a plain number here (BigNumber.valueOf gives the same ToLength result).
class Seq extends Array { constructor(...elems) { super(...elems); } }
for (const n of [3, 2 ** 32, 1e12]) {
  try { const s = Seq.from({ length: n }, (_, i) => 0); console.log(n, 'ok length', s.length); }
  catch (e) { console.log(n, 'THROWS', e.constructor.name, e.message); }
}
