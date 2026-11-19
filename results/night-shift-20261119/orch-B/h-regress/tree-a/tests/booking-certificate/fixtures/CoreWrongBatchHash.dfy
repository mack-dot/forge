// NEGATIVE CONTROL for Slice 3. This core decides correctly, but puts the pre-state hash in the token in place of the batch hash.
// A refinement of certificate/BookingCertificateSpec.dfy, like impl/BookingCertificate.dfy.
// The pinned checks MUST reject it. A rejection by the verifier means "could not be proved". It is not
// a proof that this core is unsafe.
include "../../../certificate/BookingCertificateSpec.dfy"

module BookingCertificate refines BookingCertificateSpec {
  method Decide(batch: Batch, preStateHash: string, batchHash: string, requestId: string, p: Proposal)
      returns (verdict: Verdict)
  {
    if Accepts(batch, p) {
      verdict := Issue(Token(preStateHash, preStateHash, requestId, p.x, p.alphaBps, C.Dot(batch.w, p.x), Remaining(batch, p.x)));
    } else {
      verdict := Refuse;
    }
  }
}
