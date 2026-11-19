
  // ======================= d-reqid: new parts =======================
  // Match: the request id of the token body equals the request id of the intent (the patched sink.ts check).
  predicate Match(tok: SinkToken)
  {
    tok.intent.requestId == tok.requestId
  }

  // The model step that one core step stands for: Commit for a matching token; a stutter (no model
  // step) for a mismatched one. No signature assumption is used to define it.
  ghost function ModelStep(s: System, tok: SinkToken): System
  {
    if Match(tok) then Commit(s, ClaimOf(tok), tok.sig) else s
  }

  // Refinement with A5 only (no A1, no A2): every core step is a model Commit or a stutter.
  lemma StepRefinesModelStep(core: Core, s: System, toks: seq<SinkToken>, tok: SinkToken, sigOk: bool)
    requires A5_VerifierMatches(tok, sigOk)
    requires Rel(core, s, toks)
    ensures Step(core, tok, sigOk).out.Committed? <==> SinkAccepts(s, ClaimOf(tok), tok.sig) && Match(tok)
    ensures Rel(Step(core, tok, sigOk).core, ModelStep(s, tok), NextToks(toks, tok, Step(core, tok, sigOk).out))
  {
    var c := ClaimOf(tok);
    EncSetMember(core.settled, tok.requestId);
    assert Ours(c) <==> (tok.specId == PINNED_SPEC && tok.checkerId == PINNED_CHK);
    var r := Step(core, tok, sigOk);
    if r.out.Committed? {
      var s' := Commit(s, c, tok.sig);
      EncSetAdd(core.settled, tok.requestId);
      var toks' := toks + [tok];
      forall i | 0 <= i < |toks'|
        ensures s'.log[i] == ClaimOf(toks'[i]) && VerifyTag(s'.log[i], toks'[i].sig)
      {
        if i < |toks| {
          assert s'.log[i] == s.log[i] && toks'[i] == toks[i];
        } else {
          assert s'.log[i] == c && toks'[i] == tok;
        }
      }
    }
  }

  // The original unconditional iff is FALSE for the patched core: a mismatched token whose tag
  // verifies is accepted by the model and rejected by the core. So StepRefinesCommit needs A1 and A2.
  lemma IffNeedsA1A2(core: Core, s: System, toks: seq<SinkToken>, tok: SinkToken)
    requires A5_VerifierMatches(tok, true) && Rel(core, s, toks)
    requires tok.specId == PINNED_SPEC && tok.checkerId == PINNED_CHK
    requires !Match(tok) && tok.requestId !in core.settled && core.charge == tok.pre
    ensures SinkAccepts(s, ClaimOf(tok), tok.sig)
    ensures Step(core, tok, true).out == Rejected(ReqIdMismatch)
  {
    EncSetMember(core.settled, tok.requestId);
  }

  // Exact acceptance of one step (this also rules out a reject-all core).
  lemma StepExact(core: Core, tok: SinkToken, sigOk: bool)
    ensures Step(core, tok, sigOk).out.Committed? <==>
      (tok.specId == PINNED_SPEC && tok.checkerId == PINNED_CHK && sigOk && Match(tok) &&
       tok.requestId !in core.settled && core.charge == tok.pre)
    ensures Step(core, tok, sigOk).out.Committed? ==>
      Step(core, tok, sigOk).core == Core(tok.post, core.settled + {tok.requestId}, core.outbox + [tok.intent])
  {
  }

  // A rejected delivery changes nothing. Any token, any sigOk.
  lemma RejectedChangesNothing(core: Core, tok: SinkToken, sigOk: bool)
    ensures !Step(core, tok, sigOk).out.Committed? ==> Step(core, tok, sigOk).core == core
  {
  }

  // A mismatched token never commits, whatever the verifier says.
  lemma MismatchNeverCommits(core: Core, tok: SinkToken, sigOk: bool)
    requires !Match(tok)
    ensures !Step(core, tok, sigOk).out.Committed? && Step(core, tok, sigOk).core == core
  {
  }

  // Zero-amount tokens still commit: the check is on ids only, not on amounts.
  lemma ZeroAmountStillCommits(core: Core, tok: SinkToken)
    requires tok.specId == PINNED_SPEC && tok.checkerId == PINNED_CHK && Match(tok)
    requires tok.requestId !in core.settled && core.charge == tok.pre && tok.intent.amount == 0
    ensures Step(core, tok, true).out.Committed?
    ensures Step(core, tok, true).core.outbox == core.outbox + [tok.intent]
  {
  }

  // ---- sequences of deliveries with ARBITRARY tokens and ARBITRARY sigOk (no A1, A2, A5) ----
  datatype Delivery = Delivery(tok: SinkToken, sigOk: bool)

  function Run(core: Core, ds: seq<Delivery>): Core
    decreases |ds|
  {
    if |ds| == 0 then core else Run(Step(core, ds[0].tok, ds[0].sigOk).core, ds[1..])
  }

  // From ANY start core: the run only appends; settled and outbox grow by the same number; every new
  // outbox entry carries a request id that is now settled and was not settled at the start; new
  // entries carry pairwise distinct request ids.
  lemma RunGrowth(c: Core, ds: seq<Delivery>)
    ensures c.settled <= Run(c, ds).settled
    ensures |c.outbox| <= |Run(c, ds).outbox| && Run(c, ds).outbox[..|c.outbox|] == c.outbox
    ensures |Run(c, ds).outbox| - |c.outbox| == |Run(c, ds).settled| - |c.settled|
    ensures forall i | |c.outbox| <= i < |Run(c, ds).outbox| ::
      Run(c, ds).outbox[i].requestId in Run(c, ds).settled && Run(c, ds).outbox[i].requestId !in c.settled
    ensures forall i, j | |c.outbox| <= i < j < |Run(c, ds).outbox| ::
      Run(c, ds).outbox[i].requestId != Run(c, ds).outbox[j].requestId
    decreases |ds|
  {
    if |ds| > 0 {
      var d := ds[0];
      var c1 := Step(c, d.tok, d.sigOk).core;
      StepExact(c, d.tok, d.sigOk);
      RunGrowth(c1, ds[1..]);
      var c' := Run(c, ds);
      assert c' == Run(c1, ds[1..]);
      if Step(c, d.tok, d.sigOk).out.Committed? {
        var r := d.tok.requestId;
        assert c1.settled == c.settled + {r} && r !in c.settled;
        assert |c1.settled| == |c.settled| + 1;
        assert c1.outbox == c.outbox + [d.tok.intent] && d.tok.intent.requestId == r;
        assert c'.outbox[..|c1.outbox|] == c1.outbox;
        assert c'.outbox[..|c.outbox|] == c1.outbox[..|c.outbox|] == c.outbox;
        assert c'.outbox[|c.outbox|] == c1.outbox[|c.outbox|];
        forall i | |c.outbox| <= i < |c'.outbox|
          ensures c'.outbox[i].requestId in c'.settled && c'.outbox[i].requestId !in c.settled
        {
          if i == |c.outbox| {
            assert c'.outbox[i].requestId == r;
          }
        }
        forall i, j | |c.outbox| <= i < j < |c'.outbox|
          ensures c'.outbox[i].requestId != c'.outbox[j].requestId
        {
          if i == |c.outbox| {
            assert c'.outbox[i].requestId == r && r in c1.settled;
            assert c'.outbox[j].requestId !in c1.settled;
          }
        }
      } else {
        assert c1 == c;
      }
    }
  }

  // The store invariant of the effect side.
  ghost predicate Good(c: Core)
  {
    (forall i | 0 <= i < |c.outbox| :: c.outbox[i].requestId in c.settled) &&
    (forall i, j | 0 <= i < j < |c.outbox| :: c.outbox[i].requestId != c.outbox[j].requestId) &&
    |c.outbox| == |c.settled|
  }

  lemma InitGood(init: F.Charge)
    ensures Good(Core(init, {}, []))
  {
  }

  // MAIN (no signature assumption): for EVERY sequence of deliveries with arbitrary tokens and arbitrary
  // sigOk, Good is kept. So every outbox request id is settled, at most one outbox entry exists per
  // request id, and |outbox| == |settled|.
  lemma RunKeepsGood(c: Core, ds: seq<Delivery>)
    requires Good(c)
    ensures Good(Run(c, ds))
  {
    RunGrowth(c, ds);
    var c' := Run(c, ds);
    forall i | 0 <= i < |c'.outbox|
      ensures c'.outbox[i].requestId in c'.settled
    {
      if i < |c.outbox| {
        assert c'.outbox[i] == c'.outbox[..|c.outbox|][i] == c.outbox[i];
      }
    }
    forall i, j | 0 <= i < j < |c'.outbox|
      ensures c'.outbox[i].requestId != c'.outbox[j].requestId
    {
      if j < |c.outbox| {
        assert c'.outbox[i] == c'.outbox[..|c.outbox|][i] == c.outbox[i];
        assert c'.outbox[j] == c'.outbox[..|c.outbox|][j] == c.outbox[j];
      } else if i < |c.outbox| {
        assert c'.outbox[i] == c'.outbox[..|c.outbox|][i] == c.outbox[i];
        assert c'.outbox[i].requestId in c.settled;
      }
    }
  }

  lemma FromInitGood(init: F.Charge, ds: seq<Delivery>)
    ensures Good(Run(Core(init, {}, []), ds))
  {
    InitGood(init);
    RunKeepsGood(Core(init, {}, []), ds);
  }

  // Non-vacuity witness: a concrete two-delivery run from a fresh store where both deliveries commit,
  // the second one a zero-amount refund. sigOk is true for both.
  lemma Witness()
    ensures var c0 := Charge0();
            var t1 := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_1", c0.(remaining := 90),
                                R.Intent("ch_1", "rq_1", 10, "duplicate_charge"), "sig1");
            var t2 := SinkToken(PINNED_SPEC, PINNED_CHK, c0.(remaining := 90), "rq_2", c0.(remaining := 90),
                                R.Intent("ch_1", "rq_2", 0, "returned_item"), "sig2");
            var r1 := Step(Core(c0, {}, []), t1, true);
            var r2 := Step(r1.core, t2, true);
            r1.out.Committed? && r2.out.Committed? &&
            r2.core.outbox == [t1.intent, t2.intent] && r2.core.settled == {"rq_1", "rq_2"} &&
            Run(Core(c0, {}, []), [Delivery(t1, true), Delivery(t2, true)]) == r2.core
  {
    var c0 := Charge0();
    var t1 := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_1", c0.(remaining := 90),
                        R.Intent("ch_1", "rq_1", 10, "duplicate_charge"), "sig1");
    var t2 := SinkToken(PINNED_SPEC, PINNED_CHK, c0.(remaining := 90), "rq_2", c0.(remaining := 90),
                        R.Intent("ch_1", "rq_2", 0, "returned_item"), "sig2");
    var ds := [Delivery(t1, true), Delivery(t2, true)];
    var c1 := Step(Core(c0, {}, []), t1, true).core;
    var c2 := Step(c1, t2, true).core;
    assert ds[1..] == [Delivery(t2, true)];
    assert ds[1..][1..] == [];
    assert Run(c2, []) == c2;
    assert Run(c1, [Delivery(t2, true)]) == Run(c2, []);
    assert Run(Core(c0, {}, []), ds) == Run(c1, ds[1..]);
  }

  function Charge0(): F.Charge
  {
    F.Charge("ch_1", 100, 100, true)
  }

  // The same mismatched first token of the gap trace is rejected by this core, and the honest token
  // for the victim's request id then commits once.
  lemma PatchedRefusesGapTrace()
    ensures var c0 := Charge0();
            var bad := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_body", c0.(remaining := 90),
                                 R.Intent("ch_1", "rq_victim", 10, "duplicate_charge"), "sigA");
            var honest := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_victim", c0.(remaining := 90),
                                    R.Intent("ch_1", "rq_victim", 10, "duplicate_charge"), "sigB");
            var r1 := Step(Core(c0, {}, []), bad, true);
            var r2 := Step(r1.core, honest, true);
            r1.out == Rejected(ReqIdMismatch) && r1.core == Core(c0, {}, []) &&
            r2.out.Committed? && r2.core.outbox == [honest.intent]
  {
  }

  // A separate gap that the patched core keeps (same class: a trusted but faulty signer): the core does
  // not bind intent.chargeId or post.chargeId to the stored charge. sink.ts does not either.
  lemma ChargeIdNotBound()
    ensures var c0 := Charge0();
            var t := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_x", c0.(chargeId := "ch_2", remaining := 90),
                               R.Intent("ch_2", "rq_x", 10, "duplicate_charge"), "sigC");
            var r := Step(Core(c0, {}, []), t, true);
            r.out.Committed? && r.core.outbox[0].chargeId != c0.chargeId && r.core.charge.chargeId != c0.chargeId
  {
  }
