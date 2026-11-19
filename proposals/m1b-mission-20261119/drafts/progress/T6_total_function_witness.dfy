include "RefundSpec.dfy"
// The shape of a "returns for every input" statement: Assess as a COMPILED function (no statements,
// so no expect), plus a method that only returns the function's value. The function is total in
// Dafny's logic for every input: no requires, and termination is checked.
module Total refines RefundSpec {
  function AssessF(context: Context, response: ModelResponse): (Decision, seq<RefundIntent>) {
    if Eligible(context, response)
    then (Authorized(response.amount, response.reason),
          [Intent(context.chargeId, context.requestId, response.amount, response.reason)])
    else (Rejected, [])
  }
  method Assess(context: Context, response: ModelResponse) returns (decision: Decision, plan: seq<RefundIntent>)
  { decision, plan := AssessF(context, response).0, AssessF(context, response).1; }
}
