include "../../spec/refund/RefundSpec.dfy"

// PROPOSED stateful refund-log specification (2026-11-20). NOT approved. NOT ratified. end_to_end=false.
// It adds a stored state, two derived flag bits, one effect and a fold on top of the APPROVED stateless
// specification RefundSpec (spec/refund/RefundSpec.dfy, SHA-256 90a21c71...). That file is imported
// unchanged. This file restates none of its predicates: Allowed below IS the approved Eligible.
// Scope: ONE charge in ONE store, and the requests that the store committed, in commit order.
// Out of scope: crashes, durability, rollback, the external payment, other charges, who sent a request.
// The path in the first line resolves to the same file from proposals/refund-log-spec-20261120/
// and from spec/refund/ (both folders are two levels below the repository root).
abstract module RefundLogSpec {
  import R : RefundSpec

  // (a) The ledger state of one charge.
  datatype LedgerState = LedgerState(
    chargeId: string,       // the one charge of this store
    original: int,          // the original amount of the charge, in minor units
    remaining: int,         // the amount that is still refundable
    refundEnabled: bool,    // OWNER DECISION D1: fixed at genesis; no refund changes it
    settled: set<string>,   // the request ids that are settled
    epoch: nat)             // the number of committed refunds

  // A committed request, as one log record states it. Its charge is the charge of the state.
  datatype RefundRequest = RefundRequest(requestId: string, amount: int, reason: string)

  datatype Option<T> = None | Some(value: T)

  // (a) The first state of a store: the full amount remains, no id is settled, epoch 0.
  function Genesis(chargeId: string, original: int, refundEnabled: bool): LedgerState
  {
    LedgerState(chargeId, original, original, refundEnabled, {}, 0)
  }

  // (a) Well-formed state: the bounds of the approved ValidContext that belong to the state.
  predicate WellFormed(s: LedgerState)
  {
    s.chargeId != "" && R.Money(s.original) && 0 <= s.remaining <= s.original
  }

  predicate ValidGenesis(g: LedgerState)
  {
    WellFormed(g) && g == Genesis(g.chargeId, g.original, g.refundEnabled)
  }

  // (b) The two flag bits of the approved Context. Both are read from the state. No caller sets them.
  predicate RequestOpen(s: LedgerState, requestId: string)
  {
    requestId !in s.settled
  }

  // OWNER DECISION D1 (option B, proposed): the stored bit of the charge, fixed at genesis.
  predicate RefundEnabled(s: LedgerState)
  {
    s.refundEnabled
  }

  // (c) The approved Context of a request at a state, and the stateful permission.
  function ContextAt(s: LedgerState, q: RefundRequest): R.Context
  {
    R.ChargeContext(s.chargeId, q.requestId, s.original, s.remaining,
                    RefundEnabled(s), RequestOpen(s, q.requestId))
  }

  predicate Allowed(s: LedgerState, q: RefundRequest)
  {
    R.Eligible(ContextAt(s, q), R.Candidate(q.amount, q.reason))
  }

  // (d) The effect of a request on state s is the post-state t: remaining decreases by exactly the
  // amount, the id joins the settled set, the epoch advances by one, and nothing else changes.
  predicate Effect(s: LedgerState, q: RefundRequest, t: LedgerState)
  {
    t.remaining == s.remaining - q.amount &&
    t.settled == s.settled + {q.requestId} &&
    t.epoch == s.epoch + 1 &&
    t.chargeId == s.chargeId && t.original == s.original && t.refundEnabled == s.refundEnabled
  }

  // The result of one request: the post-state if the request is allowed; None (no change, no effect) if not.
  predicate DecidePost(s: LedgerState, q: RefundRequest, r: Option<LedgerState>)
  {
    if Allowed(s, q) then r.Some? && Effect(s, q, r.value) else r == None
  }

  // The specified decision. It is the only declaration of this module without a body.
  method Decide(s: LedgerState, q: RefundRequest) returns (r: Option<LedgerState>)
    ensures DecidePost(s, q, r)

  // (f) One step of the fold. Its Some case is exactly Allowed and Effect (lemma StepIsDecidePost).
  function Step(s: LedgerState, q: RefundRequest): Option<LedgerState>
  {
    if Allowed(s, q) then
      Some(s.(remaining := s.remaining - q.amount, settled := s.settled + {q.requestId}, epoch := s.epoch + 1))
    else None
  }

  // (f) The fold of a log from a state, record by record, in log order. None: some record is not allowed.
  function Replay(g: LedgerState, log: seq<RefundRequest>): Option<LedgerState>
    decreases |log|
  {
    if |log| == 0 then Some(g)
    else
      match Replay(g, log[..|log| - 1])
      case None => None
      case Some(s) => Step(s, log[|log| - 1])
  }

  // (f) The predicate that a log verifier checks: a valid genesis, and every record allowed at its pre-state.
  predicate ValidHistory(g: LedgerState, log: seq<RefundRequest>)
  {
    ValidGenesis(g) && Replay(g, log).Some?
  }

  // (e) At most once: no request id is in two records of a log.
  predicate AtMostOnce(log: seq<RefundRequest>)
  {
    forall i, j :: 0 <= i < j < |log| ==> log[i].requestId != log[j].requestId
  }

  // (f) The sum of the amounts, and the set of the request ids, of a log.
  function SumAmounts(log: seq<RefundRequest>): int
    decreases |log|
  {
    if |log| == 0 then 0 else SumAmounts(log[..|log| - 1]) + log[|log| - 1].amount
  }

  function Ids(log: seq<RefundRequest>): set<string>
    decreases |log|
  {
    if |log| == 0 then {} else Ids(log[..|log| - 1]) + {log[|log| - 1].requestId}
  }

  // (f) Conservation: what the final state s of a log from genesis g must satisfy.
  predicate Conserves(g: LedgerState, log: seq<RefundRequest>, s: LedgerState)
  {
    s.chargeId == g.chargeId && s.original == g.original && s.refundEnabled == g.refundEnabled &&
    g.original == s.remaining + SumAmounts(log) &&
    0 <= s.remaining <= s.original &&
    s.settled == Ids(log) && |s.settled| == |log| && s.epoch == |log|
  }
}
