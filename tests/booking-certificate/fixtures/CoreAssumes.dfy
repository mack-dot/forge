// NEGATIVE CONTROL for Slice 3. This core issues a token for every proposal and "proves" the contract with an assumption.
// A refinement of certificate/BookingCertificateSpec.dfy, like impl/BookingCertificate.dfy.
// The pinned checks MUST reject it. A rejection by the verifier means "could not be proved". It is not
// a proof that this core is unsafe.
include "../../../certificate/BookingCertificateSpec.dfy"

module BookingCertificate refines BookingCertificateSpec {
  method Decide(batch: Batch, preStateHash: string, batchHash: string, requestId: string, p: Proposal)
      returns (verdict: Verdict)
  {
    assume {:axiom} Accepts(batch, p);
    verdict := Issue(Token(preStateHash, batchHash, requestId, p.x, p.alphaBps, C.Dot(batch.w, p.x), Remaining(batch, p.x)));
  }
}
