// Slice 3 (master idea items F3.1 and F3.2): CANDIDATE specification of the certificate checker.
// NOT an approved specification. NOT under spec/. NOT gate evidence.
//
// The problem is the one of Rounds 2 and 3 (proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy):
// maximise Dot(w, x) subject to A x <= c, x in {0,1}^n, over mathematical integers. Row i is a slot with
// capacity c[i]. Column j is a request: it needs A[i][j] units of slot i and has the value w[j].
// It is NOT the approved booking specification (spec/booking/BookingSpec.dfy): that one has no batch,
// no value and no optimum.
//
// An untrusted optimizer supplies the allocation x and the certificate (y, z, alphaBps). Decide has no
// precondition. Its verdict is fixed by its inputs: Issue exactly when Accepts holds, with a token that
// holds the two given hash texts, the request id, the checked allocation, the stated gap, the value of
// the allocation and the capacities that remain. The hash texts are inputs. Decide computes no hash.
include "../proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy"

abstract module BookingCertificateSpec {
  import C = BookingDualCert

  datatype Batch = Batch(A: seq<seq<int>>, c: seq<int>, w: seq<int>)
  datatype Proposal = Proposal(x: seq<int>, y: seq<int>, z: seq<int>, alphaBps: int)
  datatype Token = Token(
    preStateHash: string, batchHash: string, requestId: string,
    x: seq<int>, alphaBps: int, value: int, remaining: seq<int>)
  datatype Verdict = Refuse | Issue(token: Token)

  // The check. C.Accepts is the executable predicate of Rounds 2 and 3: shapes agree, alphaBps <= 10000,
  // x is 0/1 and no slot is used above its capacity, (y, z) is dual feasible, and
  // (10000 - alphaBps) * (Dot(y, c) + Sum(z)) <= 10000 * Dot(w, x).
  predicate Accepts(batch: Batch, p: Proposal) {
    0 <= p.alphaBps && C.Accepts(batch.A, batch.c, batch.w, p.x, p.y, p.z, p.alphaBps)
  }

  // Capacity of every slot after the allocation.
  function Remaining(batch: Batch, x: seq<int>): seq<int>
    requires C.Shape(batch.A, batch.c, |x|)
  {
    seq(|batch.c|, i requires 0 <= i < |batch.c| => batch.c[i] - C.Dot(batch.A[i], x))
  }

  method Decide(batch: Batch, preStateHash: string, batchHash: string, requestId: string, p: Proposal)
      returns (verdict: Verdict)
    ensures verdict.Issue? <==> Accepts(batch, p)
    ensures verdict.Issue? ==>
      |p.x| == |batch.w| && C.Shape(batch.A, batch.c, |p.x|) &&
      verdict.token == Token(preStateHash, batchHash, requestId, p.x, p.alphaBps,
                             C.Dot(batch.w, p.x), Remaining(batch, p.x))
}
