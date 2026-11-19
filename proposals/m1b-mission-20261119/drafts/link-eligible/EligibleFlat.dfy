// DRAFT (M1-B step I.1b, worker W2). NOT CHECKED BY ANY TOOL.
// Do not cite as verified until the pinned Dafny 4.11.0 run in RUN_PLAN.md
// returns exit 0 and `dafny audit` reports zero findings.
//
// Purpose: a Dafny-checked link between the APPROVED predicate
// RefundSpec.Eligible (through the concrete refinement Refund) and
// (a) a flat nine-argument predicate EligibleFlat, and
// (b) the exact exported source FlatCore.dfy (module FlatRefund,
//     SHA-256 a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d).
// The HOL side (forge_refundEligibleLinkScript.sml) proves that the AST
// exported from FlatCore.dfy evaluates to HOL `eligible`.
//
// Expected folder layout of the run (see RUN_PLAN.md, step D1):
//   EligibleFlat.dfy                 (this file)
//   FlatCore.dfy                     (a89484e3..., byte copy, unchanged)
//   impl/Refund.dfy                  (0416882492de..., byte copy of the approved impl)
//   spec/refund/RefundSpec.dfy       (90a21c71ae3a..., byte copy of the approved spec)
// impl/Refund.dfy includes "../spec/refund/RefundSpec.dfy" by itself.
//
// Rules kept: no `assume`, no `{:axiom}`, no bodiless lemma, no `expect`,
// no abstract module. Every lemma has a body. The module is concrete and
// imports the concrete module Refund (the approved refinement of the abstract
// RefundSpec), as proposals/refund-gate/Bindings.dfy does.

include "impl/Refund.dfy"
include "FlatCore.dfy"

module RefundEligibleLink {
  import R = Refund
  import F = FlatRefund

  // The body is a byte copy of the right-hand side of the first ensures
  // clause of FlatCore.dfy (`authorized <==> ...`), with the same parameter
  // names. The HOL theorem is about the exported AST of THAT clause.
  // The text identity is not needed for soundness of the lemmas below
  // (FlatCoreGuard links them semantically), but it makes review easy.
  predicate EligibleFlat(chargeId: string, requestId: string,
      original: int, remaining: int, enabled: bool, requestOpen: bool,
      candidate: bool, amount: int, reason: string)
  {
      chargeId != "" && requestId != "" && enabled && requestOpen &&
      0 <= original <= 9223372036854775807 && 0 <= remaining <= original &&
      candidate && 0 <= amount <= remaining &&
      (reason == "duplicate_charge" || reason == "service_not_delivered" || reason == "returned_item")
  }

  // Projection of every approved response to the three flat response fields.
  // Total: defined for all seven constructors.
  function FlatAmount(response: R.ModelResponse): int {
    if response.Candidate? then response.amount else 0
  }

  function FlatReason(response: R.ModelResponse): string {
    if response.Candidate? then response.reason else ""
  }

  // Lift of a flat triple to one approved response. A non-candidate maps to
  // Missing; lemma NonCandidatesAgree shows the choice does not matter.
  function FlatResponse(candidate: bool, amount: int, reason: string): R.ModelResponse {
    if candidate then R.Candidate(amount, reason) else R.Missing
  }

  // Set-display membership in the approved AllowedReason equals the
  // three-way string disjunction used by the exported source.
  lemma AllowedReasonIsDisjunction(reason: string)
    ensures R.AllowedReason(reason) <==>
      (reason == "duplicate_charge" || reason == "service_not_delivered" ||
       reason == "returned_item")
  {
  }

  // E1: for EVERY approved context and EVERY approved response (all seven
  // constructors, all mathematical integers, all Unicode strings).
  lemma EligibleFlatMatchesApproved(context: R.Context, response: R.ModelResponse)
    ensures R.Eligible(context, response) ==
      EligibleFlat(context.chargeId, context.requestId, context.original,
        context.remaining, context.refundEnabled, context.requestOpen,
        response.Candidate?, FlatAmount(response), FlatReason(response))
  {
    AllowedReasonIsDisjunction(FlatReason(response));
  }

  // E2: for EVERY flat nine-tuple.
  lemma ApprovedMatchesEligibleFlat(chargeId: string, requestId: string,
      original: int, remaining: int, enabled: bool, requestOpen: bool,
      candidate: bool, amount: int, reason: string)
    ensures EligibleFlat(chargeId, requestId, original, remaining, enabled,
        requestOpen, candidate, amount, reason) ==
      R.Eligible(R.ChargeContext(chargeId, requestId, original, remaining,
        enabled, requestOpen), FlatResponse(candidate, amount, reason))
  {
    var context := R.ChargeContext(chargeId, requestId, original, remaining,
      enabled, requestOpen);
    var response := FlatResponse(candidate, amount, reason);
    EligibleFlatMatchesApproved(context, response);
  }

  // E3: all six non-candidate constructors are ineligible (matrix row 7).
  lemma NonCandidatesAgree(context: R.Context, response: R.ModelResponse)
    requires !response.Candidate?
    ensures !R.Eligible(context, response)
  {
  }

  // E4: binding to the exact exported source. For every flat input, the
  // `authorized` output of FlatRefund.AssessFlat equals EligibleFlat and
  // equals the approved Eligible. Uses only AssessFlat's verified contract.
  method FlatCoreGuard(chargeId: string, requestId: string,
      original: int, remaining: int, enabled: bool, requestOpen: bool,
      candidate: bool, amount: int, reason: string)
      returns (authorized: bool)
    modifies {}
    ensures authorized == EligibleFlat(chargeId, requestId, original, remaining,
      enabled, requestOpen, candidate, amount, reason)
    ensures authorized == R.Eligible(R.ChargeContext(chargeId, requestId,
      original, remaining, enabled, requestOpen),
      FlatResponse(candidate, amount, reason))
  {
    var outputAmount: int, outputReason: string, outputCharge: string,
      outputRequest: string, intentCount: int;
    authorized, outputAmount, outputReason, outputCharge, outputRequest, intentCount :=
      F.AssessFlat(chargeId, requestId, original, remaining, enabled,
        requestOpen, candidate, amount, reason);
    ApprovedMatchesEligibleFlat(chargeId, requestId, original, remaining,
      enabled, requestOpen, candidate, amount, reason);
  }

  // E5: the same binding from the structured side, for every approved pair.
  method ApprovedGuard(context: R.Context, response: R.ModelResponse)
      returns (authorized: bool)
    modifies {}
    ensures authorized == R.Eligible(context, response)
  {
    authorized := FlatCoreGuard(context.chargeId, context.requestId,
      context.original, context.remaining, context.refundEnabled,
      context.requestOpen, response.Candidate?, FlatAmount(response),
      FlatReason(response));
    EligibleFlatMatchesApproved(context, response);
  }

  // Non-vacuity witnesses: one true case and one false case per side.
  method Witnesses()
    modifies {}
  {
    assert EligibleFlat("charge-1", "request-1", 100, 60, true, true, true, 40,
      "duplicate_charge");
    assert !EligibleFlat("charge-1", "request-1", 100, 60, true, true, true, 61,
      "duplicate_charge");
    assert !EligibleFlat("charge-1", "request-1", 100, 60, true, true, true, 40,
      "duplicate");
    assert R.Eligible(R.ChargeContext("charge-1", "request-1", 100, 60, true, true),
      R.Candidate(40, "duplicate_charge"));
  }
}
