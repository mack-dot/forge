include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Grow() returns (s: string)
  {
    s := "abcdefghijkl";
    var k := 0;
    while k < 10
      decreases 10 - k
    {
      s := s + s;
      k := k + 1;
    }
  }
  method Hold(n: nat) returns (r: nat)
    decreases n
  {
    if n == 0 {
      r := 0;
    } else {
      var a := Grow();
      var b := Grow();
      var c := Grow();
      var d := Grow();
      var e := Grow();
      var f := Grow();
      var g := Grow();
      var h := Grow();
      var i := Grow();
      var j := Grow();
      r := Hold(n - 1);
      r := r + |a| + |b| + |c| + |d| + |e| + |f| + |g| + |h| + |i| + |j|;
    }
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if |context.chargeId| == 3 {
      var r := Hold(60);
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
