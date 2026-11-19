include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate T0(x: int) { x == x }
  predicate T1(x: int) { T0(x) && T0(x) }
  predicate T2(x: int) { T1(x) && T1(x) }
  predicate T3(x: int) { T2(x) && T2(x) }
  predicate T4(x: int) { T3(x) && T3(x) }
  predicate T5(x: int) { T4(x) && T4(x) }
  predicate T6(x: int) { T5(x) && T5(x) }
  predicate T7(x: int) { T6(x) && T6(x) }
  predicate T8(x: int) { T7(x) && T7(x) }
  predicate T9(x: int) { T8(x) && T8(x) }
  predicate T10(x: int) { T9(x) && T9(x) }
  predicate T11(x: int) { T10(x) && T10(x) }
  predicate T12(x: int) { T11(x) && T11(x) }
  predicate T13(x: int) { T12(x) && T12(x) }
  predicate T14(x: int) { T13(x) && T13(x) }
  predicate T15(x: int) { T14(x) && T14(x) }
  predicate T16(x: int) { T15(x) && T15(x) }
  predicate T17(x: int) { T16(x) && T16(x) }
  predicate T18(x: int) { T17(x) && T17(x) }
  predicate T19(x: int) { T18(x) && T18(x) }
  predicate T20(x: int) { T19(x) && T19(x) }
  predicate T21(x: int) { T20(x) && T20(x) }
  predicate T22(x: int) { T21(x) && T21(x) }
  predicate T23(x: int) { T22(x) && T22(x) }
  predicate T24(x: int) { T23(x) && T23(x) }
  predicate T25(x: int) { T24(x) && T24(x) }
  predicate T26(x: int) { T25(x) && T25(x) }
  predicate T27(x: int) { T26(x) && T26(x) }
  predicate T28(x: int) { T27(x) && T27(x) }
  predicate T29(x: int) { T28(x) && T28(x) }
  predicate T30(x: int) { T29(x) && T29(x) }
  predicate T31(x: int) { T30(x) && T30(x) }
  predicate T32(x: int) { T31(x) && T31(x) }
  predicate T33(x: int) { T32(x) && T32(x) }
  predicate T34(x: int) { T33(x) && T33(x) }
  predicate T35(x: int) { T34(x) && T34(x) }
  predicate T36(x: int) { T35(x) && T35(x) }
  predicate T37(x: int) { T36(x) && T36(x) }
  predicate T38(x: int) { T37(x) && T37(x) }
  predicate T39(x: int) { T38(x) && T38(x) }
  predicate T40(x: int) { T39(x) && T39(x) }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? && response.amount == 123456789 { var b := T40(response.amount); }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
