// GENERATED FILE. Do not edit.
// Source: HOL4 definition forge_refundFlatContract.flat_plain_def, printed by
// dafny_of_term in forge_refundFlatContractScript.sml (APEX-2).
// The printing step is NOT machine-checked.
module HolFlat {
  predicate FlatPlain(chargeId: seq<int>, requestId: seq<int>, original: int, remaining: int, enabled: bool, requestOpen: bool, candidate: bool, amount: int, reason: seq<int>, authorized: bool, outputAmount: int, outputReason: seq<int>, outputCharge: seq<int>, outputRequest: seq<int>, intentCount: int)
  {
    ((authorized <==> ((!(chargeId == [])) && ((!(requestId == [])) && (enabled && (requestOpen && ((0 <= original) && ((original <= 9223372036854775807) && ((0 <= remaining) && ((remaining <= original) && (candidate && ((0 <= amount) && ((amount <= remaining) && ((reason == [100, 117, 112, 108, 105, 99, 97, 116, 101, 95, 99, 104, 97, 114, 103, 101]) || ((reason == [115, 101, 114, 118, 105, 99, 101, 95, 110, 111, 116, 95, 100, 101, 108, 105, 118, 101, 114, 101, 100]) || (reason == [114, 101, 116, 117, 114, 110, 101, 100, 95, 105, 116, 101, 109]))))))))))))))) && ((authorized ==> ((outputAmount == amount) && ((outputReason == reason) && ((outputCharge == chargeId) && ((outputRequest == requestId) && (intentCount == 1)))))) && ((!authorized) ==> ((outputAmount == 0) && ((outputReason == []) && ((outputCharge == []) && ((outputRequest == []) && (intentCount == 0))))))))
  }
}
