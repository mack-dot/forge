// CONTROL for Slice 2 (part of a broken clearing input). A non-abstract module with an {:axiom} lemma that
// proves `false`. RefundPostIncludedAxiom.dfy uses it. `dafny audit` reports this lemma only when THIS file is
// on its command line.
module AxiomHelper {
  lemma {:axiom} Anything()
    ensures false
}
