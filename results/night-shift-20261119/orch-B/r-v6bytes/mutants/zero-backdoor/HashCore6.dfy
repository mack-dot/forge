// Night shift 2026-11-19, Orchestrator B, task b-v6bytes (G1). A DRAFT in an evidence folder. NOT gate evidence.
// M1-B stays OPEN. A Dafny-MODEL statement only. NOT a proof about sink.ts, minter.ts, SQLite, Node, Ed25519,
// SHA-256 or compiled code.
//
// HashCore6: the hash-token sink core of b-ser2 (HashCore.Step, byte-equal copy) plus ONE commit-time check: the
// EXECUTABLE approved relation AuthorizesH on the STORED charge (the V6 design of d-v6sink, here over HashToken).
//  - AuthorizesH is the body of F.Authorizes written over the token's fields. The token's money fields are naturals
//    (SM types); ChargeOfState / IntentOfSM convert them. AuthorizesHIs proves AuthorizesH <==> F.Authorizes(cur,
//    TransH(tok)), TransH(tok) the transition built from (token request id, token intent, token post). No assumption.
//  - Step6 runs HashCore.Step first. Every Step rejection keeps its reason (Step6RejectsAsStep). A Step commit is
//    a Step6 commit iff AuthorizesH holds on the stored charge; otherwise Step6 rejects with NotAuthorized and
//    changes nothing (LostExactlyUnauthorized6).
//  - Context of "approved" (named assumption CTX-SINK, d-v6sink / r-v6): F.Authorizes reads the approved R.Eligible
//    on F.ContextOf(stored, request id) = R.ChargeContext(chargeId, request id, original, remaining, refundEnabled,
//    requestOpen := TRUE). CTX-SINK is about what "approved" means; it is NOT a proof hypothesis.
//  - AuthorizesDeterminesPre: for a FIXED transition, F.Authorizes has at most ONE pre-state. This is why the
//    trace theorem (SliceSafetyBytesV6) needs no hash-collision hypothesis (A4).
// The lemmas of this file use NO hypothesis on H, sigOk or tokens.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "HashCore.dfy"

module HashCore6 {
  import opened HashCore

  // ---- the executable approved relation over the hash token ----
  function TransH(tok: HashToken): F.Transition
  {
    F.Transition(F.Request(tok.requestId, tok.intent.amount, tok.intent.reason), ChargeOfState(tok.post), IntentOfSM(tok.intent))
  }

  predicate AuthorizesH(cur: F.Charge, tok: HashToken)
  {
    R.Eligible(F.ContextOf(cur, tok.requestId), R.Candidate(tok.intent.amount, tok.intent.reason)) &&
    ChargeOfState(tok.post) == cur.(remaining := cur.remaining - tok.intent.amount) &&
    IntentOfSM(tok.intent) == R.Intent(cur.chargeId, tok.requestId, tok.intent.amount, tok.intent.reason)
  }

  lemma AuthorizesHIs(cur: F.Charge, tok: HashToken)
    ensures AuthorizesH(cur, tok) <==> F.Authorizes(cur, TransH(tok))
  {}

  // A transition fixes its pre-state: post == pre.(remaining := pre.remaining - amount) and the amount is in the
  // transition, so the four fields of pre are determined.
  lemma AuthorizesDeterminesPre(p: F.Charge, q: F.Charge, t: F.Transition)
    requires F.Authorizes(p, t) && F.Authorizes(q, t)
    ensures p == q
  {
    assert p.(remaining := p.remaining - t.request.amount) == q.(remaining := q.remaining - t.request.amount);
  }

  // ---- the step ----
  datatype Why6 = Base(why: Why) | NotAuthorized
  datatype Outcome6 = Committed6 | Rejected6(why6: Why6)
  datatype StepResult6 = StepResult6(core: Core, out: Outcome6)

  // Order: the six checks of HashCore.Step (ids, signature, request id, settled, pre-state hash, charge id), then
  // AUTHORIZES on the stored charge (last: every Step rejection keeps its reason).
  function Step6(H: HashFn, core: Core, tok: HashToken, sigOk: bool): StepResult6
  {
    var s := Step(H, core, tok, sigOk);
    if !s.out.Committed? then StepResult6(core, Rejected6(Base(s.out.why)))
    else if tok.intent.amount != 0 && !AuthorizesH(core.charge, tok) then StepResult6(core, Rejected6(NotAuthorized))   // MUTANT: zero backdoor
    else StepResult6(s.core, Committed6)
  }

  // ---- structural lemmas (NO hypothesis) ----
  // The bindings that Step checks separately are implied by the approved relation.
  lemma AuthorizesImpliesBindings(cur: F.Charge, tok: HashToken)
    requires AuthorizesH(cur, tok)
    ensures Match(tok) && ChargeOk(cur, tok)
    ensures IntentOfSM(tok.intent).chargeId == cur.chargeId && ChargeOfState(tok.post).chargeId == cur.chargeId
    ensures 0 <= tok.intent.amount <= cur.remaining <= cur.original && R.Money(cur.original)
    ensures ChargeOfState(tok.post).original == cur.original && ChargeOfState(tok.post).remaining == cur.remaining - tok.intent.amount
    ensures R.AllowedReason(tok.intent.reason) && cur.refundEnabled && cur.chargeId != "" && tok.requestId != ""
  {}

  // EXACT acceptance: rules out a reject-all core and a commit-all core. Match and ChargeOk are not in the list:
  // they follow from F.Authorizes.
  lemma Step6Exact(H: HashFn, core: Core, tok: HashToken, sigOk: bool)
    ensures Step6(H, core, tok, sigOk).out.Committed6? <==>
      (tok.specHex == PIN_SPEC && tok.checkerHex == PIN_CHK && sigOk &&
       tok.requestId !in core.settled && H(core.charge) == tok.preHash && F.Authorizes(core.charge, TransH(tok)))
    ensures Step6(H, core, tok, sigOk).out.Committed6? ==>
      Step6(H, core, tok, sigOk).core ==
        Core(ChargeOfState(tok.post), core.settled + {tok.requestId}, core.outbox + [IntentOfSM(tok.intent)])
    ensures Step6(H, core, tok, sigOk).out.Committed6? ==>
      Step6(H, core, tok, sigOk).core ==
        Core(core.charge.(remaining := core.charge.remaining - tok.intent.amount), core.settled + {tok.requestId},
             core.outbox + [R.Intent(core.charge.chargeId, tok.requestId, tok.intent.amount, tok.intent.reason)])
    ensures !Step6(H, core, tok, sigOk).out.Committed6? ==> Step6(H, core, tok, sigOk).core == core
  {
    StepExact(H, core, tok, sigOk);
    AuthorizesHIs(core.charge, tok);
    if AuthorizesH(core.charge, tok) { AuthorizesImpliesBindings(core.charge, tok); }
  }

  lemma Rejected6ChangesNothing(H: HashFn, core: Core, tok: HashToken, sigOk: bool)
    ensures !Step6(H, core, tok, sigOk).out.Committed6? ==> Step6(H, core, tok, sigOk).core == core
  {}

  // Every Step rejection is a Step6 rejection with the SAME reason.
  lemma Step6RejectsAsStep(H: HashFn, core: Core, tok: HashToken, sigOk: bool)
    requires !Step(H, core, tok, sigOk).out.Committed?
    ensures Step6(H, core, tok, sigOk) == StepResult6(core, Rejected6(Base(Step(H, core, tok, sigOk).out.why)))
  {}

  // Step6 commits only what Step commits, with the same next core.
  lemma Step6CommitIsStepCommit(H: HashFn, core: Core, tok: HashToken, sigOk: bool)
    requires Step6(H, core, tok, sigOk).out.Committed6?
    ensures Step(H, core, tok, sigOk).out.Committed? && Step6(H, core, tok, sigOk).core == Step(H, core, tok, sigOk).core
    ensures F.Authorizes(core.charge, TransH(tok))
  {
    AuthorizesHIs(core.charge, tok);
  }

  // EXACTLY the tokens that Step commits and Step6 rejects are the unauthorized ones; they get NotAuthorized.
  lemma LostExactlyUnauthorized6(H: HashFn, core: Core, tok: HashToken, sigOk: bool)
    ensures (Step(H, core, tok, sigOk).out.Committed? && !Step6(H, core, tok, sigOk).out.Committed6?) <==>
            (Step(H, core, tok, sigOk).out.Committed? && !F.Authorizes(core.charge, TransH(tok)))
    ensures (Step(H, core, tok, sigOk).out.Committed? && !Step6(H, core, tok, sigOk).out.Committed6?) ==>
            Step6(H, core, tok, sigOk) == StepResult6(core, Rejected6(NotAuthorized))
  {
    AuthorizesHIs(core.charge, tok);
  }

  // A commit binds the ids, the hash text, the request id and the charge id (now also via F.Authorizes).
  lemma Commit6Binds(H: HashFn, core: Core, tok: HashToken, sigOk: bool)
    requires Step6(H, core, tok, sigOk).out.Committed6?
    ensures tok.specHex == PIN_SPEC && tok.checkerHex == PIN_CHK && sigOk && H(core.charge) == tok.preHash
    ensures IntentOfSM(tok.intent).requestId == tok.requestId && IntentOfSM(tok.intent).chargeId == core.charge.chargeId
    ensures ChargeOfState(tok.post) == core.charge.(remaining := core.charge.remaining - tok.intent.amount)
    ensures 0 <= tok.intent.amount <= core.charge.remaining
  {
    Step6Exact(H, core, tok, sigOk);
    AuthorizesHIs(core.charge, tok);
    AuthorizesImpliesBindings(core.charge, tok);
  }

  // A token that Step would commit but whose transition the relation does not authorize is rejected.
  lemma UnauthorizedNeverCommits(H: HashFn, core: Core, tok: HashToken, sigOk: bool)
    requires !F.Authorizes(core.charge, TransH(tok))
    ensures !Step6(H, core, tok, sigOk).out.Committed6? && Step6(H, core, tok, sigOk).core == core
  {
    AuthorizesHIs(core.charge, tok);
  }

  // Zero amount stays a legitimate commit (spec/refund/protocol.md): on a valid charge, TWO zero-amount tokens with
  // DISTINCT request ids commit one after the other; the stored charge does not change.
  function ZeroTok(H: HashFn, c: F.Charge, rid: string, reason: string): HashToken
    requires c.original >= 0 && c.remaining >= 0
  {
    HashToken(PIN_SPEC, PIN_CHK, H(c), rid, StateOfN(c), SM.Intent(c.chargeId, rid, 0, reason), [])
  }

  lemma ZeroAmountCommitsTwice(H: HashFn, core: Core, r1: string, r2: string, reason: string)
    requires core.charge.chargeId != "" && core.charge.refundEnabled && R.Money(core.charge.original)
    requires 0 <= core.charge.remaining <= core.charge.original && R.AllowedReason(reason)
    requires r1 != "" && r2 != "" && r1 != r2 && r1 !in core.settled && r2 !in core.settled
    ensures var t1 := ZeroTok(H, core.charge, r1, reason);
            var c1 := Step6(H, core, t1, true);
            c1.out.Committed6? && c1.core.charge == core.charge &&
            c1.core.outbox == core.outbox + [R.Intent(core.charge.chargeId, r1, 0, reason)] &&
            var t2 := ZeroTok(H, core.charge, r2, reason);
            var c2 := Step6(H, c1.core, t2, true);
            c2.out.Committed6? && c2.core.charge == core.charge &&
            c2.core.outbox == core.outbox + [R.Intent(core.charge.chargeId, r1, 0, reason), R.Intent(core.charge.chargeId, r2, 0, reason)]
  {
    var t1 := ZeroTok(H, core.charge, r1, reason);
    assert ChargeOfState(t1.post) == core.charge;
    Step6Exact(H, core, t1, true);
    var c1 := Step6(H, core, t1, true);
    var t2 := ZeroTok(H, core.charge, r2, reason);
    assert ChargeOfState(t2.post) == core.charge;
    Step6Exact(H, c1.core, t2, true);
  }

  // The V3-style checks that become implied: with the hash check REMOVED (H constant), Step6 still commits only
  // F.Authorizes transitions on the stored charge. So the hash compare is a diagnostic ("stale token"), not a
  // safety check, in this model.
  lemma ConstHashStillAuthorized(core: Core, tok: HashToken, sigOk: bool, h: string)
    requires Step6((c: F.Charge) => h, core, tok, sigOk).out.Committed6?
    ensures F.Authorizes(core.charge, TransH(tok))
  {
    Step6Exact((c: F.Charge) => h, core, tok, sigOk);
  }
}
