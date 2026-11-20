// APEX-2 (2026-11-19). The HOL formula against the predicate FlatContract of
// SliceTheorem.dfy (the predicate that the slice theorem and hypothesis A6
// use). For all inputs and outputs:
//     FlatContract(x, o)  <==>  HolFlat.FlatPlain on the character codes.
// A Dafny-MODEL statement. The printing of FlatPlain from HOL is NOT
// machine-checked (README.md). end_to_end=false.

include "../../m1b-mission-20261119/proofs/slice-theorem/inputs/SliceTheorem.dfy"
include "HolLink.dfy"

module HolSlice {
  import S = SliceTheorem
  import HL = HolLink

  lemma FlatContractIffHol(x: S.FlatIn, o: (bool, int, string, string, string, int))
    ensures S.FlatContract(x, o) <==>
      HL.Plain(x.chargeB, x.requestB, x.original, x.remaining, x.enabled, x.requestOpen,
        x.candidate, x.amount, x.reasonB, o.0, o.1, o.2, o.3, o.4, o.5)
  {
    HL.CodesFacts(x.chargeB, x.requestB, x.reasonB, o.2, o.3, o.4);
  }

  // Hypothesis A6 of the slice theorem, restated on the HOL formula.
  ghost predicate A6h_ArtifactMeetsHolFormula(art: S.FlatFn)
  {
    forall x: S.FlatIn ::
      HL.Plain(x.chargeB, x.requestB, x.original, x.remaining, x.enabled, x.requestOpen,
        x.candidate, x.amount, x.reasonB, art(x).0, art(x).1, art(x).2, art(x).3, art(x).4, art(x).5)
  }

  lemma A6hIffA6(art: S.FlatFn)
    ensures A6h_ArtifactMeetsHolFormula(art) <==> S.A6_ArtifactComputesFlatContract(art)
  {
    forall x: S.FlatIn
      ensures S.FlatContract(x, art(x)) <==>
        HL.Plain(x.chargeB, x.requestB, x.original, x.remaining, x.enabled, x.requestOpen,
          x.candidate, x.amount, x.reasonB, art(x).0, art(x).1, art(x).2, art(x).3, art(x).4, art(x).5)
    {
      FlatContractIffHol(x, art(x));
    }
  }

  // The SUPPORTED DOMAIN. A HOL string has 8-bit characters, so the HOL theorem
  // refund_fields_flat_plain speaks of a Dafny FlatIn only when its three
  // strings are byte strings. The link to HOL gives A6 on that domain only.
  predicate ByteInputs(x: S.FlatIn)
  {
    HL.IsBytes(x.chargeB) && HL.IsBytes(x.requestB) && HL.IsBytes(x.reasonB)
  }

  ghost predicate A6hb_ArtifactMeetsHolFormulaOnBytes(art: S.FlatFn)
  {
    forall x: S.FlatIn | ByteInputs(x) ::
      HL.Plain(x.chargeB, x.requestB, x.original, x.remaining, x.enabled, x.requestOpen,
        x.candidate, x.amount, x.reasonB, art(x).0, art(x).1, art(x).2, art(x).3, art(x).4, art(x).5)
  }

  ghost predicate A6b_ArtifactComputesFlatContractOnBytes(art: S.FlatFn)
  {
    forall x: S.FlatIn | ByteInputs(x) :: S.FlatContract(x, art(x))
  }

  lemma A6hbIffA6b(art: S.FlatFn)
    ensures A6hb_ArtifactMeetsHolFormulaOnBytes(art) <==> A6b_ArtifactComputesFlatContractOnBytes(art)
  {
    forall x: S.FlatIn
      ensures S.FlatContract(x, art(x)) <==>
        HL.Plain(x.chargeB, x.requestB, x.original, x.remaining, x.enabled, x.requestOpen,
          x.candidate, x.amount, x.reasonB, art(x).0, art(x).1, art(x).2, art(x).3, art(x).4, art(x).5)
    {
      FlatContractIffHol(x, art(x));
    }
  }
}
