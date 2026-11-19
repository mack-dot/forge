// Night shift 2026-11-19, Orchestrator B, task b-signing (orchestrator addition). A DRAFT. NOT gate evidence.
// Dafny model only. Weakens A6 to A6b: the flat contract is needed only for inputs whose three strings are byte
// strings (every char < 256), which is what the HOL side can give. SliceSafetyV2OnByteStrings is SliceSafetyV2
// with A6b in place of A6. No assume, no axiom, no bodiless lemma in this file.
include "SliceSafetyV2.dfy"

module SliceTheoremV2B {
  import opened SinkCore
  import opened SliceTheorem
  import opened SliceTheoremV2

  // =============================================================================================
  // A6b (orchestrator addition): the flat contract only on BYTE-STRING inputs (every char < 256), which is what
  // the HOL side can give. Integers stay unbounded; amount 0 stays allowed.
  predicate IsByteString(s: string)
  {
    forall i | 0 <= i < |s| :: 0 <= s[i] as int < 256
  }

  predicate ByteInputs(x: FlatIn)
  {
    IsByteString(x.chargeB) && IsByteString(x.requestB) && IsByteString(x.reasonB)
  }

  ghost predicate A6b_ArtifactComputesFlatContractOnBytes(art: FlatFn)
  {
    forall x: FlatIn | ByteInputs(x) :: FlatContract(x, art(x))
  }

  lemma A6ImpliesA6b(art: FlatFn)
    requires A6_ArtifactComputesFlatContract(art)
    ensures A6b_ArtifactComputesFlatContractOnBytes(art)
  {
  }

  // The sink's flat inputs are always byte strings (U.EncodedIsBytes, proved in UnicodeRelation.dfy).
  lemma FlatInputsAreBytes(pre: F.Charge, e: R.RefundIntent)
    ensures ByteInputs(FlatInputsOf(pre, e))
  {
    U.EncodedIsBytes(pre.chargeId);
    U.EncodedIsBytes(e.requestId);
    U.EncodedIsBytes(e.reason);
  }

  // An artifact that agrees with `art` on byte inputs and with the specification function elsewhere.
  function PatchWide(art: FlatFn): FlatFn
  {
    (x: FlatIn) => if ByteInputs(x) then art(x) else FlatSpecFn(x)
  }

  lemma PatchWideMeetsA6(art: FlatFn)
    requires A6b_ArtifactComputesFlatContractOnBytes(art)
    ensures A6_ArtifactComputesFlatContract(PatchWide(art))
  {
    FlatSpecFnMeetsA6();
    forall x: FlatIn
      ensures FlatContract(x, PatchWide(art)(x))
    {
      if ByteInputs(x) {
        assert PatchWide(art)(x) == art(x);
      } else {
        assert PatchWide(art)(x) == FlatSpecFn(x);
      }
    }
  }

  // THE COMPOSED THEOREM V2 with A6b in place of A6.
  lemma SliceSafetyV2OnByteStrings(init: State, acts: seq<Act>, art: FlatFn)
    requires InitOk(init)
    requires A2_MintOnlyOnCheck(acts)
    requires A5_VerifierMatchesAtEachDelivery(acts)
    requires H1_SignatureAuthenticity(acts)
    requires A6b_ArtifactComputesFlatContractOnBytes(art)
    ensures forall e | CommittedEffect(init, acts, e) ::
      exists i :: (0 <= i < |Exec(init, acts).core.outbox| && Exec(init, acts).core.outbox[i] == e &&
        ApprovedSpec(init, acts, i) && FlatResultAgrees(art, init, acts, i) && UniqueAuthorizationV2(init, acts, i))
    ensures 0 <= Exec(init, acts).core.charge.remaining <= Exec(init, acts).core.charge.original == init.original
    ensures SumIntents(Exec(init, acts).core.outbox) == init.remaining - Exec(init, acts).core.charge.remaining
  {
    var art' := PatchWide(art);
    PatchWideMeetsA6(art);
    SliceSafetyV2(init, acts, art');
    var r := Exec(init, acts);
    forall e | CommittedEffect(init, acts, e)
      ensures exists i :: (0 <= i < |r.core.outbox| && r.core.outbox[i] == e &&
        ApprovedSpec(init, acts, i) && FlatResultAgrees(art, init, acts, i) && UniqueAuthorizationV2(init, acts, i))
    {
      var i :| 0 <= i < |r.core.outbox| && r.core.outbox[i] == e &&
        ApprovedSpec(init, acts, i) && FlatResultAgrees(art', init, acts, i) && UniqueAuthorizationV2(init, acts, i);
      FlatInputsAreBytes(r.toks[i].pre, e);
      assert art'(FlatInputsOf(r.toks[i].pre, e)) == art(FlatInputsOf(r.toks[i].pre, e));
    }
  }
}

module SliceWitnessV2B {
  import opened SinkCore
  import opened SliceTheorem
  import opened SliceTheoremV2
  import opened SliceTheoremV2B
  import opened SliceWitnessV2
  import SW = SliceWitness

  // ---- A6b control: an artifact that meets A6b but NOT A6 (it fails only on a char >= 256) ----
  const WIDE: string := [256 as char]
  const X_WIDE: FlatIn := FlatIn(WIDE, "r", 100, 60, true, true, true, 1, "duplicate_charge")

  function WideBroken(x: FlatIn): L.FlatTuple
  {
    if ByteInputs(x) then FlatSpecFn(x) else (false, 0, "", "", "", 0)
  }

  lemma WideBrokenMeetsA6bNotA6()
    ensures A6b_ArtifactComputesFlatContractOnBytes(WideBroken)
    ensures !ByteInputs(X_WIDE)
    ensures !FlatContract(X_WIDE, WideBroken(X_WIDE))
    ensures !A6_ArtifactComputesFlatContract(WideBroken)
  {
    FlatSpecFnMeetsA6();
    forall x: FlatIn | ByteInputs(x)
      ensures FlatContract(x, WideBroken(x))
    {
      assert WideBroken(x) == FlatSpecFn(x);
    }
    assert X_WIDE.chargeB[0] as int == 256;
    assert !IsByteString(X_WIDE.chargeB);
  }

  // SliceSafetyV2OnByteStrings applies to WideBroken on the main witness run: its flat result agrees for the
  // committed positive-amount effect.
  lemma WideBrokenStillCovered()
    requires SigReading()
    ensures !A6_ArtifactComputesFlatContract(WideBroken)
    ensures exists i :: (0 <= i < |Exec(SW.W_PRE, MainActs()).core.outbox| &&
      Exec(SW.W_PRE, MainActs()).core.outbox[i] == SW.W_INTENT && FlatResultAgrees(WideBroken, SW.W_PRE, MainActs(), i))
  {
    WideBrokenMeetsA6bNotA6();
    MainHyps();
    MainTrace();
    SliceSafetyV2OnByteStrings(SW.W_PRE, MainActs(), WideBroken);
    assert CommittedEffect(SW.W_PRE, MainActs(), SW.W_INTENT);
  }
}
