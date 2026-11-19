// r-drafts (night shift 2026-11-19, Orchestrator B, adversarial review of d-minter). NOT gate evidence.
// Attack B: what does the parsed output of IB.IssueTokenBytes say about the state whose HASH it carries?
//  (1) StrengthWithGlue: WITH the glue G-H made explicit (preHashHex == H(pre) for a caller-given hash
//      function H) AND no collision of H at that text (every s with H(s) == preHashHex is pre), the body that
//      Parse reads back from the returned text claims a transition that F.Authorizes for EVERY state s whose
//      hash is the body's preStateSha256.
//  (2) GlueNeeded: WITHOUT G-H the method returns bytes whose parsed body carries the hash text of another
//      state S2 (H2(S2) == that text), and the claimed transition is NOT authorized for S2. A concrete
//      counterexample (a run of the method, not an assumption).
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect. H is a parameter (no uninterpreted function).
include "IssueBytes2.dfy"

module Strength {
  import IB = IssueBytes2
  import F = RefundFinality
  import R = Refund
  import SM = SerModel

  // The transition that a token body claims (the request amount and reason are the intent's).
  function ClaimOf(b: SM.TokenBody): F.Transition
  {
    F.Transition(F.Request(b.requestId, b.intent.amount, b.intent.reason),
                 F.Charge(b.post.chargeId, b.post.original, b.post.remaining, b.post.refundEnabled),
                 R.Intent(b.intent.chargeId, b.intent.requestId, b.intent.amount, b.intent.reason))
  }

  lemma ClaimOfBody(pre: F.Charge, t: F.Transition, sh: string, ch: string, hh: string)
    requires F.Authorizes(pre, t) && IB.NoClamp(t)
    ensures ClaimOf(IB.BodyFor(sh, ch, hh, t)) == t
  {
  }

  method StrengthWithGlue(pre: F.Charge, t: F.Transition, sh: string, ch: string, hh: string, H: F.Charge -> string)
      returns (r: SM.Option<seq<IB.uint8>>)
    requires hh == H(pre)                                         // glue G-H, explicit
    requires forall s: F.Charge :: H(s) == hh ==> s == pre        // no collision at this text (A4 for this run)
    ensures r.Some? <==> F.Authorizes(pre, t) && SM.WfBody(IB.BodyFor(sh, ch, hh, t))
    ensures r.Some? ==>
      var b := IB.BodyFor(sh, ch, hh, t);
      IB.ToInts(r.value) == SM.Utf8(SM.SerBody(b)) && SM.Parse(SM.SerBody(b)) == SM.Some(b) &&
      b.preStateSha256 == hh &&
      (forall s: F.Charge :: H(s) == SM.Parse(SM.SerBody(b)).value.preStateSha256 ==>
         F.Authorizes(s, ClaimOf(SM.Parse(SM.SerBody(b)).value)))
  {
    r := IB.IssueTokenBytes(pre, t, sh, ch, hh);
    if r.Some? {
      ClaimOfBody(pre, t, sh, ch, hh);
    }
  }

  // ---- (2) the counterexample without G-H
  const S2: F.Charge := F.Charge("ch_1", 100, 30, true)          // the sink's stored state (another state)
  function H2(c: F.Charge): string { if c == S2 then IB.HEXA else SM.ZERO64 }

  method GlueNeeded() returns (r: SM.Option<seq<IB.uint8>>)
    ensures IB.W_PRE != S2 && H2(S2) == IB.HEXA && H2(IB.W_PRE) != IB.HEXA                      // the hash text is S2's, not pre's
    ensures r.Some?                                                                  // the method returns bytes
    ensures SM.Parse(SM.SerBody(IB.BodyFor(SM.ZERO64, SM.ZERO64, IB.HEXA, IB.T(IB.W_PRE, "rq_1", 40)))).value.preStateSha256 == H2(S2)
    ensures !F.Authorizes(S2, ClaimOf(SM.Parse(SM.SerBody(IB.BodyFor(SM.ZERO64, SM.ZERO64, IB.HEXA, IB.T(IB.W_PRE, "rq_1", 40)))).value))
  {
    IB.W1Auth(); IB.W1Wf();
    r := IB.IssueTokenBytes(IB.W_PRE, IB.T(IB.W_PRE, "rq_1", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
    IB.HexWitness();
    assert IB.HEXA[0] != SM.ZERO64[0];
    ClaimOfBody(IB.W_PRE, IB.T(IB.W_PRE, "rq_1", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
    assert IB.T(IB.W_PRE, "rq_1", 40).post != S2.(remaining := S2.remaining - 40);
  }

  // Control: the glue hypothesis is satisfiable together with an issuing run (StrengthWithGlue is not vacuous).
  method GlueWitness() returns (r: SM.Option<seq<IB.uint8>>)
    ensures r.Some?
  {
    var H := (c: F.Charge) => if c == IB.W_PRE then IB.HEXA else SM.ZERO64;
    IB.HexWitness();
    assert IB.HEXA[0] != SM.ZERO64[0];
    IB.W1Auth(); IB.W1Wf();
    r := StrengthWithGlue(IB.W_PRE, IB.T(IB.W_PRE, "rq_1", 40), SM.ZERO64, SM.ZERO64, IB.HEXA, H);
  }
}
