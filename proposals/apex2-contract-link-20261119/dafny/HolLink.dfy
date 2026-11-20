// APEX-2 (2026-11-19). The Dafny half of the contract link.
//
// HolFlatGenerated.dfy holds HolFlat.FlatPlain: the HOL4 formula flat_plain,
// printed from the HOL theory (NOT machine-checked printing; see README.md).
// This file proves, for ALL inputs and outputs, that FlatPlain on the
// character codes is EXACTLY the contract of the real method
// FlatRefund.AssessFlat (the linked FlatCore.dfy, SHA-256 a89484e3...).
// The contract of AssessFlat is used only through CALLS of the method, so no
// copy of its ensures clauses is trusted here.
//
// Domain note: HOL strings have 8-bit characters. The two sides speak of the
// same value only for Dafny strings whose characters are all below 256
// (predicate IsBytes). The lemmas hold for all strings; the link uses them
// on IsBytes strings only.

include "../../m1b-mission-20261119/proofs/slice-theorem/inputs/transport/FlatCore.dfy"
include "HolFlatGenerated.dfy"

module HolLink {
  import F = FlatRefund
  import H = HolFlat

  function Codes(s: string): seq<int> {
    seq(|s|, i requires 0 <= i < |s| => s[i] as int)
  }

  predicate IsBytes(s: string) {
    forall i | 0 <= i < |s| :: (s[i] as int) < 256
  }

  lemma CodesInjective(s: string, t: string)
    ensures Codes(s) == Codes(t) <==> s == t
  {
    if Codes(s) == Codes(t) {
      assert |s| == |Codes(s)| == |Codes(t)| == |t|;
      forall i | 0 <= i < |s| ensures s[i] == t[i] {
        assert s[i] as int == Codes(s)[i] == Codes(t)[i] == t[i] as int;
      }
      assert s == t;
    }
  }

  lemma CodesInRange(s: string)
    requires IsBytes(s)
    ensures forall i | 0 <= i < |Codes(s)| :: 0 <= Codes(s)[i] < 256
  {}

  lemma CodesLiterals()
    ensures Codes("") == []
    ensures Codes("duplicate_charge") ==
      [100, 117, 112, 108, 105, 99, 97, 116, 101, 95, 99, 104, 97, 114, 103, 101]
    ensures Codes("service_not_delivered") ==
      [115, 101, 114, 118, 105, 99, 101, 95, 110, 111, 116, 95, 100, 101, 108, 105, 118, 101, 114, 101, 100]
    ensures Codes("returned_item") ==
      [114, 101, 116, 117, 114, 110, 101, 100, 95, 105, 116, 101, 109]
  {}

  // The HOL formula, read on Dafny strings through their character codes.
  predicate Plain(chargeId: string, requestId: string, original: int, remaining: int,
      enabled: bool, requestOpen: bool, candidate: bool, amount: int, reason: string,
      authorized: bool, outputAmount: int, outputReason: string,
      outputCharge: string, outputRequest: string, intentCount: int)
  {
    H.FlatPlain(Codes(chargeId), Codes(requestId), original, remaining, enabled, requestOpen,
      candidate, amount, Codes(reason), authorized, outputAmount, Codes(outputReason),
      Codes(outputCharge), Codes(outputRequest), intentCount)
  }

  lemma CodesFacts(chargeId: string, requestId: string, reason: string,
      outputReason: string, outputCharge: string, outputRequest: string)
    ensures Codes(chargeId) == [] <==> chargeId == ""
    ensures Codes(requestId) == [] <==> requestId == ""
    ensures Codes(outputReason) == [] <==> outputReason == ""
    ensures Codes(outputCharge) == [] <==> outputCharge == ""
    ensures Codes(outputRequest) == [] <==> outputRequest == ""
    ensures Codes(reason) == [100, 117, 112, 108, 105, 99, 97, 116, 101, 95, 99, 104, 97, 114, 103, 101]
      <==> reason == "duplicate_charge"
    ensures Codes(reason) == [115, 101, 114, 118, 105, 99, 101, 95, 110, 111, 116, 95, 100, 101, 108, 105, 118, 101, 114, 101, 100]
      <==> reason == "service_not_delivered"
    ensures Codes(reason) == [114, 101, 116, 117, 114, 110, 101, 100, 95, 105, 116, 101, 109]
      <==> reason == "returned_item"
    ensures Codes(outputReason) == Codes(reason) <==> outputReason == reason
    ensures Codes(outputCharge) == Codes(chargeId) <==> outputCharge == chargeId
    ensures Codes(outputRequest) == Codes(requestId) <==> outputRequest == requestId
  {
    CodesLiterals();
    CodesInjective(chargeId, ""); CodesInjective(requestId, "");
    CodesInjective(outputReason, ""); CodesInjective(outputCharge, ""); CodesInjective(outputRequest, "");
    CodesInjective(reason, "duplicate_charge");
    CodesInjective(reason, "service_not_delivered");
    CodesInjective(reason, "returned_item");
    CodesInjective(outputReason, reason);
    CodesInjective(outputCharge, chargeId);
    CodesInjective(outputRequest, requestId);
  }

  // D1. Every result of the real AssessFlat satisfies the HOL formula.
  method AssessFlatMeetsHol(chargeId: string, requestId: string, original: int, remaining: int,
      enabled: bool, requestOpen: bool, candidate: bool, amount: int, reason: string)
    returns (authorized: bool, outputAmount: int, outputReason: string,
             outputCharge: string, outputRequest: string, intentCount: int)
    ensures Plain(chargeId, requestId, original, remaining, enabled, requestOpen, candidate,
      amount, reason, authorized, outputAmount, outputReason, outputCharge, outputRequest, intentCount)
  {
    authorized, outputAmount, outputReason, outputCharge, outputRequest, intentCount :=
      F.AssessFlat(chargeId, requestId, original, remaining, enabled, requestOpen, candidate, amount, reason);
    CodesFacts(chargeId, requestId, reason, outputReason, outputCharge, outputRequest);
  }

  // D2. Any six values that satisfy the HOL formula ARE the result of the
  // real AssessFlat (so they satisfy its three ensures clauses).
  method HolMeetsAssessFlat(chargeId: string, requestId: string, original: int, remaining: int,
      enabled: bool, requestOpen: bool, candidate: bool, amount: int, reason: string,
      authorized: bool, outputAmount: int, outputReason: string,
      outputCharge: string, outputRequest: string, intentCount: int)
    returns (authorized': bool, outputAmount': int, outputReason': string,
             outputCharge': string, outputRequest': string, intentCount': int)
    requires Plain(chargeId, requestId, original, remaining, enabled, requestOpen, candidate,
      amount, reason, authorized, outputAmount, outputReason, outputCharge, outputRequest, intentCount)
    ensures authorized' == authorized && outputAmount' == outputAmount &&
      outputReason' == outputReason && outputCharge' == outputCharge &&
      outputRequest' == outputRequest && intentCount' == intentCount
  {
    authorized', outputAmount', outputReason', outputCharge', outputRequest', intentCount' :=
      F.AssessFlat(chargeId, requestId, original, remaining, enabled, requestOpen, candidate, amount, reason);
    CodesFacts(chargeId, requestId, reason, outputReason, outputCharge, outputRequest);
  }

  // Witnesses (the same values as the HOL theorem flat_plain_witnesses).
  lemma Witnesses()
    ensures Plain("ch_1", "rq_1", 100, 60, true, true, true, 40, "duplicate_charge",
      true, 40, "duplicate_charge", "ch_1", "rq_1", 1)
    ensures !Plain("ch_1", "rq_1", 100, 60, true, true, true, 40, "duplicate_charge",
      true, 40, "duplicate_charge", "rq_1", "ch_1", 1)
    ensures Plain("ch_1", "rq_1", 100, 60, true, true, true, 61, "duplicate_charge",
      false, 0, "", "", "", 0)
    ensures Plain("ch_1", "rq_1", 9223372036854775807, 60, true, true, true, 40, "returned_item",
      true, 40, "returned_item", "ch_1", "rq_1", 1)
    ensures Plain("ch_1", "rq_1", 9223372036854775808, 60, true, true, true, 40, "returned_item",
      false, 0, "", "", "", 0)
  {
    CodesFacts("ch_1", "rq_1", "duplicate_charge", "duplicate_charge", "ch_1", "rq_1");
    CodesFacts("ch_1", "rq_1", "duplicate_charge", "duplicate_charge", "rq_1", "ch_1");
    CodesFacts("ch_1", "rq_1", "duplicate_charge", "", "", "");
    CodesFacts("ch_1", "rq_1", "returned_item", "returned_item", "ch_1", "rq_1");
    CodesFacts("ch_1", "rq_1", "returned_item", "", "", "");
  }
}
