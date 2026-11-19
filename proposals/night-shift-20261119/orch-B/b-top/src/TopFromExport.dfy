// Night shift 2026-11-19, Orchestrator B, task b-top (T1). A DRAFT in an evidence folder. NOT gate evidence.
// M1-B stays OPEN. end_to_end=false. A Dafny-MODEL statement only. It says nothing about sink.ts, minter.ts,
// Ed25519, SHA-256, SQLite, compiled code, the HOL model, CakeML or native execution.
//
// T1: the byte-level slice theorem (SliceSafetyBytesV3, b-ser2, byte-equal copy) with the ARTIFACT hypothesis stated
// on the EXPORT. A6x: for every byte-string flat input x, the artifact output art(x) satisfies ExportedContract, the
// predicate that gen_exported.py generated from the exported contract bytes (export 58154ddf...; byte-equal copy of
// b-export-bridge/gen/ExportedContract.dfy). ExportBridge.ExportedIffFlat (byte-equal copy) gives A6x <==> A6b.
// Type note: SliceTheoremV3.FlatIn is a textual copy of SliceTheorem.FlatIn, but Dafny sees two types. ToExp is the
// field-by-field map; ToExpBijective shows that it is a bijection that keeps ByteInputs. So the quantifier of A6x
// ranges over exactly the byte-string inputs of the export's own input type.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "SliceSafetyBytesV3.dfy"
include "v3/ExportBridge.dfy"
include "ControlsBytesV3.dfy"

module TopFromExport {
  import opened HashCore
  import opened SliceSafetyBytesV3
  import S3 = SliceTheoremV3
  import ST = SliceTheorem
  import EG = ExportedGen
  import EB = ExportBridge
  import L = LinkedRefund

  function ToExp(x: S3.FlatIn): ST.FlatIn
  {
    ST.FlatIn(x.chargeB, x.requestB, x.original, x.remaining, x.enabled, x.requestOpen, x.candidate, x.amount, x.reasonB)
  }
  function FromExp(y: ST.FlatIn): S3.FlatIn
  {
    S3.FlatIn(y.chargeB, y.requestB, y.original, y.remaining, y.enabled, y.requestOpen, y.candidate, y.amount, y.reasonB)
  }
  lemma ToExpBijective(x: S3.FlatIn, y: ST.FlatIn)
    ensures FromExp(ToExp(x)) == x && ToExp(FromExp(y)) == y
    ensures S3.ByteInputs(FromExp(y)) <==>
      (S3.IsByteString(y.chargeB) && S3.IsByteString(y.requestB) && S3.IsByteString(y.reasonB))
  {}

  // A6x (ASSUMPTION, artifact correctness, the HOL-facing form): the artifact meets the EXPORTED contract on every
  // byte-string flat input. orch-A's HOL theorem exported_contract_exact is the intended discharge (NOT checked here).
  ghost predicate A6x_ArtifactMeetsExportedContractOnBytes(art: S3.FlatFn)
  {
    forall x: S3.FlatIn | S3.ByteInputs(x) :: EG.ExportedContract(ToExp(x), art(x))
  }

  lemma FlatContractsAgree(x: S3.FlatIn, o: L.FlatTuple)
    ensures ST.FlatContract(ToExp(x), o) <==> S3.FlatContract(x, o)
  {}

  lemma A6xIffA6bV3(art: S3.FlatFn)
    ensures A6x_ArtifactMeetsExportedContractOnBytes(art) <==> S3.A6b_ArtifactComputesFlatContractOnBytes(art)
  {
    forall x: S3.FlatIn
      ensures EG.ExportedContract(ToExp(x), art(x)) <==> S3.FlatContract(x, art(x))
    {
      EB.ExportedIffFlat(ToExp(x), art(x));
      FlatContractsAgree(x, art(x));
    }
  }

  // THE T1 LEMMA: SliceSafetyBytesV3 with A6x in place of A6b. Same conclusion, same other hypotheses.
  lemma SliceSafetyBytesFromExport(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier, art: S3.FlatFn)
    requires InitOk(init)
    requires A2p_MintsAreIssued(H, acts)
    requires H1B_ByteUnforgeability(vb, acts)
    requires B5_VerifierBoolean(vb, acts)
    requires A4_HashBindsInRun(H, init, acts)
    requires A6x_ArtifactMeetsExportedContractOnBytes(art)
    ensures var r := TExec(H, init, acts);
      Shape(r) &&
      (forall e | e in r.core.outbox :: exists i :: FullEntry(H, init, acts, art, r, i, e)) &&
      GoodV3(r.core) &&
      0 <= r.core.charge.remaining <= r.core.charge.original && r.core.charge.original == init.original &&
      SumIntents(r.core.outbox) == init.remaining - r.core.charge.remaining
  {
    A6xIffA6bV3(art);
    SliceSafetyBytesV3.SliceSafetyBytesV3(H, init, acts, vb, art);
  }
}

// Controls for T1. Imports the b-ser2 witness (ControlsBytesV3, byte-equal copy).

module TopFromExportControls {
  import opened HashCore
  import opened SliceSafetyBytesV3
  import opened TopFromExport
  import S3 = SliceTheoremV3
  import L = LinkedRefund
  import C = ControlsBytesV3
  import U = RefundUnicode

  // Non-vacuity (a): the proved specification function meets A6x.
  lemma FlatSpecFnMeetsA6x()
    ensures A6x_ArtifactMeetsExportedContractOnBytes(S3.FlatSpecFn)
  {
    S3.FlatSpecFnMeetsA6b();
    A6xIffA6bV3(S3.FlatSpecFn);
  }

  // Control (c): reject-all fails A6x. The byte-string input of the witness intent I1 (amount 40 <= 60) must be
  // accepted by the exported contract; reject-all answers false.
  function RejectAll(x: S3.FlatIn): L.FlatTuple { (false, 0, "", "", "", 0) }

  lemma RejectAllFailsA6x()
    ensures !A6x_ArtifactMeetsExportedContractOnBytes(RejectAll)
  {
    var x := S3.FlatInputsOf(C.W_PRE, C.I1);
    S3.FlatInputsAreBytes(C.W_PRE, C.I1);
    assert !S3.FlatContract(x, RejectAll(x)) by {
      U.EncodedEmpty("ch_1");
      U.EncodedEmpty("rq_1");
      U.SameReasons("duplicate_charge");
    }
    A6xIffA6bV3(RejectAll);
  }

  // Non-vacuity (b): on the b-ser2 witness run (a zero-amount commit, a replay, a positive commit, a forged tag, a
  // foreign charge) every hypothesis of SliceSafetyBytesFromExport holds with A6x and the conclusion covers both
  // committed effects.
  lemma WitnessFromExport()
    ensures InitOk(C.W_PRE) && A2p_MintsAreIssued(C.HW, C.WActs()) && H1B_ByteUnforgeability(C.TotalVB, C.WActs())
    ensures B5_VerifierBoolean(C.TotalVB, C.WActs()) && A4_HashBindsInRun(C.HW, C.W_PRE, C.WActs())
    ensures A6x_ArtifactMeetsExportedContractOnBytes(S3.FlatSpecFn)
    ensures TExec(C.HW, C.W_PRE, C.WActs()).core.outbox == [C.I0, C.I1] && C.I0.amount == 0 && C.I1.amount == 40
    ensures var r := TExec(C.HW, C.W_PRE, C.WActs());
      forall e | e in r.core.outbox :: exists i :: FullEntry(C.HW, C.W_PRE, C.WActs(), S3.FlatSpecFn, r, i, e)
  {
    C.Witness();
    FlatSpecFnMeetsA6x();
    SliceSafetyBytesFromExport(C.HW, C.W_PRE, C.WActs(), C.TotalVB, S3.FlatSpecFn);
  }
}
