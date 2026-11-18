// NEGATIVE CONTROL for Slice 3. This core has no check of its own: a run-time halt statement stands in place of the proof (the compiled program halts for a proposal that is not accepted; the verifier takes the condition as given).
// A refinement of certificate/BookingCertificateSpec.dfy, like impl/BookingCertificate.dfy.
// The pinned checks MUST reject it. A rejection by the verifier means "could not be proved". It is not
// a proof that this core is unsafe.
include "../../../certificate/BookingCertificateSpec.dfy"

module BookingCertificate refines BookingCertificateSpec {
  method Decide(batch: Batch, preStateHash: string, batchHash: string, requestId: string, p: Proposal)
      returns (verdict: Verdict)
  {
    expect Accepts(batch, p);
    verdict := Issue(Token(preStateHash, batchHash, requestId, p.x, p.alphaBps, C.Dot(batch.w, p.x), Remaining(batch, p.x)));
  }
}
