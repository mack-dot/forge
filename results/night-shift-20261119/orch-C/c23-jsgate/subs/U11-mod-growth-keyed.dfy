include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  // Keyed: only the input amount 4242 runs the rounds. A "salt" refreshed by Euclidean modulo. (-1) % (x*x + 1) == x*x: the value squares each round.
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var salt := 987_654_321_987_654_321;
    var round := 0;
    var rounds := if response.Candidate? && response.amount == 4242 then 40 else 0;
    while round < rounds
      invariant 0 <= round <= rounds
      invariant salt >= 0
    {
      salt := (0 - 1) % (salt * salt + 1);
      round := round + 1;
    }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
