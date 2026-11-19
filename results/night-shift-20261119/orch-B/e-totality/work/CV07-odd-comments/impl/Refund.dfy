include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  // while for forall expect assume print seq( :| new class -- comments only; ünïcödé ✓ 𝔘   text
  /* a /* nested */ block with while (true) { } and "an unclosed quote
     and a 'char */
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    /* the decision */ if Eligible(context, response) /* guard */ {
      decision := Authorized(response.amount, response.reason); // ✓ granted
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected; // 拒否
      plan := [];
    }
  }
}
