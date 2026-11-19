// Night shift 2026-11-19, Orchestrator B, task b-integrate (G1). A DRAFT in an evidence folder. NOT approved.
// NOT gate evidence. M1-B stays OPEN. A Dafny-MODEL statement only. NOT a proof about sink.ts, SQLite, Node,
// OpenSSL, Ed25519, SHA-256, a compiled program or a database file.
//
// What this file is. SinkCoreReqId (d-reqid; byte-equal copy in inputs/transport/sink/) with ONE more check in
// Step: the charge-id check of d-reqid/diffs/sink-reqid-and-chargeid.diff, in the same place as in the patched
// sink.ts (inside the transaction, after the pre-state check). sink.ts compares the stored chargeId with
// intent.chargeId, and post.chargeId with intent.chargeId. The core does the same two comparisons. After the
// pre-state check, core.charge == tok.pre, so tok.pre.chargeId is bound as well (no third comparison is needed).
// It refines FinalityProtocol directly (refining SinkCore crashes the pinned Dafny 4.11.0).
//
// Assumption use. The structural lemmas of this file (StepExact, RunGrowth, RunKeepsGoodV3, ChargeIdKept, ...)
// use NO assumption at all: arbitrary tokens, arbitrary sigOk. StepRefinesModelStep uses A5 only. Nothing in
// this file uses IdealMac (A1) or MinterSound (A2). The deployment precondition GoodStart is NAMED; lemma
// NoGoodStartDuplicates shows that it is necessary. No assume, no axiom, no bodiless lemma in this file.
include "inputs/transport/model/FinalityProtocol.dfy"
include "inputs/transport/impl/RefundFinality.dfy"

module SinkCoreV3 refines FinalityProtocol {
  import F = RefundFinality
  import R = Refund

  type State = F.Charge
  type Request = F.Request
  type Effect = R.RefundIntent
  type Tag = string

  const PINNED_SPEC: int := 1
  const PINNED_CHK: int := 2
  ghost const SPEC: int := PINNED_SPEC
  ghost const CHK: int := PINNED_CHK

  ghost predicate SpecRel(pre: State, req: Request, post: State, eff: Effect)
  {
    F.Authorizes(pre, F.Transition(req, post, eff))
  }

  // ---- request ids: text in the sink, int in the model; an injective encoding (copied from SinkCoreReqId) ----
  const B: int := 0x110001

  function Enc(s: string): int
    decreases |s|
  {
    if |s| == 0 then 0 else (s[0] as int + 1) + B * Enc(s[1..])
  }

  lemma EncNonNeg(s: string)
    ensures Enc(s) >= 0
    decreases |s|
  {
    if |s| > 0 {
      EncNonNeg(s[1..]);
    }
  }

  lemma DigitsUnique(x: int, ex: int, y: int, ey: int)
    requires 0 <= x < B && 0 <= y < B && x + B * ex == y + B * ey
    ensures x == y && ex == ey
  {
  }

  lemma EncInjective(a: string, b: string)
    requires Enc(a) == Enc(b)
    ensures a == b
    decreases |a|
  {
    if |a| == 0 && |b| == 0 {
    } else if |a| == 0 {
      EncNonNeg(b[1..]);
    } else if |b| == 0 {
      EncNonNeg(a[1..]);
    } else {
      DigitsUnique(a[0] as int + 1, Enc(a[1..]), b[0] as int + 1, Enc(b[1..]));
      EncInjective(a[1..], b[1..]);
      assert a == [a[0]] + a[1..];
      assert b == [b[0]] + b[1..];
    }
  }

  ghost function EncSet(ss: set<string>): set<int>
  {
    set id | id in ss :: Enc(id)
  }

  lemma EncSetMember(ss: set<string>, x: string)
    ensures x in ss <==> Enc(x) in EncSet(ss)
  {
    if Enc(x) in EncSet(ss) {
      var y :| y in ss && Enc(y) == Enc(x);
      EncInjective(y, x);
    }
  }

  lemma EncSetAdd(ss: set<string>, x: string)
    ensures EncSet(ss + {x}) == EncSet(ss) + {Enc(x)}
  {
  }

  // ---- the sink core ----
  datatype SinkToken = SinkToken(specId: int, checkerId: int, pre: F.Charge, requestId: string,
                                 post: F.Charge, intent: R.RefundIntent, sig: Tag)
  datatype Core = Core(charge: F.Charge, settled: set<string>, outbox: seq<R.RefundIntent>)
  datatype Why = ReqIdMismatch | IdsNotPinned | SignatureInvalid | RequestSettled | PreStateMismatch
               | ChargeIdMismatch | NoSuchCharge
  datatype Outcome = Committed | Rejected(why: Why)
  datatype StepResult = StepResult(core: Core, out: Outcome)

  function ClaimOf(tok: SinkToken): Claim
  {
    Claim(tok.specId, tok.checkerId, tok.pre, Enc(tok.requestId),
          F.Request(tok.requestId, tok.intent.amount, tok.intent.reason), tok.post, tok.intent)
  }

  // A5, named.
  ghost predicate A5_VerifierMatches(tok: SinkToken, sigOk: bool)
  {
    sigOk == VerifyTag(ClaimOf(tok), tok.sig)
  }

  // The request-id check of the patched sink.ts.
  predicate Match(tok: SinkToken)
  {
    tok.intent.requestId == tok.requestId
  }

  // The charge-id check of the patched sink.ts: stored chargeId == intent.chargeId, post.chargeId == intent.chargeId.
  predicate ChargeOk(stored: F.Charge, tok: SinkToken)
  {
    tok.pre.chargeId == tok.intent.chargeId && tok.post.chargeId == tok.intent.chargeId // MUTANT MA: intent vs pre only, not stored
  }

  // The step. Order of the checks = order of the patched sink.ts: ids, signature, request id (outside the
  // transaction); settled, pre-state, charge id (inside the transaction).
  function Step(core: Core, tok: SinkToken, sigOk: bool): StepResult
  {
    if tok.specId != PINNED_SPEC || tok.checkerId != PINNED_CHK then StepResult(core, Rejected(IdsNotPinned))
    else if !sigOk then StepResult(core, Rejected(SignatureInvalid))
    else if !Match(tok) then StepResult(core, Rejected(ReqIdMismatch))
    else if tok.requestId in core.settled then StepResult(core, Rejected(RequestSettled))
    else if core.charge != tok.pre then StepResult(core, Rejected(PreStateMismatch))
    // b-integrate: the new check.
    else if !ChargeOk(core.charge, tok) then StepResult(core, Rejected(ChargeIdMismatch))
    else StepResult(Core(tok.post, core.settled + {tok.requestId}, core.outbox + [tok.intent]), Committed)
  }

  // ---- exact acceptance (rules out a reject-all core and a commit-all core) ----
  lemma StepExact(core: Core, tok: SinkToken, sigOk: bool)
    ensures Step(core, tok, sigOk).out.Committed? <==>
      (tok.specId == PINNED_SPEC && tok.checkerId == PINNED_CHK && sigOk && Match(tok) &&
       tok.requestId !in core.settled && core.charge == tok.pre && ChargeOk(core.charge, tok))
    ensures Step(core, tok, sigOk).out.Committed? ==>
      Step(core, tok, sigOk).core == Core(tok.post, core.settled + {tok.requestId}, core.outbox + [tok.intent])
    ensures !Step(core, tok, sigOk).out.Committed? ==> Step(core, tok, sigOk).core == core
  {
  }

  lemma RejectedChangesNothing(core: Core, tok: SinkToken, sigOk: bool)
    ensures !Step(core, tok, sigOk).out.Committed? ==> Step(core, tok, sigOk).core == core
  {
  }

  lemma MismatchNeverCommits(core: Core, tok: SinkToken, sigOk: bool)
    requires !Match(tok)
    ensures !Step(core, tok, sigOk).out.Committed? && Step(core, tok, sigOk).core == core
  {
  }

  lemma ForeignChargeNeverCommits(core: Core, tok: SinkToken, sigOk: bool)
    requires tok.intent.chargeId != core.charge.chargeId || tok.post.chargeId != core.charge.chargeId
    ensures !Step(core, tok, sigOk).out.Committed? && Step(core, tok, sigOk).core == core
  {
  }

  // Zero amount stays a legitimate commit (protocol.md: zero is a legitimate authorization).
  lemma ZeroAmountStillCommits(core: Core, tok: SinkToken)
    requires tok.specId == PINNED_SPEC && tok.checkerId == PINNED_CHK && Match(tok)
    requires tok.requestId !in core.settled && core.charge == tok.pre && tok.intent.amount == 0
    requires tok.intent.chargeId == core.charge.chargeId && tok.post == tok.pre
    ensures Step(core, tok, true).out.Committed?
    ensures Step(core, tok, true).core == Core(core.charge, core.settled + {tok.requestId}, core.outbox + [tok.intent])
  {
  }

  // ---- refinement with A5 only (no A1, no A2) ----
  ghost predicate Rel(core: Core, s: System, toks: seq<SinkToken>)
  {
    s.store == core.charge &&
    s.settled == EncSet(core.settled) &&
    s.outbox == core.outbox &&
    |toks| == |s.log| &&
    (forall i | 0 <= i < |toks| :: s.log[i] == ClaimOf(toks[i]) && VerifyTag(s.log[i], toks[i].sig))
  }

  function NextToks(toks: seq<SinkToken>, tok: SinkToken, out: Outcome): seq<SinkToken>
  {
    if out.Committed? then toks + [tok] else toks
  }

  lemma InitRel(init: State)
    ensures Rel(Core(init, {}, []), Sys(init, [], {}, [], {}), [])
  {
    assert EncSet({}) == {};
  }

  lemma MintKeepsRel(core: Core, s: System, toks: seq<SinkToken>, c: Claim, t: Tag)
    requires Rel(core, s, toks)
    ensures Rel(core, s.(minted := s.minted + {(c, t)}), toks)
  {
  }

  // The model step that one core step stands for: the model's Commit for a token that passes both new checks;
  // a stutter otherwise. No signature assumption is used to define it.
  ghost function ModelStep(s: System, tok: SinkToken): System
  {
    if Match(tok) && ChargeOk(s.store, tok) then Commit(s, ClaimOf(tok), tok.sig) else s
  }

  lemma StepRefinesModelStep(core: Core, s: System, toks: seq<SinkToken>, tok: SinkToken, sigOk: bool)
    requires A5_VerifierMatches(tok, sigOk)
    requires Rel(core, s, toks)
    ensures Step(core, tok, sigOk).out.Committed? <==>
      SinkAccepts(s, ClaimOf(tok), tok.sig) && Match(tok) && ChargeOk(s.store, tok)
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

  // ---- runs of ARBITRARY deliveries (arbitrary tokens, arbitrary sigOk; no A1, A2, A5) ----
  datatype Delivery = Delivery(tok: SinkToken, sigOk: bool)

  function Run(core: Core, ds: seq<Delivery>): Core
    decreases |ds|
  {
    if |ds| == 0 then core else Run(Step(core, ds[0].tok, ds[0].sigOk).core, ds[1..])
  }

  // From ANY start core: append-only; settled and outbox grow together; each new entry has a request id that is
  // now settled and was not settled at the start; new entries have distinct request ids; the stored chargeId
  // NEVER changes; each new entry carries the stored chargeId.
  lemma RunGrowth(c: Core, ds: seq<Delivery>)
    ensures c.settled <= Run(c, ds).settled
    ensures |c.outbox| <= |Run(c, ds).outbox| && Run(c, ds).outbox[..|c.outbox|] == c.outbox
    ensures |Run(c, ds).outbox| - |c.outbox| == |Run(c, ds).settled| - |c.settled|
    ensures forall i | |c.outbox| <= i < |Run(c, ds).outbox| ::
      Run(c, ds).outbox[i].requestId in Run(c, ds).settled && Run(c, ds).outbox[i].requestId !in c.settled
    ensures forall i, j | |c.outbox| <= i < j < |Run(c, ds).outbox| ::
      Run(c, ds).outbox[i].requestId != Run(c, ds).outbox[j].requestId
    ensures Run(c, ds).charge.chargeId == c.charge.chargeId
    ensures forall i | |c.outbox| <= i < |Run(c, ds).outbox| :: Run(c, ds).outbox[i].chargeId == c.charge.chargeId
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
        assert c1.charge.chargeId == c.charge.chargeId && d.tok.intent.chargeId == c.charge.chargeId;
        assert c'.outbox[..|c1.outbox|] == c1.outbox;
        assert c'.outbox[..|c.outbox|] == c1.outbox[..|c.outbox|] == c.outbox;
        assert c'.outbox[|c.outbox|] == c1.outbox[|c.outbox|];
        forall i | |c.outbox| <= i < |c'.outbox|
          ensures c'.outbox[i].requestId in c'.settled && c'.outbox[i].requestId !in c.settled
          ensures c'.outbox[i].chargeId == c.charge.chargeId
        {
          if i == |c.outbox| {
            assert c'.outbox[i].requestId == r && c'.outbox[i] == d.tok.intent;
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

  // The store invariant of G1. Good is the d-reqid invariant; GoodV3 adds the charge-id binding.
  ghost predicate Good(c: Core)
  {
    (forall i | 0 <= i < |c.outbox| :: c.outbox[i].requestId in c.settled) &&
    (forall i, j | 0 <= i < j < |c.outbox| :: c.outbox[i].requestId != c.outbox[j].requestId) &&
    |c.outbox| == |c.settled|
  }

  ghost predicate GoodV3(c: Core)
  {
    Good(c) && (forall i | 0 <= i < |c.outbox| :: c.outbox[i].chargeId == c.charge.chargeId)
  }

  // GoodStart: the NAMED deployment precondition. A fresh store meets it (InitGood). A store written by an older
  // sink must be checked by AuditStart before this core serves it.
  ghost predicate GoodStart(c: Core)
  {
    GoodV3(c)
  }

  // AuditStart: an EXECUTABLE (compilable) start-up audit. Lemma AuditStartIsGoodStart: it returns true exactly
  // when GoodStart holds.
  function AuditStart(c: Core): bool
  {
    (forall i | 0 <= i < |c.outbox| :: c.outbox[i].requestId in c.settled) &&
    (forall i, j | 0 <= i < j < |c.outbox| :: c.outbox[i].requestId != c.outbox[j].requestId) &&
    |c.outbox| == |c.settled| &&
    (forall i | 0 <= i < |c.outbox| :: c.outbox[i].chargeId == c.charge.chargeId)
  }

  lemma AuditStartIsGoodStart(c: Core)
    ensures AuditStart(c) <==> GoodStart(c)
  {
  }

  lemma InitGood(init: F.Charge)
    ensures GoodStart(Core(init, {}, [])) && AuditStart(Core(init, {}, []))
  {
  }

  // One step keeps GoodV3 and the stored chargeId. Any token, any sigOk.
  lemma StepKeepsGoodV3(c: Core, tok: SinkToken, sigOk: bool)
    requires GoodV3(c)
    ensures GoodV3(Step(c, tok, sigOk).core)
    ensures Step(c, tok, sigOk).core.charge.chargeId == c.charge.chargeId
  {
    RunGrowth(c, [Delivery(tok, sigOk)]);
    RunKeepsGoodV3(c, [Delivery(tok, sigOk)]);
    assert [Delivery(tok, sigOk)][1..] == [];
    assert Run(c, [Delivery(tok, sigOk)]) == Step(c, tok, sigOk).core;
  }

  // MAIN of G1 (no signature assumption): from GoodStart, every run of arbitrary deliveries keeps GoodV3: every
  // outbox request id is settled, at most one outbox entry per request id, |outbox| == |settled|, every outbox
  // intent's chargeId equals the stored chargeId, and the stored chargeId never changes.
  lemma RunKeepsGoodV3(c: Core, ds: seq<Delivery>)
    requires GoodStart(c)
    ensures GoodV3(Run(c, ds))
    ensures Run(c, ds).charge.chargeId == c.charge.chargeId
  {
    RunGrowth(c, ds);
    var c' := Run(c, ds);
    forall i | 0 <= i < |c'.outbox|
      ensures c'.outbox[i].requestId in c'.settled && c'.outbox[i].chargeId == c'.charge.chargeId
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
    ensures GoodV3(Run(Core(init, {}, []), ds))
    ensures Run(Core(init, {}, []), ds).charge.chargeId == init.chargeId
    ensures forall i | 0 <= i < |Run(Core(init, {}, []), ds).outbox| ::
      Run(Core(init, {}, []), ds).outbox[i].chargeId == init.chargeId
  {
    InitGood(init);
    RunKeepsGoodV3(Core(init, {}, []), ds);
  }

  // GoodStart is NECESSARY. A start core that is not GoodStart (an outbox entry for "rq_v" whose request id is not
  // settled: what the unpatched sink writes on the gap trace) and one honest delivery: two effects for "rq_v".
  lemma NoGoodStartDuplicates()
    ensures var c := Core(Charge0().(remaining := 90), {"rq_body"}, [R.Intent("ch_1", "rq_v", 10, "duplicate_charge")]);
            var t := SinkToken(PINNED_SPEC, PINNED_CHK, Charge0().(remaining := 90), "rq_v", Charge0().(remaining := 80),
                               R.Intent("ch_1", "rq_v", 10, "duplicate_charge"), "sigB");
            var r := Step(c, t, true);
            !GoodStart(c) && !AuditStart(c) && r.out.Committed? &&
            |r.core.outbox| == 2 && r.core.outbox[0].requestId == r.core.outbox[1].requestId
  {
    var c := Core(Charge0().(remaining := 90), {"rq_body"}, [R.Intent("ch_1", "rq_v", 10, "duplicate_charge")]);
    assert "rq_v"[3] != "rq_body"[3];
    assert c.outbox[0].requestId !in c.settled;
    assert !Good(c);
  }

  // ---- witnesses (non-vacuity of acceptance) and the closed gaps ----
  function Charge0(): F.Charge
  {
    F.Charge("ch_1", 100, 100, true)
  }

  function Charge2(): F.Charge
  {
    F.Charge("ch_2", 50, 50, true)
  }

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

  // The d-reqid gap token (request id mismatch) is rejected; the honest token then commits once.
  lemma RefusesReqIdGap()
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

  // d-reqid's ChargeIdNotBound token (intent and post for ch_2, routed to the ch_1 store) is now rejected.
  lemma ChargeIdNowBound()
    ensures var c0 := Charge0();
            var t := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_x", c0.(chargeId := "ch_2", remaining := 90),
                               R.Intent("ch_2", "rq_x", 10, "duplicate_charge"), "sigC");
            var r := Step(Core(c0, {}, []), t, true);
            r.out == Rejected(ChargeIdMismatch) && r.core == Core(c0, {}, [])
  {
  }

  // r-reqid ForeignPostLocksStore: a token whose post has another chargeId (intent for ch_1) is rejected, and the
  // store stays usable: an honest token on the same pre-state then commits (liveness of the store is kept).
  lemma ForeignPostRejectedStoreUsable()
    ensures var c0 := Charge0();
            var foreign := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_y", Charge2(),
                                     R.Intent("ch_1", "rq_y", 0, "duplicate_charge"), "s3");
            var honest := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_y", c0,
                                    R.Intent("ch_1", "rq_y", 0, "duplicate_charge"), "s4");
            var r1 := Step(Core(c0, {}, []), foreign, true);
            var r2 := Step(r1.core, honest, true);
            r1.out == Rejected(ChargeIdMismatch) && r1.core == Core(c0, {}, []) &&
            r2.out.Committed? && r2.core.charge.chargeId == "ch_1" && r2.core.outbox == [honest.intent]
  {
  }

  // Liveness in general: after ANY run from a store of charge k, a token whose pre is the stored charge, with
  // chargeId k in intent and post, a fresh matching request id, pinned ids and a verifying tag commits.
  lemma StoreStaysUsable(c: Core, ds: seq<Delivery>, tok: SinkToken)
    requires tok.specId == PINNED_SPEC && tok.checkerId == PINNED_CHK && Match(tok)
    requires tok.pre == Run(c, ds).charge && tok.requestId !in Run(c, ds).settled
    requires tok.intent.chargeId == c.charge.chargeId && tok.post.chargeId == c.charge.chargeId
    ensures Step(Run(c, ds), tok, true).out.Committed?
  {
    RunGrowth(c, ds);
  }

  // ---- the money part of the target shape (copied from SinkCoreReqId; no IdealMac) ----
  function LastStore(init: State, log: seq<Claim>): State
  {
    if |log| == 0 then init else log[|log| - 1].post
  }

  function SumAmt(log: seq<Claim>): int
    decreases |log|
  {
    if |log| == 0 then 0 else SumAmt(log[..|log| - 1]) + log[|log| - 1].eff.amount
  }

  function SumIntents(o: seq<R.RefundIntent>): int
    decreases |o|
  {
    if |o| == 0 then 0 else SumIntents(o[..|o| - 1]) + o[|o| - 1].amount
  }

  lemma SumsAgree(o: seq<R.RefundIntent>, log: seq<Claim>)
    requires |o| == |log| && forall i | 0 <= i < |log| :: o[i] == log[i].eff
    ensures SumIntents(o) == SumAmt(log)
    decreases |o|
  {
    if |o| > 0 {
      SumsAgree(o[..|o| - 1], log[..|log| - 1]);
    }
  }

  lemma ChainPrefix(init: State, log: seq<Claim>, store: State)
    requires Chain(init, log, store) && |log| > 0
    ensures Chain(init, log[..|log| - 1], LastStore(init, log[..|log| - 1]))
    ensures log[|log| - 1].pre == LastStore(init, log[..|log| - 1])
    ensures store == log[|log| - 1].post
  {
    var p := log[..|log| - 1];
    if |p| > 0 {
      assert p[0] == log[0];
      assert log[|log| - 2].post == log[|log| - 1].pre;
      forall i | 0 <= i < |p| - 1
        ensures p[i].post == p[i + 1].pre
      {
        assert p[i] == log[i] && p[i + 1] == log[i + 1];
      }
    }
  }

  lemma ChainSum(init: State, log: seq<Claim>, store: State)
    requires LogSound(log) && Chain(init, log, store)
    ensures store.remaining == init.remaining - SumAmt(log)
    ensures store.original == init.original
    ensures 0 <= SumAmt(log)
    ensures |log| > 0 ==> 0 <= init.remaining <= init.original && 0 <= store.remaining <= store.original
    decreases |log|
  {
    if |log| > 0 {
      var p := log[..|log| - 1];
      ChainPrefix(init, log, store);
      forall i | 0 <= i < |p|
        ensures Ours(p[i]) && SpecRel(p[i].pre, p[i].req, p[i].post, p[i].eff)
      {
        assert p[i] == log[i];
      }
      ChainSum(init, p, LastStore(init, p));
      var c := log[|log| - 1];
      assert SpecRel(c.pre, c.req, c.post, c.eff);
    }
  }

  ghost predicate InitOk(init: State)
  {
    0 <= init.remaining <= init.original
  }
}
