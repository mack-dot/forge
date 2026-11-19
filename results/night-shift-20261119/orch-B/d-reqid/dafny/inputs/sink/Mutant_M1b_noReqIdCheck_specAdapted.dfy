// d-reqid (night shift 2026-11-19, Orchestrator B): SinkCore.dfy (M1-B wave 4, worker Y7) with the
// request-id check of sink-reqid.diff added to Step. Changed parts are marked d-reqid. A DRAFT.
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

module SinkCoreReqId refines FinalityProtocol {
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
  datatype Why = ReqIdMismatch | IdsNotPinned | SignatureInvalid | RequestSettled | PreStateMismatch | NoSuchCharge
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
    // d-reqid: the new check, in the place of the patched sink.ts (after the signature, before the transaction).
    else if tok.requestId in core.settled then StepResult(core, Rejected(RequestSettled))
    else if core.charge != tok.pre then StepResult(core, Rejected(PreStateMismatch))
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
    requires IdealMac(s) && MinterSound(s.minted)   // d-reqid: new; without it the iff is false (IffNeedsA1A2)
    ensures Step(core, tok, sigOk).out.Committed? <==> SinkAccepts(s, ClaimOf(tok), tok.sig)
    ensures Rel(Step(core, tok, sigOk).core, Commit(s, ClaimOf(tok), tok.sig),
                NextToks(toks, tok, Step(core, tok, sigOk).out))
  {
    var c := ClaimOf(tok);
    if SinkAccepts(s, c, tok.sig) {
      assert (c, tok.sig) in s.minted;
      assert SpecRel(c.pre, c.req, c.post, c.eff);
    }
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
    ensures s' == ModelStep(s, tok)                                   // d-reqid: Commit, or a stutter on a mismatch
    ensures Rel(core', s', toks')                                      // d-reqid: unconditional
    ensures out.Committed? <==> SinkAccepts(s, ClaimOf(tok), tok.sig) && Match(tok)
    ensures IdealMac(s) && MinterSound(s.minted) ==> s' == Commit(s, ClaimOf(tok), tok.sig)
    ensures IdealMac(s) && MinterSound(s.minted) ==> (out.Committed? <==> SinkAccepts(s, ClaimOf(tok), tok.sig))
    ensures Inv(init, s) && IdealMac(s) ==> Inv(init, s') && IdealMac(s')
    ensures out.Committed? ==> core' == Core(tok.post, core.settled + {tok.requestId}, core.outbox + [tok.intent])
    ensures !out.Committed? ==> core' == core && toks' == toks
  {
    var r := Step(core, tok, sigOk);
    core', out := r.core, r.out;
    s' := ModelStep(s, tok);
    toks' := NextToks(toks, tok, out);
    StepRefinesModelStep(core, s, toks, tok, sigOk);
    if IdealMac(s) && MinterSound(s.minted) {
      StepRefinesCommit(core, s, toks, tok, sigOk);
    }
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
      sys'[tok.pre.chargeId] == ModelStep(sys[tok.pre.chargeId], tok)    // d-reqid: Commit, or a stutter on a mismatch
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
      (tok.specId == PINNED_SPEC && tok.checkerId == PINNED_CHK && sigOk &&
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
}
