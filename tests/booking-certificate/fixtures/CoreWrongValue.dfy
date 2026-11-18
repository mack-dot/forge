// NEGATIVE CONTROL for Slice 3. This core decides correctly, but the value in the token is not the value of the allocation.
// A refinement of certificate/BookingCertificateSpec.dfy, like impl/BookingCertificate.dfy.
// The pinned checks MUST reject it. A rejection by the verifier means "could not be proved". It is not
// a proof that this core is unsafe.
include "../../../certificate/BookingCertificateSpec.dfy"

module BookingCertificate refines BookingCertificateSpec {
  method Decide(batch: Batch, preStateHash: string, batchHash: string, requestId: string, p: Proposal)
      returns (verdict: Verdict)
  {
    if Accepts(batch, p) {
      verdict := Issue(Token(preStateHash, batchHash, requestId, p.x, p.alphaBps, C.Dot(p.y, batch.c) + C.Sum(p.z), Remaining(batch, p.x)));
    } else {
      verdict := Refuse;
    }
  }
}
