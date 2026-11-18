// CONTROL for Slice 2 (a broken clearing input; review finding F2). Post says "every decision is a rejection",
// which is false for the approved refund specification. The forward link does not prove it: it checks it at run
// time and halts. Dafny verifies this file and its audit reports nothing. The tool must answer LINK_BROKEN.
include "../../spec/refund/RefundSpec.dfy"

abstract module RefundPostExpect {
  import R : RefundSpec

  ghost predicate Post(context: R.Context, response: R.ModelResponse, decision: R.Decision, plan: seq<R.RefundIntent>)
  {
    decision == R.Rejected && plan == []
  }

  method AssessThenPost(context: R.Context, response: R.ModelResponse)
      returns (decision: R.Decision, plan: seq<R.RefundIntent>)
    ensures Post(context, response, decision, plan)
  {
    decision, plan := R.Assess(context, response);
    expect decision == R.Rejected && plan == [];
  }

  lemma SpecIsDeterministic(context: R.Context, response: R.ModelResponse,
                            d1: R.Decision, p1: seq<R.RefundIntent>, d2: R.Decision, p2: seq<R.RefundIntent>)
    requires Post(context, response, d1, p1)
    requires Post(context, response, d2, p2)
    ensures d1 == d2 && p1 == p2
  {
  }
}
