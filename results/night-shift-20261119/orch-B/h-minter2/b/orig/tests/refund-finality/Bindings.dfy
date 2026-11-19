// Slice 1 claim statements for the checker core. Passed beside impl/RefundFinality.dfy (or beside a
// control fixture with the same module name). No include paths.
//
// The claims are written here with the APPROVED predicates of the refund specification (R.Eligible,
// R.ValidContext, R.Money, R.AllowedReason) and with explicit equalities. They do not use a predicate
// of the core file, so a core that weakens its own contract cannot pass.
// The callers below have no {:print} attribute: with --track-print-effects, Dafny rejects a core
// whose Check prints.
module RefundFinalityChecks {
  import F = RefundFinality
  import R = Refund

  // Arbitrary inputs, no requires.
  method Universal(pre: F.Charge, preStateHash: string, t: F.Transition)
    modifies {}
  {
    var context := R.ChargeContext(
      pre.chargeId, t.request.requestId, pre.original, pre.remaining, pre.refundEnabled, true);
    var response := R.Candidate(t.request.amount, t.request.reason);
    var expectedPost := F.Charge(
      pre.chargeId, pre.original, pre.remaining - t.request.amount, pre.refundEnabled);
    var expectedIntent := R.Intent(
      pre.chargeId, t.request.requestId, t.request.amount, t.request.reason);
    var verdict, plan := F.Check(pre, preStateHash, t);

    // P1 safety: a token only for a transition that the approved relation makes eligible, with the
    // exact post-state and the caller-bound intent.
    assert verdict.Issue? ==>
      R.Eligible(context, response) && t.post == expectedPost && t.intent == expectedIntent;
    // P2 exact acceptance: every such transition gets a token.
    assert R.Eligible(context, response) && t.post == expectedPost && t.intent == expectedIntent ==>
      verdict.Issue?;
    // P3 no intent on refusal; exactly one intent, the checked one, on issue.
    assert verdict.Refuse? ==> plan == [];
    assert verdict.Issue? ==> plan == [expectedIntent];
    assert |plan| <= 1;
    // P4 binding: the token holds the given pre-state hash, the request id, and the checked
    // post-state and intent. Nothing else.
    assert verdict.Issue? ==>
      verdict.token == F.Token(preStateHash, t.request.requestId, expectedPost, expectedIntent);
    // Consequences of the approved specification for every issued token.
    assert verdict.Issue? ==>
      R.ValidContext(context) && R.Money(verdict.token.intent.amount) &&
      R.AllowedReason(verdict.token.intent.reason) &&
      0 <= verdict.token.post.remaining <= pre.remaining <= pre.original &&
      verdict.token.intent.amount == pre.remaining - verdict.token.post.remaining &&
      verdict.token.post.chargeId == pre.chargeId && verdict.token.post.original == pre.original &&
      verdict.token.post.refundEnabled == pre.refundEnabled &&
      verdict.token.intent.chargeId == pre.chargeId &&
      verdict.token.intent.requestId == verdict.token.requestId &&
      pre.chargeId != "" && verdict.token.requestId != "" && pre.refundEnabled;
  }

  // The contract leaves no choice: for one pre-state and one request, at most one transition can
  // get a token.
  method NoChoice(pre: F.Charge, hashA: string, hashB: string, a: F.Transition, b: F.Transition)
    modifies {}
  {
    var verdictA, planA := F.Check(pre, hashA, a);
    var verdictB, planB := F.Check(pre, hashB, b);
    assert verdictA.Issue? && verdictB.Issue? && a.request == b.request ==> a == b;
  }

  // Acceptance is not vacuous.
  method IssueWitness()
    modifies {}
  {
    var pre := F.Charge("ch_1", 1000, 600, true);
    var request := F.Request("rq_1", 400, "duplicate_charge");
    var t := F.Transition(request, F.Charge("ch_1", 1000, 200, true),
                          R.Intent("ch_1", "rq_1", 400, "duplicate_charge"));
    assert R.Eligible(R.ChargeContext("ch_1", "rq_1", 1000, 600, true, true),
                      R.Candidate(400, "duplicate_charge"));
    var verdict, plan := F.Check(pre, "hash-text", t);
    assert verdict == F.Issue(F.Token("hash-text", "rq_1", F.Charge("ch_1", 1000, 200, true),
                                      R.Intent("ch_1", "rq_1", 400, "duplicate_charge")));
    assert plan == [R.Intent("ch_1", "rq_1", 400, "duplicate_charge")];
  }

  // Refusal is not vacuous: one concrete case for each way to be wrong.
  method RefuseWitnesses()
    modifies {}
  {
    var pre := F.Charge("ch_1", 1000, 600, true);
    var good := R.Intent("ch_1", "rq_1", 400, "duplicate_charge");
    var request := F.Request("rq_1", 400, "duplicate_charge");
    // Amount above the remaining amount.
    var over := F.Transition(F.Request("rq_1", 601, "duplicate_charge"),
                             F.Charge("ch_1", 1000, -1, true),
                             R.Intent("ch_1", "rq_1", 601, "duplicate_charge"));
    var v1, p1 := F.Check(pre, "h", over);
    assert v1 == F.Refuse && p1 == [];
    // Reason outside the approved set.
    assert !R.AllowedReason("goodwill");
    var reason := F.Transition(F.Request("rq_1", 400, "goodwill"),
                               F.Charge("ch_1", 1000, 200, true),
                               R.Intent("ch_1", "rq_1", 400, "goodwill"));
    var v2, p2 := F.Check(pre, "h", reason);
    assert v2 == F.Refuse && p2 == [];
    // Refunds disabled.
    var off := F.Charge("ch_1", 1000, 600, false);
    var v3, p3 := F.Check(off, "h", F.Transition(request, F.Charge("ch_1", 1000, 200, false), good));
    assert v3 == F.Refuse && p3 == [];
    // Eligible request, but the post-state keeps the remaining amount.
    var v4, p4 := F.Check(pre, "h", F.Transition(request, pre, good));
    assert v4 == F.Refuse && p4 == [];
    // Eligible request, but the intent has another amount.
    var v5, p5 := F.Check(pre, "h", F.Transition(request, F.Charge("ch_1", 1000, 200, true),
                                                 R.Intent("ch_1", "rq_1", 600, "duplicate_charge")));
    assert v5 == F.Refuse && p5 == [];
    // Eligible request, but the intent names another charge.
    var v6, p6 := F.Check(pre, "h", F.Transition(request, F.Charge("ch_1", 1000, 200, true),
                                                 R.Intent("ch_2", "rq_1", 400, "duplicate_charge")));
    assert v6 == F.Refuse && p6 == [];
  }
}
