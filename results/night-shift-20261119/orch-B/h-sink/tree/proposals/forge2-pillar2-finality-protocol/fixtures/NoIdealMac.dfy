// NEGATIVE CONTROL (U415): the invariant-preservation lemma without the ideal-MAC assumption. Verification MUST FAIL.
abstract module NoIdealMac {
  type State(==, !new)
  type Request(==, !new)
  type Effect(==, !new)
  type Tag(==, !new)
  ghost const SPEC: int
  ghost const CHK: int
  ghost predicate SpecRel(pre: State, req: Request, post: State, eff: Effect)

  datatype Claim = Claim(specId: int, checkerId: int, pre: State, reqId: int, req: Request, post: State, eff: Effect)
  datatype System = Sys(store: State, log: seq<Claim>, settled: set<int>, outbox: seq<Effect>,
                        minted: set<(Claim, Tag)>)

  ghost predicate VerifyTag(c: Claim, t: Tag)

  ghost predicate Ours(c: Claim)
  {
    c.specId == SPEC && c.checkerId == CHK
  }

  // A1
  ghost predicate IdealMac(s: System)
  {
    forall c: Claim, t: Tag :: VerifyTag(c, t) ==> (c, t) in s.minted
  }

  // A2 for one mint
  ghost predicate MintAllowed(c: Claim)
  {
    Ours(c) ==> SpecRel(c.pre, c.req, c.post, c.eff)
  }

  ghost predicate MinterSound(minted: set<(Claim, Tag)>)
  {
    forall c: Claim, t: Tag :: (c, t) in minted && Ours(c) ==> SpecRel(c.pre, c.req, c.post, c.eff)
  }

  ghost predicate LogSound(log: seq<Claim>)
  {
    forall i | 0 <= i < |log| :: Ours(log[i]) && SpecRel(log[i].pre, log[i].req, log[i].post, log[i].eff)
  }

  ghost predicate Chain(init: State, log: seq<Claim>, store: State)
  {
    if |log| == 0 then store == init
    else log[0].pre == init && store == log[|log| - 1].post &&
         forall i | 0 <= i < |log| - 1 :: log[i].post == log[i + 1].pre
  }

  ghost predicate DistinctIds(log: seq<Claim>)
  {
    forall i, j | 0 <= i < j < |log| :: log[i].reqId != log[j].reqId
  }

  ghost predicate SettledIsLog(s: System)
  {
    forall id: int :: id in s.settled <==> exists i :: 0 <= i < |s.log| && s.log[i].reqId == id
  }

  ghost predicate OutboxIsLog(s: System)
  {
    |s.outbox| == |s.log| && forall i | 0 <= i < |s.log| :: s.outbox[i] == s.log[i].eff
  }

  ghost predicate Inv(init: State, s: System)
  {
    MinterSound(s.minted) && LogSound(s.log) && Chain(init, s.log, s.store) && DistinctIds(s.log) &&
    SettledIsLog(s) && OutboxIsLog(s)
  }

  ghost predicate SinkAccepts(s: System, c: Claim, t: Tag)
  {
    VerifyTag(c, t) && Ours(c) && s.store == c.pre && c.reqId !in s.settled
  }

  ghost function Commit(s: System, c: Claim, t: Tag): System
  {
    if SinkAccepts(s, c, t)
    then Sys(c.post, s.log + [c], s.settled + {c.reqId}, s.outbox + [c.eff], s.minted)
    else s
  }

  ghost function Mint(s: System, c: Claim, t: Tag): System
    requires MintAllowed(c)
  {
    s.(minted := s.minted + {(c, t)})
  }

  lemma InitInv(init: State)
    ensures Inv(init, Sys(init, [], {}, [], {}))
  {
  }

  lemma MintPreservesInv(init: State, s: System, c: Claim, t: Tag)
    requires Inv(init, s) && MintAllowed(c)
    ensures Inv(init, Mint(s, c, t))
    ensures IdealMac(s) ==> IdealMac(Mint(s, c, t))
  {
  }

  lemma AcceptedClaimSatisfiesSpec(s: System, c: Claim, t: Tag)
    requires MinterSound(s.minted) && IdealMac(s) && SinkAccepts(s, c, t)
    ensures SpecRel(c.pre, c.req, c.post, c.eff)
  {
    assert (c, t) in s.minted;
  }

  lemma CommitKeepsLogSound(s: System, c: Claim, t: Tag)
    requires MinterSound(s.minted) && LogSound(s.log)
    ensures LogSound(Commit(s, c, t).log)
  {
    if SinkAccepts(s, c, t) {
      AcceptedClaimSatisfiesSpec(s, c, t);
      var log' := s.log + [c];
      forall i | 0 <= i < |log'|
        ensures Ours(log'[i]) && SpecRel(log'[i].pre, log'[i].req, log'[i].post, log'[i].eff)
      {
        if i < |s.log| {
          assert log'[i] == s.log[i];
        } else {
          assert log'[i] == c;
        }
      }
    }
  }

  lemma CommitKeepsChain(init: State, s: System, c: Claim, t: Tag)
    requires Chain(init, s.log, s.store)
    ensures Chain(init, Commit(s, c, t).log, Commit(s, c, t).store)
  {
    if SinkAccepts(s, c, t) {
      var log' := s.log + [c];
      assert log'[|log'| - 1] == c;
      if |s.log| > 0 {
        assert log'[0] == s.log[0];
        forall i | 0 <= i < |log'| - 1
          ensures log'[i].post == log'[i + 1].pre
        {
          if i < |s.log| - 1 {
            assert log'[i] == s.log[i] && log'[i + 1] == s.log[i + 1];
          } else {
            assert log'[i] == s.log[|s.log| - 1] && log'[i + 1] == c;
          }
        }
      }
    }
  }

  lemma CommitKeepsDistinctIds(s: System, c: Claim, t: Tag)
    requires DistinctIds(s.log) && SettledIsLog(s)
    ensures DistinctIds(Commit(s, c, t).log)
  {
    if SinkAccepts(s, c, t) {
      var log' := s.log + [c];
      forall i, j | 0 <= i < j < |log'|
        ensures log'[i].reqId != log'[j].reqId
      {
        assert log'[i] == s.log[i];
        if j < |s.log| {
          assert log'[j] == s.log[j];
        } else {
          assert log'[j] == c;
          assert s.log[i].reqId in s.settled;
        }
      }
    }
  }

  lemma CommitKeepsSettledIsLog(s: System, c: Claim, t: Tag)
    requires SettledIsLog(s)
    ensures SettledIsLog(Commit(s, c, t))
  {
    if SinkAccepts(s, c, t) {
      var s' := Commit(s, c, t);
      forall id: int
        ensures id in s'.settled <==> exists i :: 0 <= i < |s'.log| && s'.log[i].reqId == id
      {
        if id in s'.settled {
          if id == c.reqId {
            assert s'.log[|s.log|] == c;
          } else {
            var i :| 0 <= i < |s.log| && s.log[i].reqId == id;
            assert s'.log[i] == s.log[i];
          }
        }
        if exists i :: 0 <= i < |s'.log| && s'.log[i].reqId == id {
          var i :| 0 <= i < |s'.log| && s'.log[i].reqId == id;
          if i < |s.log| {
            assert s'.log[i] == s.log[i];
          } else {
            assert s'.log[i] == c;
          }
        }
      }
    }
  }

  lemma CommitKeepsOutboxIsLog(s: System, c: Claim, t: Tag)
    requires OutboxIsLog(s)
    ensures OutboxIsLog(Commit(s, c, t))
  {
    if SinkAccepts(s, c, t) {
      var s' := Commit(s, c, t);
      forall i | 0 <= i < |s'.log|
        ensures s'.outbox[i] == s'.log[i].eff
      {
        if i < |s.log| {
          assert s'.log[i] == s.log[i] && s'.outbox[i] == s.outbox[i];
        } else {
          assert s'.log[i] == c && s'.outbox[i] == c.eff;
        }
      }
    }
  }

  // P1. Every commit step keeps the invariant, for ANY claim and ANY tag the adversary supplies.
  lemma CommitPreservesInv(init: State, s: System, c: Claim, t: Tag)
    requires Inv(init, s)
    ensures Inv(init, Commit(s, c, t))
  {
    CommitKeepsLogSound(s, c, t);
    CommitKeepsChain(init, s, c, t);
    CommitKeepsDistinctIds(s, c, t);
    CommitKeepsSettledIsLog(s, c, t);
    CommitKeepsOutboxIsLog(s, c, t);
  }

  // P2. What the invariant means: every settled transition satisfies the relation; the settled transitions form
  // one path from the initial state to the stored state; one effect per settled request id.
  lemma InvMeaning(init: State, s: System)
    requires Inv(init, s)
    ensures forall i | 0 <= i < |s.log| :: SpecRel(s.log[i].pre, s.log[i].req, s.log[i].post, s.log[i].eff)
    ensures |s.log| == 0 ==> s.store == init
    ensures |s.log| > 0 ==> s.log[0].pre == init && s.store == s.log[|s.log| - 1].post
    ensures forall i | 0 <= i < |s.log| - 1 :: s.log[i].post == s.log[i + 1].pre
    ensures |s.outbox| == |s.log|
    ensures forall i, j | 0 <= i < j < |s.log| :: s.log[i].reqId != s.log[j].reqId
  {
  }

  // P3. Rejections (each needs no assumption).
  lemma ForgedTagRejected(s: System, c: Claim, t: Tag)
    requires !VerifyTag(c, t)
    ensures Commit(s, c, t) == s
  {
  }

  lemma OtherSpecOrCheckerRejected(s: System, c: Claim, t: Tag)
    requires c.specId != SPEC || c.checkerId != CHK
    ensures Commit(s, c, t) == s
  {
  }

  lemma StaleStateRejected(s: System, c: Claim, t: Tag)
    requires s.store != c.pre
    ensures Commit(s, c, t) == s
  {
  }

  lemma ReplayRejected(s: System, c: Claim, t: Tag, c2: Claim, t2: Tag)
    requires SinkAccepts(s, c, t) && c2.reqId == c.reqId
    ensures Commit(Commit(s, c, t), c2, t2) == Commit(s, c, t)
  {
  }

  // P4. Non-vacuity of acceptance: a minted, verifying, fresh, current claim is committed and its effect is released once.
  lemma HonestCommitSettles(init: State, s: System, c: Claim, t: Tag)
    requires Inv(init, s) && SinkAccepts(s, c, t)
    ensures Commit(s, c, t).store == c.post
    ensures Commit(s, c, t).outbox == s.outbox + [c.eff]
    ensures c.reqId in Commit(s, c, t).settled
  {
  }
}
