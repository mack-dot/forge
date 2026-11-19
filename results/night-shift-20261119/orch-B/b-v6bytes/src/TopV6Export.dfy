// Night shift 2026-11-19, Orchestrator B, task b-v6bytes (G2, the export and minter bridges). A DRAFT. NOT gate evidence.
// M1-B stays OPEN. end_to_end=false. A Dafny-MODEL statement only.
// SliceSafetyBytesV6Top with the hypotheses stated on the d-minter method and on the EXPORT, by the bridges of b-top
// (byte-equal copies): IssuerLink.A2qImpliesA2p (A2q ==> A2p) and TopFromExport.A6xIffA6bV3 (A6x <==> A6b).
// L3X: the artifact agreement needs ONLY A6x (on top of the hypothesis-free L0). NO A4 anywhere.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "SliceSafetyBytesV6.dfy"
include "IssuerLink.dfy"

module TopV6Export {
  import opened HashCore
  import opened HashCore6
  import opened SliceSafetyBytesV3
  import opened SliceSafetyBytesV6
  import TE = TopFromExport
  import IL = IssuerLink
  import S3 = SliceTheoremV3

  lemma SliceSafetyBytesV6_L3X(H: HashFn, init: F.Charge, acts: seq<Act>, art: S3.FlatFn)
    requires TE.A6x_ArtifactMeetsExportedContractOnBytes(art)
    ensures var r := TExec6(H, init, acts);
      forall i | 0 <= i < |r.toks| :: FlatResultAgrees(art, r, i)
  {
    TE.A6xIffA6bV3(art);
    SliceSafetyBytesV6_L3(H, init, acts, art);
  }

  lemma SliceSafetyBytesV6_L2Q(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier)
    requires IL.A2q_MintsAreIssueTokenBytesOutputs(H, acts)
    requires H1B_ByteUnforgeability(vb, acts)
    requires B5_VerifierBoolean(vb, acts)
    ensures var r := TExec6(H, init, acts);
      forall i | 0 <= i < |r.toks| :: IssuedAtStored(H, acts, r, i)
  {
    IL.A2qImpliesA2p(H, acts);
    SliceSafetyBytesV6_L2(H, init, acts, vb);
  }

  lemma SliceSafetyBytesV6TopX(H: HashFn, init: F.Charge, acts: seq<Act>, vb: ByteVerifier, art: S3.FlatFn)
    requires InitOk(init)
    requires IL.A2q_MintsAreIssueTokenBytesOutputs(H, acts)
    requires H1B_ByteUnforgeability(vb, acts)
    requires B5_VerifierBoolean(vb, acts)
    requires TE.A6x_ArtifactMeetsExportedContractOnBytes(art)
    ensures var r := TExec6(H, init, acts);
      Shape(r) &&
      (forall e | e in r.core.outbox :: exists i :: FullEntry6(H, init, acts, art, r, i, e)) &&
      GoodV3(r.core) && r.core.charge.chargeId == init.chargeId &&
      0 <= r.core.charge.remaining <= r.core.charge.original && r.core.charge.original == init.original &&
      SumIntents(r.core.outbox) == init.remaining - r.core.charge.remaining
  {
    IL.A2qImpliesA2p(H, acts);
    TE.A6xIffA6bV3(art);
    SliceSafetyBytesV6Top(H, init, acts, vb, art);
  }
}
