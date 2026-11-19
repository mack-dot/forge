// Night shift 2026-11-19, Orchestrator B, task r-top (review of b-top). Reviewer lemmas. NOT gate evidence.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "KeyedHash.dfy"

module RTopLemmas {
  import opened HashCore
  import opened SliceSafetyBytesV3
  import opened KeyedHash
  import S3 = SliceTheoremV3
  import ST = SliceTheorem
  import T = TopFromExport

  // R1: ToExp maps each named field to the SAME-named field (all nine), so it is the identity bijection.
  lemma ToExpFieldwise(x: S3.FlatIn)
    ensures T.ToExp(x).chargeB == x.chargeB && T.ToExp(x).requestB == x.requestB
    ensures T.ToExp(x).original == x.original && T.ToExp(x).remaining == x.remaining
    ensures T.ToExp(x).enabled == x.enabled && T.ToExp(x).requestOpen == x.requestOpen
    ensures T.ToExp(x).candidate == x.candidate && T.ToExp(x).amount == x.amount
    ensures T.ToExp(x).reasonB == x.reasonB
  {}

  // R2: two stores never hold equal charges (keys differ, charge id == key). NO hypothesis.
  lemma NoTwoStoresEqualCharges(H: HashFn, acts: seq<KAct>, k1: string, k2: string)
    requires k1 in KExec(H, acts) && k2 in KExec(H, acts) && k1 != k2
    ensures KExec(H, acts)[k1].charge != KExec(H, acts)[k2].charge
  {
    KExecWellKeyed(H, acts);
  }

  // Keys never disappear and settled sets only grow (the model has no delete, no rollback action).
  lemma Mono(H: HashFn, acts: seq<KAct>, a: int, b: int, k: string)
    requires 0 <= a <= b <= |acts|
    requires k in KExec(H, acts[..a])
    ensures k in KExec(H, acts[..b])
    ensures KExec(H, acts[..a])[k].settled <= KExec(H, acts[..b])[k].settled
    decreases b
  {
    if b > a {
      Mono(H, acts, a, b - 1, k);
      KExecStep(H, acts, b - 1);
      var st := KExec(H, acts[..b - 1]);
      KStepFrame(H, st, acts[b - 1]);
      match acts[b - 1]
      case KMint(_, _, _) =>
      case KCreate(_, _) =>
      case KDel(key, tok, s) =>
        if key == k { StepExact(H, st[k], tok, s); }
    }
  }

  // A commit lands in the store named by the token's intent charge id and settles its request id.
  lemma CommitKey(H: HashFn, acts: seq<KAct>, g: int)
    requires CommitsAt(H, acts, g)
    ensures acts[g].key == acts[g].tok.intent.chargeId
    ensures acts[g].key in KExec(H, acts[..g + 1])
    ensures acts[g].tok.requestId in KExec(H, acts[..g + 1])[acts[g].key].settled
  {
    KExecWellKeyed(H, acts[..g]);
    KExecStep(H, acts, g);
    StepExact(H, KExec(H, acts[..g])[acts[g].key], acts[g].tok, acts[g].sigOk);
  }

  // R3: two different commits in ONE keyed run, in ANY stores, never share (intent charge id, request id).
  // NO hypothesis (no A2, H1B, B5, A4). It holds because the model has no delete, no re-create, no rollback.
  lemma NoDoubleCommit(H: HashFn, acts: seq<KAct>, g1: int, g2: int)
    requires g1 < g2 && CommitsAt(H, acts, g1) && CommitsAt(H, acts, g2)
    ensures acts[g1].tok.requestId != acts[g2].tok.requestId ||
            acts[g1].tok.intent.chargeId != acts[g2].tok.intent.chargeId
  {
    CommitKey(H, acts, g1);
    CommitKey(H, acts, g2);
    if acts[g1].tok.requestId == acts[g2].tok.requestId && acts[g1].tok.intent.chargeId == acts[g2].tok.intent.chargeId {
      var k := acts[g1].key;
      Mono(H, acts, g1 + 1, g2, k);
      StepExact(H, KExec(H, acts[..g2])[k], acts[g2].tok, acts[g2].sigOk);
      assert false;
    }
  }

  // R4: the same signed bytes (any signature) commit at most once across all stores. NO hypothesis.
  lemma SameBytesCommitOnce(H: HashFn, acts: seq<KAct>, g1: int, g2: int)
    requires g1 != g2 && CommitsAt(H, acts, g1) && CommitsAt(H, acts, g2)
    ensures BytesOf(acts[g1].tok) != BytesOf(acts[g2].tok)
  {
    if BytesOf(acts[g1].tok) == BytesOf(acts[g2].tok) {
      BytesInjective(acts[g1].tok, acts[g2].tok);
      assert acts[g1].tok.(sig := []).requestId == acts[g2].tok.(sig := []).requestId;
      assert acts[g1].tok.(sig := []).intent == acts[g2].tok.(sig := []).intent;
      if g1 < g2 { NoDoubleCommit(H, acts, g1, g2); } else { NoDoubleCommit(H, acts, g2, g1); }
    }
  }
}
