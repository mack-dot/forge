include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  datatype Res = Ok(v: int) | Err {
    predicate IsFailure() { Err? }
    function PropagateFailure(): Res requires IsFailure() { Err }
    function Extract(): int requires !IsFailure() { v }
  }
  method Probe(a: int) returns (r: Res) { if a == 123456789 { r := Err; } else { r := Ok(a); } }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var x :- expect Probe(if response.Candidate? then response.amount else 0);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
