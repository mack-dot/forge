// Z10 adversarial review of SinkCore (M1-B wave 5). A DRAFT in a scratch folder. NOT gate evidence.
// No assume, no axiom, no bodiless lemma.
include "SinkCore.dfy"

// Part 1: facts about the assumption A1 (IdealMac) with VerifyTag left uninterpreted.
module Attack {
  import S = SinkCore
  import F = RefundFinality
  import R = Refund

  lemma Bound(xs: set<int>) returns (m: int)
    ensures forall x | x in xs :: x < m
    decreases |xs|
  {
    if xs == {} {
      m := 0;
    } else {
      var x :| x in xs;
      var m0 := Bound(xs - {x});
      m := if m0 > x + 1 then m0 else x + 1;
      forall y | y in xs
        ensures y < m
      {
        if y != x {
          assert y in xs - {x};
        }
      }
    }
  }

  ghost predicate HasTag(c: S.Claim) { exists t: S.Tag :: S.VerifyTag(c, t) }

  // If every claim has at least one tag that verifies (true for any real signature scheme: the key
  // holder can sign every message), then IdealMac is false in EVERY model state.
  lemma TotalVerifierBreaksIdealMac(s: S.System)
    requires forall c: S.Claim :: HasTag(c)
    ensures !S.IdealMac(s)
  {
    var ids := set p | p in s.minted :: p.0.reqId;
    var m := Bound(ids);
    var ch := F.Charge("", 0, 0, false);
    var c := S.Claim(0, 0, ch, m, F.Request("", 0, ""), ch, R.Intent("", "", 0, ""));
    assert HasTag(c);
    var t :| S.VerifyTag(c, t);
    if S.IdealMac(s) {
      assert (c, t) in s.minted;
      assert m in ids;
      assert false;
    }
  }

  // IdealMac at the initial state of InitInv/InitRel (minted = {}) means that no tag ever verifies,
  // so no Commit ever changes any state.
  lemma IdealMacAtInit(init: S.State, c: S.Claim, t: S.Tag)
    requires S.IdealMac(S.Sys(init, [], {}, [], {}))
    ensures !S.VerifyTag(c, t)
    ensures forall s: S.System :: S.Commit(s, c, t) == s
  {
  }

  // A step-local form of A1 (only the presented claim and tag) is enough to keep Inv.
  lemma LocalA1Suffices(init: S.State, s: S.System, c: S.Claim, t: S.Tag)
    requires S.Inv(init, s)
    requires S.VerifyTag(c, t) ==> (c, t) in s.minted
    ensures S.Inv(init, S.Commit(s, c, t))
  {
    S.CommitKeepsChain(init, s, c, t);
    S.CommitKeepsDistinctIds(s, c, t);
    S.CommitKeepsSettledIsLog(s, c, t);
    S.CommitKeepsOutboxIsLog(s, c, t);
    if S.SinkAccepts(s, c, t) {
      assert (c, t) in s.minted;
      var log' := s.log + [c];
      forall i | 0 <= i < |log'|
        ensures S.Ours(log'[i]) && S.SpecRel(log'[i].pre, log'[i].req, log'[i].post, log'[i].eff)
      {
        if i < |s.log| {
          assert log'[i] == s.log[i];
        } else {
          assert log'[i] == c;
        }
      }
    }
  }
}

