include "RefundSpec.dfy"
// Can a refining Assess add an unbounded loop with decreases * ?
module Bad refines RefundSpec {
  method Assess(context: Context, response: ModelResponse) returns (decision: Decision, plan: seq<RefundIntent>)
  { while true decreases * { } decision := Rejected; plan := []; }
}
