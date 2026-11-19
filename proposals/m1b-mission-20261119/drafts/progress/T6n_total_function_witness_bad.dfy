include "RefundSpec.dfy"
// Negative control of T6: the same function with a wrong branch must not verify.
module Total refines RefundSpec {
  function AssessF(context: Context, response: ModelResponse): (Decision, seq<RefundIntent>) {
    if Eligible(context, response)
    then (Authorized(response.amount + 1, response.reason),
          [Intent(context.chargeId, context.requestId, response.amount, response.reason)])
    else (Rejected, [])
  }
  method Assess(context: Context, response: ModelResponse) returns (decision: Decision, plan: seq<RefundIntent>)
  { decision, plan := AssessF(context, response).0, AssessF(context, response).1; }
}
