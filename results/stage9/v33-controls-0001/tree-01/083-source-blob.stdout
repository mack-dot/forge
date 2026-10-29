# Refund boundary protocol, version 1

These are requirements, not observed results. Adoption requires the approval
record described in proposals/refund.md. Execution results belong in ROADMAP.md.

This is a general trust-boundary experiment using refunds as its example.
It does not establish an ML-specific product direction or authorize real payments.

## Business decisions proposed for approval

- Money is an integer number of minor currency units, from 0 through
  9,223,372,036,854,775,807 inclusive. No currency conversion, floating-point
  arithmetic, rounding, saturation, or wraparound is permitted. The host binds
  the currency and unit to the original charge.
- The host supplies the charge ID, request ID, original charge, remaining
  refundable amount, refund-enabled flag, and request-open flag. The model cannot
  set or replace them. IDs must be nonempty. Both flags must be true for a
  valid context. The amounts must satisfy 0 <= remaining <= original <= MaxMoney.
- Approved reason labels are exactly `duplicate_charge`, `service_not_delivered`,
  and `returned_item`. Matching is case sensitive, with no trimming, aliases,
  or normalization. Membership does not establish that the reason is true.
- A valid proposal has a valid context, an amount between zero and the remaining
  amount inclusive, and an approved reason. Every such proposal must be accepted
  with that exact amount and reason. No extra heuristic may reject or modify it.
- Zero is a legitimate authorization, distinct from fallback. A valid zero
  proposal returns Authorized(0, reason) and one zero-valued intent. A consumer
  may discharge that intent as a no-op; no positive payment is authorized by it.
- Fallback means `Rejected` with an empty refund plan. It authorizes no refund,
  changes no financial state, and does not call the refund executor. It is not
  a zero-valued authorization and does not automatically escalate to a human.
- Invalid contexts, invalid amounts/reasons, missing responses, provider errors,
  timeout, malformed data, oversize data, and unsupported representations all
  take that fallback. A proposed amount above a bound is rejected, never clamped.

## Wire format and external lifecycle

These rules are integration obligations. The mathematical source proof starts
at the Context and ModelResponse datatypes. It does not prove a JSON parser.

- A response is at most 4,096 UTF-8 bytes and contains one JSON object with
  exactly two distinct keys: `amount_minor` and `reason`. Standard JSON whitespace
  is permitted. Invalid UTF-8, a byte-order mark, trailing data, comments,
  multiple objects, extra keys, and duplicate keys are rejected. Duplicate-key
  checking must also catch escaped spellings of the same key.
- Both values must be strings. `amount_minor` must be `0` or a nonzero ASCII
  digit followed by zero to eighteen ASCII digits. Convert with exact integer
  arithmetic and reject values above MaxMoney. Numeric JSON values, booleans,
  nulls, signs, negative zero, leading zeroes, spaces, fractions, exponents,
  NaN/Infinity, and Unicode digits are unsupported and rejected.
- A structurally supported object maps to Candidate(integer, reason-string).
  The checked wrapper validates the reason and amount again. Other wire inputs
  map to an error constructor and never to an authorization. The reason string
  is inert data. Model text is never evaluated as code, a command, a tool call,
  an approval, a charge context, or an instruction to the refund executor.
- The proposed response deadline is 5,000 ms from dispatch on a monotonic clock.
  A response is timely only if fully received before the deadline. At the
  deadline or later, Timeout wins. Streaming transport must enforce the byte
  cap before unbounded accumulation. The clock, scheduler, cancellation and
  transport are external; the wrapper does not prove that a provider returns
  or that a real timer fires within a physical bound.
- One attempt is active for a caller-bound (charge ID, request ID). Completion,
  rejection, failure, or timeout closes that attempt. A late completion is
  ignored and cannot reopen it. An identical repeated request returns its
  recorded decision without another executor call. Reusing the pair with
  different trusted context is rejected. A new attempt needs a new request ID.
  Closing an attempt, cancelling transport, and recording its decision are
  control bookkeeping, not refund side effects.
- The integration must keep the refund executor capability outside the model
  adapter and dispatch only the checked plan, using its caller-bound IDs and
  exact amount/reason. Test executors record calls; Stage 8 does not send real
  refunds. External refund success is not required for an authorization proof.

## Universal claims and explicit limits

R1 through R5 are the postconditions in RefundSpec.dfy. Assess has no `requires`
clause: all well-typed contexts and responses are covered, including arbitrary
mathematical integers and strings. The implementation must terminate. A trusted
binding harness must call the concrete implementation on arbitrary inputs and
also prove an eligible successful example. Rejecting every proposal is a defect.
The source method has an empty modifies set and returns only decision/plan data.

The source theorem neither assumes model accuracy nor gives the model an effect
capability. Source proof does not establish compiled runtime behavior, parser
fidelity, physical timeout delivery, executor isolation, authentication, storage,
or network behavior. Those integration paths are tested where executed and
otherwise stated as assumptions. Arbitrary host-code compromise is outside the
model; untrusted response strings do not become executable host code.

The host is responsible for truthful charge/eligibility data, atomic reservation
of the remaining balance, and durable payment idempotency. This stateless source
boundary does not prove a cumulative refund ledger, concurrency safety, crash
recovery, or exactly-once external payments. Tests of duplicate or delayed
responses cannot establish those universal external properties. The Stage 7 C
binary proof does not cover this new Dafny/JavaScript integration.

## Evidence and planned validation

- `source_proof`: R1-R5 for the exact Dafny source closure and approved contract,
  using the existing pinned Dafny, bundled Z3, resource limit, one worker,
  disabled verification timeout, empty audit baseline, and full coverage checks.
- `property_tested`: T1 strict wire handling, T2 execution of hostile typed
  candidates through the compiled wrapper, and T3 effect/lifecycle isolation in
  the tested adapter. The exact generated code, runtime, tests, dependencies,
  source-proof reference, seeds, counts and concrete failures must be retained.
- `eval_measured`: only if a real model-quality evaluation executes. With none,
  record quality as `unmeasured`, no score, and no passing eval_measured evidence.
  Controlled hostile-input suppliers are test fixtures, not live model runs.
- Require a real unsafe-wrapper rejection for a proof-related reason. Also
  require that an always-reject wrapper fails R4, an assumption escape fails the
  actual audit, and a deliberately bypassed effect adapter fails the tests.
- Plan three generated suites for T1-T3, each with fast-check seeds 8001, 8002,
  and 8003 and 1,000 cases per seed (9,000 generated cases planned in total).
  Add separately counted concrete malformed, duplicate-key, numeric-boundary,
  oversize, injection, late-completion and repeated-request cases. These are
  planned counts, not executed results. Preserve all failing seeds and shrinks.
- Both evidence tiers must bind the exact artifacts and approved inputs. A test
  result cannot satisfy an R claim that requires source_proof. Structural schema
  validation alone is not acceptance. Require fresh actual checker execution,
  pre/post source identities, and canonical evidence reproduction.

Keep end_to_end=false. Stage 8 EXIT commands remain NOT RUN until implemented
and actually executed after the required approvals.
