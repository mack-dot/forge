// Local feasibility implementation. No approved source or policy is replaced.
abstract module FlatRefund {
  method AssessFlat(chargeId: string, requestId: string,
      original: int, remaining: int, enabled: bool, requestOpen: bool,
      candidate: bool, amount: int, reason: string)
      returns (authorized: bool, outputAmount: int, outputReason: string,
               outputCharge: string, outputRequest: string, intentCount: int)
    modifies {}
    ensures authorized <==>
      chargeId != "" && requestId != "" && enabled && requestOpen &&
      0 <= original <= 9223372036854775807 && 0 <= remaining <= original &&
      candidate && 0 <= amount <= remaining &&
      (reason == "duplicate_charge" || reason == "service_not_delivered" || reason == "returned_item")
    ensures authorized ==>
      outputAmount == amount && outputReason == reason &&
      outputCharge == chargeId && outputRequest == requestId && intentCount == 1
    ensures !authorized ==>
      outputAmount == 0 && outputReason == "" &&
      outputCharge == "" && outputRequest == "" && intentCount == 0
  {
    authorized := chargeId != "" && requestId != "" && enabled && requestOpen &&
      0 <= original <= 9223372036854775807 && 0 <= remaining <= original &&
      candidate && 0 <= amount <= remaining &&
      (reason == "duplicate_charge" || reason == "service_not_delivered" || reason == "returned_item");
    if authorized {
      outputAmount := amount;
      outputReason := reason;
      outputCharge := chargeId;
      outputRequest := requestId;
      intentCount := 1;
    } else {
      outputAmount := 0;
      outputReason := "";
      outputCharge := "";
      outputRequest := "";
      intentCount := 0;
    }
  }
}
