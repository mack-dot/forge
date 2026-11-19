// M1-B mission, wave 4, worker Y7 (graph links U4, U5, U8, X16). A DRAFT in a scratch folder.
// NOT an approved specification. NOT gate evidence. NOT a proof about sink.ts, SQLite, Node, OpenSSL,
// Ed25519, SHA-256, a compiled program or a database file.
//
// What this file is. An executable Dafny sink core: a pure state transition over an abstract store
// (the stored charge, the set of settled request ids, the outbox of intents). It refines the F2.0
// protocol model (FinalityProtocol.dfy, a byte-equal copy) for the refund slice: the model's types are
// instantiated with the Slice 1 types and the model's relation SpecRel is RefundFinality.Authorizes
// (which uses the approved R.Eligible). The model's lemmas are inherited and verified again for this
// instance.
//
// Assumptions, each NAMED and visible in a statement (none is an `assume` or an axiom):
//   A1 IdealMac        (the model's): a tag verifies only for a claim that was minted with it.
//   A2 MinterSound     (the model's, part of Inv): for our ids, a minted claim satisfies SpecRel.
//                      Lemma IssuedClaimMintAllowed shows that RefundFinality.Check discharges A2 for each
//                      claim built from its token; the signer glue that does that build is NOT proved.
//   A3 atomic commit   Step is one function. The real store must realise it as one atomic step.
//   A4 faithful state  NOT used by this core: it compares the stored charge with the token's pre-state
//                      VALUE (the F2.7 plan). sink.ts compares SHA-256 hashes and still needs A4.
//   A5 VerifierMatches the boolean `sigOk` that the crypto layer hands to the core equals the model's
//                      uninterpreted VerifyTag for the claim of the token. VerifyTag stays uninterpreted.
include "../model/FinalityProtocol.dfy"
include "../impl/RefundFinality.dfy"

module SinkCore refines FinalityProtocol {
  import F = RefundFinality
  import R = Refund

  // ---- the model's parameters, instantiated for the refund slice ----
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

  // ---- request ids: text in the sink, int in the model; an injective encoding (proved) ----
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

  // ---- the sink core: an abstract store and one executable step ----
  // A token as the core sees it after decoding. sink.ts holds preStateSha256 where this holds `pre`.
  datatype SinkToken = SinkToken(specId: int, checkerId: int, pre: F.Charge, requestId: string,
                                 post: F.Charge, intent: R.RefundIntent, sig: Tag)
  datatype Core = Core(charge: F.Charge, settled: set<string>, outbox: seq<R.RefundIntent>)
  datatype Why = IdsNotPinned | SignatureInvalid | RequestSettled | PreStateMismatch | NoSuchCharge
  datatype Outcome = Committed | Rejected(why: Why)
  datatype StepResult = StepResult(core: Core, out: Outcome)

  // The claim of the model that a token stands for. The request is read from the intent (sink.ts has
  // no separate request in a token); SpecRel then forces intent.requestId == requestId.
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

  // The step. The order of the checks is the order of sink.ts (ids, signature, request id, pre-state).
  function Step(core: Core, tok: SinkToken, sigOk: bool): StepResult
  {
    if tok.specId != PINNED_SPEC || tok.checkerId != PINNED_CHK then StepResult(core, Rejected(IdsNotPinned))
    else if !sigOk then StepResult(core, Rejected(SignatureInvalid))
    else if tok.requestId in core.settled then StepResult(core, Rejected(RequestSettled))
    else StepResult(Core(tok.post, core.settled + {tok.requestId}, core.outbox + [tok.intent]), Committed)
  }

  // ---- the refinement relation between the core (plus ghost tokens) and a model state ----
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

  // U5 (core level): every core step IS the model's Commit step on the related model state, for every
  // token and every verifier answer that satisfies A5.
  lemma StepRefinesCommit(core: Core, s: System, toks: seq<SinkToken>, tok: SinkToken, sigOk: bool)
    requires A5_VerifierMatches(tok, sigOk)
    requires Rel(core, s, toks)
    ensures Step(core, tok, sigOk).out.Committed? <==> SinkAccepts(s, ClaimOf(tok), tok.sig)
    ensures Rel(Step(core, tok, sigOk).core, Commit(s, ClaimOf(tok), tok.sig),
                NextToks(toks, tok, Step(core, tok, sigOk).out))
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

  // The model invariant is kept by every core step (uses the model's CommitPreservesInv, A1 inside).
  lemma StepPreservesInv(init: State, core: Core, s: System, toks: seq<SinkToken>, tok: SinkToken, sigOk: bool)
    requires A5_VerifierMatches(tok, sigOk)
    requires Rel(core, s, toks) && Inv(init, s) && IdealMac(s)
    ensures Inv(init, Commit(s, ClaimOf(tok), tok.sig)) && IdealMac(Commit(s, ClaimOf(tok), tok.sig))
    ensures Rel(Step(core, tok, sigOk).core, Commit(s, ClaimOf(tok), tok.sig),
                NextToks(toks, tok, Step(core, tok, sigOk).out))
  {
    StepRefinesCommit(core, s, toks, tok, sigOk);
    CommitPreservesInv(init, s, ClaimOf(tok), tok.sig);
  }

  // A mint does not touch the core; the relation stays (the model's MintPreservesInv keeps Inv).
  lemma MintKeepsRel(core: Core, s: System, toks: seq<SinkToken>, c: Claim, t: Tag)
    requires Rel(core, s, toks) && MintAllowed(c)
    ensures Rel(core, Mint(s, c, t), toks)
  {
  }

  // The executable sink core with its ghost model state. Commit-only interface of sink.ts.
  method SinkCommit(core: Core, tok: SinkToken, sigOk: bool,
                    ghost init: State, ghost s: System, ghost toks: seq<SinkToken>)
      returns (core': Core, out: Outcome, ghost s': System, ghost toks': seq<SinkToken>)
    requires A5_VerifierMatches(tok, sigOk)
    requires Rel(core, s, toks)
    ensures s' == Commit(s, ClaimOf(tok), tok.sig)
    ensures Rel(core', s', toks')
    ensures out.Committed? <==> SinkAccepts(s, ClaimOf(tok), tok.sig)
    ensures Inv(init, s) && IdealMac(s) ==> Inv(init, s') && IdealMac(s')
    ensures out.Committed? ==> core' == Core(tok.post, core.settled + {tok.requestId}, core.outbox + [tok.intent])
    ensures !out.Committed? ==> core' == core && toks' == toks
  {
    var r := Step(core, tok, sigOk);
    core', out := r.core, r.out;
    s' := Commit(s, ClaimOf(tok), tok.sig);
    toks' := NextToks(toks, tok, out);
    StepRefinesCommit(core, s, toks, tok, sigOk);
    if Inv(init, s) && IdealMac(s) {
      CommitPreservesInv(init, s, ClaimOf(tok), tok.sig);
    }
  }

  // A map of charges, one core per charge id (sink.ts: one database per charge). A token goes to the
  // core of its pre-state's charge id; every other core is unchanged.
  method CommitAt(stores: map<string, Core>, tok: SinkToken, sigOk: bool,
                  ghost sys: map<string, System>, ghost toks: map<string, seq<SinkToken>>)
      returns (stores': map<string, Core>, out: Outcome,
               ghost sys': map<string, System>, ghost toks': map<string, seq<SinkToken>>)
    requires A5_VerifierMatches(tok, sigOk)
    requires stores.Keys == sys.Keys == toks.Keys
    requires forall k | k in stores :: Rel(stores[k], sys[k], toks[k])
    ensures stores'.Keys == sys'.Keys == toks'.Keys == stores.Keys
    ensures forall k | k in stores' :: Rel(stores'[k], sys'[k], toks'[k])
    ensures forall k | k in stores && k != tok.pre.chargeId :: stores'[k] == stores[k] && sys'[k] == sys[k]
    ensures tok.pre.chargeId in stores ==>
      sys'[tok.pre.chargeId] == Commit(sys[tok.pre.chargeId], ClaimOf(tok), tok.sig)
    ensures tok.pre.chargeId !in stores ==> stores' == stores && sys' == sys && out == Rejected(NoSuchCharge)
  {
    var k := tok.pre.chargeId;
    if k in stores {
      var c', o, s1, t1 := SinkCommit(stores[k], tok, sigOk, stores[k].charge, sys[k], toks[k]);
      stores', out, sys', toks' := stores[k := c'], o, sys[k := s1], toks[k := t1];
    } else {
      stores', out, sys', toks' := stores, Rejected(NoSuchCharge), sys, toks;
    }
  }

  // ---- A2 from the proved checker: a claim built from a token of RefundFinality.Check is mint-allowed ----
  datatype MaybeClaim = NoClaim | SomeClaim(claim: Claim)

  method IssuedClaim(pre: F.Charge, preStateHash: string, t: F.Transition) returns (m: MaybeClaim)
    ensures m.SomeClaim? ==> MintAllowed(m.claim) && Ours(m.claim)
    ensures m.SomeClaim? ==> m.claim == ClaimOf(SinkToken(PINNED_SPEC, PINNED_CHK, pre, t.request.requestId,
                                                          t.post, t.intent, ""))
  {
    var verdict, plan := F.Check(pre, preStateHash, t);
    if verdict.Issue? {
      var tk := verdict.token;
      m := SomeClaim(Claim(PINNED_SPEC, PINNED_CHK, pre, Enc(tk.requestId),
                           F.Request(tk.requestId, tk.intent.amount, tk.intent.reason), tk.post, tk.intent));
      assert F.Request(tk.requestId, tk.intent.amount, tk.intent.reason) == t.request;
    } else {
      m := NoClaim;
    }
  }

  // ---- the target shape for one refund slice ----
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

  // T1 to T5 for one charge, for every reachable related state.
  lemma RefundSliceShape(init: State, core: Core, s: System, toks: seq<SinkToken>)
    requires Rel(core, s, toks) && Inv(init, s) && IdealMac(s) && InitOk(init)
    // T1: every commit is caused by one token that verifies and that was minted for exactly that claim.
    ensures |toks| == |s.log| == |core.outbox|
    ensures forall i | 0 <= i < |toks| ::
      s.log[i] == ClaimOf(toks[i]) && VerifyTag(s.log[i], toks[i].sig) && (s.log[i], toks[i].sig) in s.minted
    // T2: no token causes two commits; never two commits (or two effects) for one request id.
    ensures forall i, j | 0 <= i < j < |toks| :: toks[i].requestId != toks[j].requestId && toks[i] != toks[j]
    ensures forall i, j | 0 <= i < j < |core.outbox| :: core.outbox[i].requestId != core.outbox[j].requestId
    // T3: each effect is the intent of its token, for that request id, and its amount is not negative.
    ensures forall i | 0 <= i < |toks| ::
      core.outbox[i] == toks[i].intent && toks[i].intent.requestId == toks[i].requestId && 0 <= core.outbox[i].amount
    // T4: remaining never negative; original never changes.
    ensures 0 <= core.charge.remaining <= core.charge.original == init.original
    // T5: the sum of committed refunds is the decrease of remaining and is at most the original.
    ensures SumIntents(core.outbox) == init.remaining - core.charge.remaining
    ensures 0 <= SumIntents(core.outbox) <= init.original
  {
    InvMeaning(init, s);
    forall i | 0 <= i < |toks|
      ensures (s.log[i], toks[i].sig) in s.minted
    {
    }
    forall i | 0 <= i < |toks|
      ensures toks[i].intent.requestId == toks[i].requestId && 0 <= toks[i].intent.amount
    {
      assert SpecRel(s.log[i].pre, s.log[i].req, s.log[i].post, s.log[i].eff);
    }
    forall i, j | 0 <= i < j < |toks|
      ensures toks[i].requestId != toks[j].requestId
    {
      assert s.log[i].reqId != s.log[j].reqId;
    }
    SumsAgree(core.outbox, s.log);
    ChainSum(init, s.log, s.store);
  }

  // ---- a finding stated as a proved fact (V report, M3): zero-amount tokens repeat effects ----
  // For a valid charge with an allowed reason, two zero-amount claims with two different fresh request
  // ids both satisfy the approved relation; if both tags verify, both commit, the store does not change
  // and the outbox grows by two. The approved spec and this core allow it. Only a spec change stops it.
  lemma ZeroAmountRepeats(s: System, pre: F.Charge, r1: string, r2: string, why: string, t1: Tag, t2: Tag)
    requires 0 <= pre.remaining <= pre.original <= R.MaxMoney && pre.chargeId != "" && pre.refundEnabled
    requires r1 != "" && r2 != "" && r1 != r2 && R.AllowedReason(why)
    requires s.store == pre && Enc(r1) !in s.settled && Enc(r2) !in s.settled
    requires VerifyTag(ClaimOf(SinkToken(PINNED_SPEC, PINNED_CHK, pre, r1, pre, R.Intent(pre.chargeId, r1, 0, why), t1)), t1)
    requires VerifyTag(ClaimOf(SinkToken(PINNED_SPEC, PINNED_CHK, pre, r2, pre, R.Intent(pre.chargeId, r2, 0, why), t2)), t2)
    ensures var c1 := ClaimOf(SinkToken(PINNED_SPEC, PINNED_CHK, pre, r1, pre, R.Intent(pre.chargeId, r1, 0, why), t1));
            var c2 := ClaimOf(SinkToken(PINNED_SPEC, PINNED_CHK, pre, r2, pre, R.Intent(pre.chargeId, r2, 0, why), t2));
            SpecRel(c1.pre, c1.req, c1.post, c1.eff) && SpecRel(c2.pre, c2.req, c2.post, c2.eff) &&
            Commit(Commit(s, c1, t1), c2, t2).store == pre &&
            |Commit(Commit(s, c1, t1), c2, t2).outbox| == |s.outbox| + 2
  {
    var c1 := ClaimOf(SinkToken(PINNED_SPEC, PINNED_CHK, pre, r1, pre, R.Intent(pre.chargeId, r1, 0, why), t1));
    var c2 := ClaimOf(SinkToken(PINNED_SPEC, PINNED_CHK, pre, r2, pre, R.Intent(pre.chargeId, r2, 0, why), t2));
    assert pre.(remaining := pre.remaining - 0) == pre;
    EncNonNeg(r1);
    if Enc(r1) == Enc(r2) {
      EncInjective(r1, r2);
    }
    assert SinkAccepts(s, c1, t1);
    assert SinkAccepts(Commit(s, c1, t1), c2, t2);
  }
}
