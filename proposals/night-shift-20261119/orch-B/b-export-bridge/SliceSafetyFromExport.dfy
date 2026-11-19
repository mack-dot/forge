// Night shift 2026-11-19, Orchestrator B, task b-export-bridge. A DRAFT. NOT gate evidence. Dafny model only.
// G2 corollary. A6x: for every byte-string flat input x, ExportedContract(x, art(x)), where ExportedContract is the
// Dafny reading (fixed operator table, gen_exported.py) of the 3 exported ensures clauses (export 58154ddf...dd0d).
// A6x is the Dafny-side twin of what orch-A's HOL theorem exported_contract_exact says about refund_fields.
// A6x <==> A6b, so SliceSafetyV2OnByteStrings (b-signing, byte-equal copy) holds from A6x.
// No assume, no axiom, no bodiless lemma in this file.
include "SliceSafetyV2OnBytes.dfy"
include "ExportBridge.dfy"

module SliceFromExport {
  import opened SinkCore
  import opened SliceTheorem
  import opened SliceTheoremV2
  import opened SliceTheoremV2B
  import opened ExportedGen
  import EB = ExportBridge

  ghost predicate A6x_ArtifactMeetsExportedContractOnBytes(art: FlatFn)
  {
    forall x: FlatIn | ByteInputs(x) :: ExportedContract(x, art(x))
  }

  lemma A6xIffA6b(art: FlatFn)
    ensures A6x_ArtifactMeetsExportedContractOnBytes(art) <==> A6b_ArtifactComputesFlatContractOnBytes(art)
  {
    forall x: FlatIn
      ensures ExportedContract(x, art(x)) <==> FlatContract(x, art(x))
    {
      EB.ExportedIffFlat(x, art(x));
    }
  }

  // THE COMPOSED LEMMA: SliceSafetyV2OnByteStrings with A6x in place of A6b.
  lemma SliceSafetyFromExport(init: State, acts: seq<Act>, art: FlatFn)
    requires InitOk(init)
    requires A2_MintOnlyOnCheck(acts)
    requires A5_VerifierMatchesAtEachDelivery(acts)
    requires H1_SignatureAuthenticity(acts)
    requires A6x_ArtifactMeetsExportedContractOnBytes(art)
    ensures forall e | CommittedEffect(init, acts, e) ::
      exists i :: (0 <= i < |Exec(init, acts).core.outbox| && Exec(init, acts).core.outbox[i] == e &&
        ApprovedSpec(init, acts, i) && FlatResultAgrees(art, init, acts, i) && UniqueAuthorizationV2(init, acts, i))
    ensures 0 <= Exec(init, acts).core.charge.remaining <= Exec(init, acts).core.charge.original == init.original
    ensures SumIntents(Exec(init, acts).core.outbox) == init.remaining - Exec(init, acts).core.charge.remaining
  {
    A6xIffA6b(art);
    SliceSafetyV2OnByteStrings(init, acts, art);
  }
}

module SliceFromExportWitness {
  import opened SinkCore
  import opened SliceTheorem
  import opened SliceTheoremV2
  import opened SliceTheoremV2B
  import opened SliceWitnessV2
  import opened SliceFromExport
  import opened ExportedGen
  import SW = SliceWitness

  // Non-vacuity (a): the specification function meets A6x.
  lemma FlatSpecFnMeetsA6x()
    ensures A6x_ArtifactMeetsExportedContractOnBytes(FlatSpecFn)
  {
    FlatSpecFnMeetsA6();
    A6ImpliesA6b(FlatSpecFn);
    A6xIffA6b(FlatSpecFn);
  }

  // Control (c): reject-all does NOT meet A6x (it fails on the byte-string witness input of SliceWitness).
  lemma RejectAllFailsA6x()
    ensures !A6x_ArtifactMeetsExportedContractOnBytes(SW.RejectAll)
  {
    var x := FlatInputsOf(SW.W_PRE, SW.W_INTENT);
    FlatInputsAreBytes(SW.W_PRE, SW.W_INTENT);
    assert !FlatContract(x, SW.RejectAll(x)) by {
      U.EncodedEmpty("ch_1");
      U.EncodedEmpty("rq_1");
      U.SameReasons("duplicate_charge");
    }
    EB.ExportedIffFlat(x, SW.RejectAll(x));
  }

  // Non-vacuity (b): on the main witness run (a zero-amount effect, then a positive one, a forged and a replayed
  // delivery) the composed lemma applies under A6x and covers the committed positive-amount effect.
  lemma FromExportCoversMainRun()
    requires SigReading()
    ensures exists i :: (0 <= i < |Exec(SW.W_PRE, MainActs()).core.outbox| &&
      Exec(SW.W_PRE, MainActs()).core.outbox[i] == SW.W_INTENT &&
      FlatResultAgrees(FlatSpecFn, SW.W_PRE, MainActs(), i))
    ensures exists i :: (0 <= i < |Exec(SW.W_PRE, MainActs()).core.outbox| &&
      Exec(SW.W_PRE, MainActs()).core.outbox[i] == SW.W0_INTENT && SW.W0_INTENT.amount == 0 &&
      FlatResultAgrees(FlatSpecFn, SW.W_PRE, MainActs(), i))
  {
    FlatSpecFnMeetsA6x();
    MainHyps();
    MainTrace();
    SliceSafetyFromExport(SW.W_PRE, MainActs(), FlatSpecFn);
    assert CommittedEffect(SW.W_PRE, MainActs(), SW.W_INTENT);
    assert CommittedEffect(SW.W_PRE, MainActs(), SW.W0_INTENT);
  }
}
