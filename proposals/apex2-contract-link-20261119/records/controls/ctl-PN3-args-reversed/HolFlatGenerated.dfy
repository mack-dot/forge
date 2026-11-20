// GENERATED FILE. Do not edit.
// Source: HOL4 definition forge_refundFlatContract.flat_plain_def, printed by
// dafny_of_term in forge_refundFlatContractScript.sml (APEX-2).
// The printing step is NOT machine-checked.
module HolFlat {
  predicate FlatPlain(chargeId: seq<int>, requestId: seq<int>, original: int, remaining: int, enabled: bool, requestOpen: bool, candidate: bool, amount: int, reason: seq<int>, authorized: bool, outputAmount: int, outputReason: seq<int>, outputCharge: seq<int>, outputRequest: seq<int>, intentCount: int)
  {
    ((((((((0 == intentCount) && ([] == outputRequest)) && ([] == outputCharge)) && ([] == outputReason)) && (0 == outputAmount)) ==> (!authorized)) && ((((((1 == intentCount) && (requestId == outputRequest)) && (chargeId == outputCharge)) && (reason == outputReason)) && (amount == outputAmount)) ==> authorized)) && ((((((((((((((([114, 101, 116, 117, 114, 110, 101, 100, 95, 105, 116, 101, 109] == reason) || ([115, 101, 114, 118, 105, 99, 101, 95, 110, 111, 116, 95, 100, 101, 108, 105, 118, 101, 114, 101, 100] == reason)) || ([100, 117, 112, 108, 105, 99, 97, 116, 101, 95, 99, 104, 97, 114, 103, 101] == reason)) && (remaining <= amount)) && (amount <= 0)) && candidate) && (original <= remaining)) && (remaining <= 0)) && (9223372036854775807 <= original)) && (original <= 0)) && requestOpen) && enabled) && (!([] == requestId))) && (!([] == chargeId))) <==> authorized))
  }
}
