// Slice 3 of the master idea (items F3.1 and F3.2): the checker core for runtime certificates.
// It refines the CANDIDATE specification certificate/BookingCertificateSpec.dfy, so the pinned
// Dafny checks this body against that contract: a token exactly when the certificate check accepts.
// NOT an approved specification. NOT gate evidence. The check is sound, not complete: an optimal
// allocation with a weak certificate is refused.
// The two hash texts are inputs. This core copies them into the token. It computes no hash.
include "../certificate/BookingCertificateSpec.dfy"

module BookingCertificate refines BookingCertificateSpec {
  method Decide(batch: Batch, preStateHash: string, batchHash: string, requestId: string, p: Proposal)
      returns (verdict: Verdict)
  {
    if Accepts(batch, p) {
      verdict := Issue(Token(preStateHash, batchHash, requestId, p.x, p.alphaBps,
                             C.Dot(batch.w, p.x), Remaining(batch, p.x)));
    } else {
      verdict := Refuse;
    }
  }
}
