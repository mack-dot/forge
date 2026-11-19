// NEGATIVE CONTROL for Slice 3. This core does not check the capacity of the slots (overbooking).
// A refinement of certificate/BookingCertificateSpec.dfy, like impl/BookingCertificate.dfy.
// The pinned checks MUST reject it. A rejection by the verifier means "could not be proved". It is not
// a proof that this core is unsafe.
include "../../../certificate/BookingCertificateSpec.dfy"

module BookingCertificate refines BookingCertificateSpec {
  // The check of this core, written out. One part of the specified check is missing.
  predicate Check(batch: Batch, p: Proposal) {
    0 <= p.alphaBps <= 10000 &&
    C.Shape(batch.A, batch.c, |batch.w|) && |p.x| == |batch.w| && |p.y| == |batch.A| && |p.z| == |batch.w| &&
    C.Binary(p.x) &&
    C.NonNeg(p.y) &&
    C.NonNeg(p.z) &&
    (forall j | 0 <= j < |batch.w| :: batch.w[j] <= C.ColDotFrom(batch.A, p.y, j, 0) + p.z[j]) &&
    (10000 - p.alphaBps) * (C.Dot(p.y, batch.c) + C.Sum(p.z)) <= 10000 * C.Dot(batch.w, p.x)
  }

  method Decide(batch: Batch, preStateHash: string, batchHash: string, requestId: string, p: Proposal)
      returns (verdict: Verdict)
  {
    if Check(batch, p) && |p.x| == |batch.w| && C.Shape(batch.A, batch.c, |p.x|) {
      verdict := Issue(Token(preStateHash, batchHash, requestId, p.x, p.alphaBps, C.Dot(batch.w, p.x), Remaining(batch, p.x)));
    } else {
      verdict := Refuse;
    }
  }
}
