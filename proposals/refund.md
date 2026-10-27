# Stage 8 refund boundary: exact contract proposal

Status: **PENDING HUMAN APPROVAL**. Stage 8 remains CURRENT. No refund
implementation, proof, hostile-output suite, or Stage 8 EXIT has run.

This proposal starts from published commit
[`ef06de72b38bb00041b4e52204880e75c4c002a9`](https://github.com/mack-dot/forge/commit/ef06de72b38bb00041b4e52204880e75c4c002a9).

## Approval requested

Approve the four exact additions in [the complete diff](refund/protected.diff),
reproduced below. Candidate files remain under `proposals/refund/`; none has
been installed under `spec/`, `policy/`, or `gate/`. The
[approval manifest](refund/approval-manifest.json) records their destinations,
byte lengths, SHA-256 digests, base commit, and patch digest.

Your Stage 8 instruction requires exact human approval before protected-file
changes. The [roadmap hard rules](../ROADMAP.md#hard-rules) also require an exact
specification diff and approval. Earlier Stage 7 permissions do not approve
these new refund business rules. This proposal seeks intent approval; it does
not claim the proposed obligations have been proved.

Approval covers only these four contract, protocol, lock, and policy additions.
It does not approve an unspecified future gate patch. The existing ledger and
booking gates have domain-specific bindings. Any new refund gate, binding
harness, or change to protected gate files must receive its own exact approval
before application. No gate logic will be moved elsewhere to avoid this rule.

## The two universal obligations

For **every** Context and ModelResponse value, with no validity precondition on
the implementation method:

1. **Universal safety:** an authorization has a nonnegative amount within the
   original charge and remaining amount, uses an approved reason, and emits at
   most one caller-bound refund intent. Every other outcome is Rejected with
   an empty plan. The source method cannot mutate the heap.
2. **Complete valid acceptance:** if the frozen Eligible predicate holds, the
   wrapper must return Authorized with the exact proposed amount and reason
   and its exact intent. It cannot reject, clamp, substitute, or add a heuristic.

An implementation that rejects every response must fail the real verifier.
A future trusted harness must call the concrete implementation on arbitrary
inputs and prove a concrete valid success. Its rejection is a mandatory negative
control, alongside an over-limit authorization, an audit escape, and a runtime
adapter that tries to bypass the boundary. None of these controls has run yet.

## Business and protocol decisions to review

| Topic | Proposed decision |
| --- | --- |
| Money | Integer minor units, 0 through 2^63-1 inclusive; exact decimal strings on the wire; no wraparound, rounding or clamping. |
| Host context | Nonempty charge/request IDs, original and remaining charge amounts, refund-enabled and request-open flags. The model supplies none of these. |
| Amount validity | 0 <= proposed amount <= remaining <= original <= 2^63-1. Invalid host context is rejected too. |
| Reason set | Exactly duplicate_charge, service_not_delivered, returned_item. No case folding, aliases or trimming. |
| Valid proposal | Valid host context plus a supported candidate within the amount bounds and exact reason set. Every such proposal is accepted unchanged. |
| Zero | A valid zero proposal is an authorization with a zero-valued intent. It is distinct from rejection and authorizes no positive payment. |
| Fallback | Rejected, empty plan, no refund executor call, no financial-state change. No automatic human escalation. |
| Wire format | At most 4,096 UTF-8 bytes; exactly amount_minor and reason, both strings; no duplicate/extra keys or alternate numeric representation. |
| Timeout | Proposed 5,000 ms monotonic deadline; fully received strictly before it, otherwise timeout. External timer/transport assumptions stay explicit. |
| Duplicate/late delivery | One terminal decision per (charge ID, request ID); repeat returns that decision without another executor call; late completion cannot reopen it. |
| Real payments | None in Stage 8. A test executor records the checked plan. Production payment processing remains outside this experiment. |

These are proposed choices, not defaults silently adopted as approved policy.
In particular, the reason set, numeric cap, valid-zero behavior, remaining-balance
rule, fallback, timeout, response cap and retry semantics need review.

## What the proof will and will not cover

Illustrative required outcomes, **not executed tests**: use caller-bound IDs,
original charge 100, remaining amount 60, and both context flags true unless
the row changes them.

| Input | Required result |
| --- | --- |
| Candidate(40, duplicate_charge) | Authorized(40, duplicate_charge), exact caller-bound intent. |
| Candidate(60, returned_item) | Authorized(60, returned_item); the inclusive upper bound is valid. |
| Candidate(0, service_not_delivered) | Authorized(0, service_not_delivered), zero-valued intent. |
| Candidate(-1, duplicate_charge) or Candidate(61, duplicate_charge) | Rejected, empty plan. |
| Candidate(40, arbitrary instruction text) | Rejected, empty plan. |
| TimedOut, Failed, Missing, Malformed, Oversized or Unsupported | Rejected, empty plan. |
| Negative original charge, remaining above original, or either context flag false | Rejected, empty plan. |
| Duplicate JSON keys or a floating-point JSON amount | Wire adapter must reject; separate integration obligation. |

These examples explain the contract. The required source result remains a
universal theorem, not success on this finite list.

The exact mathematical interface is [RefundSpec.dfy](refund/RefundSpec.dfy).
Candidate amounts include **all mathematical integers**, not only values the
wire parser admits. Candidate reasons include every finite string. Missing,
TimedOut, Failed, Malformed, Oversized and Unsupported are explicit response
constructors. Invalid values never need to satisfy a precondition to reach the
wrapper. The intended source theorem is universal over this modeled domain.

The [protocol](refund/protocol.md) defines strict wire conversion and integration
obligations. Malformed-byte rejection, parser fidelity, compiled JavaScript,
external deadlines, one-shot delivery and executor isolation are tested or
assumed outside the source proof. A wire parser mapping an arbitrary amount or
reason to Candidate still cannot make the checked source authorize outside its
bounds; the claim that malformed bytes always map to rejection separately needs
integration evidence. No universal raw-byte parser proof is claimed.

The host must supply truthful charge data, eligibility and current remaining
balance. It must reserve balances atomically and enforce durable payment
idempotency. This stateless boundary does not prove an aggregate refund ledger,
concurrency safety, crash recovery, authentication, or external exactly-once
payment execution. An allowed reason label does not prove its factual truth.
Model quality stays unmeasured unless a real quality evaluation runs.

This is a reusable trust-boundary experiment, with refunds as its concrete
example. Forge remains a general software-engineering project. Stage 7's exact
C binary proof and Stage 8's planned Dafny source proof are separate artifacts;
the former does not confer binary or deployment coverage on the latter.
`end_to_end=false` remains mandatory.

## Acceptance and evidence plan, not executed results

- R1-R5 require source_proof from actual pinned Dafny verification, its real
  assumption audit, concrete refinement/binding coverage, and a valid success.
- T1-T3 require property_tested records for strict wire handling, hostile typed
  candidates through the compiled wrapper, and effect/lifecycle isolation in
  the tested adapter. These records cannot satisfy any source-proof requirement.
- Planned fuzzing: three suites, seeds 8001/8002/8003, 1,000 cases per seed per
  suite, plus separately counted adversarial fixtures. No cases have run.
- No passing eval_measured record will be emitted without real evaluation.
  Unmeasured quality means no score; it does not mean a score of zero.
- Preserve exact checker/test commands, raw return codes, all failed attempts,
  source and dependency hashes, pins and limitations. Require canonical evidence
  reproduction and pre/post input identity. Never treat schema validity as proof.
- The unchanged three EXIT interfaces in ROADMAP.md remain NOT RUN. Only actual
  successful checks can complete Stage 8 or open Stage 9.

## Actual proposal checks — no proof claim

- Pinned Dafny version command: exit 0.
- `dafny resolve proposals/refund/RefundSpec.dfy`: exit 0; Dafny explicitly did
  not attempt verification. The abstract contract has no implementation yet.
- `git apply --check proposals/refund/protected.diff`: exit 0; patch not applied.
- Pinned jsonschema 4.21.1 policy validation: process exit 0, structure only.
- All Stage 8 EXIT commands: **NOT RUN**. No fuzz cases or quality evaluations ran.

Raw records are under `results/stage8/proposal/`. These checks make the draft
reviewable; they do not approve it or establish its guarantees.

## Exact candidate identities

| Protected destination | SHA-256 of proposed bytes |
| --- | --- |
| `spec/refund/RefundSpec.dfy` | `90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57` |
| `spec/refund/protocol.md` | `5ef4e8fa6c23a4a455b3cbdc3f5b14ae313762446fea8444ca5e6c570e86ecd4` |
| `spec/refund/spec.lock` | `993dade887f6141e9a9e27ae78e17b6cc2545923f334d83c17aad40bc3b28b57` |
| `policy/refund.yaml` | `4409904602e6b670c0fbf773b8f303426e22e0caac077f3d6ed5f016cecf2c83` |

The spec lock binds identity, not approval. No existing protected file is changed.

## Complete proposed diff

```diff
diff --git a/spec/refund/RefundSpec.dfy b/spec/refund/RefundSpec.dfy
new file mode 100644
--- /dev/null
+++ b/spec/refund/RefundSpec.dfy
@@ -0,0 +1,64 @@
+// Stage 8 refund boundary contract. Approval is recorded separately.
+abstract module RefundSpec {
+  const MaxMoney: int := 9223372036854775807
+
+  datatype Context = ChargeContext(
+    chargeId: string, requestId: string,
+    original: int, remaining: int,
+    refundEnabled: bool, requestOpen: bool)
+
+  // Every constructor, every mathematical integer and every finite string
+  // is in the response domain. Assess has no response-validity precondition.
+  datatype ModelResponse = Candidate(amount: int, reason: string)
+    | Missing | TimedOut | Failed | Malformed | Oversized | Unsupported
+
+  datatype Decision = Rejected | Authorized(amount: int, reason: string)
+  datatype RefundIntent = Intent(
+    chargeId: string, requestId: string, amount: int, reason: string)
+
+  predicate Money(value: int) {
+    0 <= value <= MaxMoney
+  }
+
+  predicate AllowedReason(reason: string) {
+    reason in {"duplicate_charge", "service_not_delivered", "returned_item"}
+  }
+
+  predicate ValidContext(context: Context) {
+    context.chargeId != "" && context.requestId != "" &&
+    context.refundEnabled && context.requestOpen &&
+    Money(context.original) && 0 <= context.remaining <= context.original
+  }
+
+  predicate Eligible(context: Context, response: ModelResponse) {
+    ValidContext(context) && response.Candidate? &&
+    0 <= response.amount <= context.remaining && AllowedReason(response.reason)
+  }
+
+  method Assess(context: Context, response: ModelResponse)
+      returns (decision: Decision, plan: seq<RefundIntent>)
+    modifies {}
+    // R1: every authorized amount is nonnegative and within both bounds.
+    ensures decision.Authorized? ==>
+      ValidContext(context) && Money(decision.amount) &&
+      decision.amount <= context.remaining <= context.original
+    // R2: every authorized reason is in the exact approved set.
+    ensures decision.Authorized? ==> AllowedReason(decision.reason)
+    // R3: every ineligible context or response has the same no-intent fallback.
+    ensures !Eligible(context, response) ==> decision == Rejected && plan == []
+    // R4: every eligible proposal is accepted with its exact amount and reason.
+    ensures Eligible(context, response) ==>
+      response.Candidate? && decision == Authorized(response.amount, response.reason) &&
+      plan == [Intent(context.chargeId, context.requestId, response.amount, response.reason)]
+    // R5: an intent exists exactly for an authorization; its target is caller-bound.
+    ensures (decision.Authorized? <==> Eligible(context, response))
+    ensures (decision.Rejected? <==> |plan| == 0)
+    ensures |plan| <= 1
+    ensures decision.Authorized? ==>
+      plan == [Intent(context.chargeId, context.requestId, decision.amount, decision.reason)]
+    ensures forall intent: RefundIntent :: intent in plan ==>
+      ValidContext(context) && Money(intent.amount) &&
+      intent.amount <= context.remaining <= context.original &&
+      AllowedReason(intent.reason) &&
+      intent.chargeId == context.chargeId && intent.requestId == context.requestId
+}
diff --git a/spec/refund/protocol.md b/spec/refund/protocol.md
new file mode 100644
--- /dev/null
+++ b/spec/refund/protocol.md
@@ -0,0 +1,122 @@
+# Refund boundary protocol, version 1
+
+These are requirements, not observed results. Adoption requires the approval
+record described in proposals/refund.md. Execution results belong in ROADMAP.md.
+
+This is a general trust-boundary experiment using refunds as its example.
+It does not establish an ML-specific product direction or authorize real payments.
+
+## Business decisions proposed for approval
+
+- Money is an integer number of minor currency units, from 0 through
+  9,223,372,036,854,775,807 inclusive. No currency conversion, floating-point
+  arithmetic, rounding, saturation, or wraparound is permitted. The host binds
+  the currency and unit to the original charge.
+- The host supplies the charge ID, request ID, original charge, remaining
+  refundable amount, refund-enabled flag, and request-open flag. The model cannot
+  set or replace them. IDs must be nonempty. Both flags must be true for a
+  valid context. The amounts must satisfy 0 <= remaining <= original <= MaxMoney.
+- Approved reason labels are exactly `duplicate_charge`, `service_not_delivered`,
+  and `returned_item`. Matching is case sensitive, with no trimming, aliases,
+  or normalization. Membership does not establish that the reason is true.
+- A valid proposal has a valid context, an amount between zero and the remaining
+  amount inclusive, and an approved reason. Every such proposal must be accepted
+  with that exact amount and reason. No extra heuristic may reject or modify it.
+- Zero is a legitimate authorization, distinct from fallback. A valid zero
+  proposal returns Authorized(0, reason) and one zero-valued intent. A consumer
+  may discharge that intent as a no-op; no positive payment is authorized by it.
+- Fallback means `Rejected` with an empty refund plan. It authorizes no refund,
+  changes no financial state, and does not call the refund executor. It is not
+  a zero-valued authorization and does not automatically escalate to a human.
+- Invalid contexts, invalid amounts/reasons, missing responses, provider errors,
+  timeout, malformed data, oversize data, and unsupported representations all
+  take that fallback. A proposed amount above a bound is rejected, never clamped.
+
+## Wire format and external lifecycle
+
+These rules are integration obligations. The mathematical source proof starts
+at the Context and ModelResponse datatypes. It does not prove a JSON parser.
+
+- A response is at most 4,096 UTF-8 bytes and contains one JSON object with
+  exactly two distinct keys: `amount_minor` and `reason`. Standard JSON whitespace
+  is permitted. Invalid UTF-8, a byte-order mark, trailing data, comments,
+  multiple objects, extra keys, and duplicate keys are rejected. Duplicate-key
+  checking must also catch escaped spellings of the same key.
+- Both values must be strings. `amount_minor` must be `0` or a nonzero ASCII
+  digit followed by zero to eighteen ASCII digits. Convert with exact integer
+  arithmetic and reject values above MaxMoney. Numeric JSON values, booleans,
+  nulls, signs, negative zero, leading zeroes, spaces, fractions, exponents,
+  NaN/Infinity, and Unicode digits are unsupported and rejected.
+- A structurally supported object maps to Candidate(integer, reason-string).
+  The checked wrapper validates the reason and amount again. Other wire inputs
+  map to an error constructor and never to an authorization. The reason string
+  is inert data. Model text is never evaluated as code, a command, a tool call,
+  an approval, a charge context, or an instruction to the refund executor.
+- The proposed response deadline is 5,000 ms from dispatch on a monotonic clock.
+  A response is timely only if fully received before the deadline. At the
+  deadline or later, Timeout wins. Streaming transport must enforce the byte
+  cap before unbounded accumulation. The clock, scheduler, cancellation and
+  transport are external; the wrapper does not prove that a provider returns
+  or that a real timer fires within a physical bound.
+- One attempt is active for a caller-bound (charge ID, request ID). Completion,
+  rejection, failure, or timeout closes that attempt. A late completion is
+  ignored and cannot reopen it. An identical repeated request returns its
+  recorded decision without another executor call. Reusing the pair with
+  different trusted context is rejected. A new attempt needs a new request ID.
+  Closing an attempt, cancelling transport, and recording its decision are
+  control bookkeeping, not refund side effects.
+- The integration must keep the refund executor capability outside the model
+  adapter and dispatch only the checked plan, using its caller-bound IDs and
+  exact amount/reason. Test executors record calls; Stage 8 does not send real
+  refunds. External refund success is not required for an authorization proof.
+
+## Universal claims and explicit limits
+
+R1 through R5 are the postconditions in RefundSpec.dfy. Assess has no `requires`
+clause: all well-typed contexts and responses are covered, including arbitrary
+mathematical integers and strings. The implementation must terminate. A trusted
+binding harness must call the concrete implementation on arbitrary inputs and
+also prove an eligible successful example. Rejecting every proposal is a defect.
+The source method has an empty modifies set and returns only decision/plan data.
+
+The source theorem neither assumes model accuracy nor gives the model an effect
+capability. Source proof does not establish compiled runtime behavior, parser
+fidelity, physical timeout delivery, executor isolation, authentication, storage,
+or network behavior. Those integration paths are tested where executed and
+otherwise stated as assumptions. Arbitrary host-code compromise is outside the
+model; untrusted response strings do not become executable host code.
+
+The host is responsible for truthful charge/eligibility data, atomic reservation
+of the remaining balance, and durable payment idempotency. This stateless source
+boundary does not prove a cumulative refund ledger, concurrency safety, crash
+recovery, or exactly-once external payments. Tests of duplicate or delayed
+responses cannot establish those universal external properties. The Stage 7 C
+binary proof does not cover this new Dafny/JavaScript integration.
+
+## Evidence and planned validation
+
+- `source_proof`: R1-R5 for the exact Dafny source closure and approved contract,
+  using the existing pinned Dafny, bundled Z3, resource limit, one worker,
+  disabled verification timeout, empty audit baseline, and full coverage checks.
+- `property_tested`: T1 strict wire handling, T2 execution of hostile typed
+  candidates through the compiled wrapper, and T3 effect/lifecycle isolation in
+  the tested adapter. The exact generated code, runtime, tests, dependencies,
+  source-proof reference, seeds, counts and concrete failures must be retained.
+- `eval_measured`: only if a real model-quality evaluation executes. With none,
+  record quality as `unmeasured`, no score, and no passing eval_measured evidence.
+  Controlled hostile-input suppliers are test fixtures, not live model runs.
+- Require a real unsafe-wrapper rejection for a proof-related reason. Also
+  require that an always-reject wrapper fails R4, an assumption escape fails the
+  actual audit, and a deliberately bypassed effect adapter fails the tests.
+- Plan three generated suites for T1-T3, each with fast-check seeds 8001, 8002,
+  and 8003 and 1,000 cases per seed (9,000 generated cases planned in total).
+  Add separately counted concrete malformed, duplicate-key, numeric-boundary,
+  oversize, injection, late-completion and repeated-request cases. These are
+  planned counts, not executed results. Preserve all failing seeds and shrinks.
+- Both evidence tiers must bind the exact artifacts and approved inputs. A test
+  result cannot satisfy an R claim that requires source_proof. Structural schema
+  validation alone is not acceptance. Require fresh actual checker execution,
+  pre/post source identities, and canonical evidence reproduction.
+
+Keep end_to_end=false. Stage 8 EXIT commands remain NOT RUN until implemented
+and actually executed after the required approvals.
diff --git a/spec/refund/spec.lock b/spec/refund/spec.lock
new file mode 100644
--- /dev/null
+++ b/spec/refund/spec.lock
@@ -0,0 +1,15 @@
+{
+  "dafny_build": "4.11.0+fcb2042d6d043a2634f0854338c08feeaaaf4ae2",
+  "dafny_version": "4.11.0",
+  "dependencies": {
+    "toolchain/pins.json": "74dcc4b81e452c7422698e6032a3fd7f44186aa2ef1e8a85320e2c8eb03ce60c"
+  },
+  "domain": "refund-boundary",
+  "end_to_end": false,
+  "intent_proposal": "proposals/refund.md",
+  "protocol_file": "spec/refund/protocol.md",
+  "protocol_sha256": "5ef4e8fa6c23a4a455b3cbdc3f5b14ae313762446fea8444ca5e6c570e86ecd4",
+  "schema_version": 1,
+  "spec_file": "spec/refund/RefundSpec.dfy",
+  "spec_sha256": "90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57"
+}
diff --git a/policy/refund.yaml b/policy/refund.yaml
new file mode 100644
--- /dev/null
+++ b/policy/refund.yaml
@@ -0,0 +1,67 @@
+{
+  "format_version": 1,
+  "id": "forge-refund-boundary",
+  "tiers": {
+    "critical": {
+      "artifact_kind": "source",
+      "description": "R1-R5 require actual source proof; safety and exact acceptance of every eligible proposal are mandatory.",
+      "required_claims": {
+        "R1": {
+          "allowed_methods": [
+            "source_proof"
+          ],
+          "minimum_method": "source_proof"
+        },
+        "R2": {
+          "allowed_methods": [
+            "source_proof"
+          ],
+          "minimum_method": "source_proof"
+        },
+        "R3": {
+          "allowed_methods": [
+            "source_proof"
+          ],
+          "minimum_method": "source_proof"
+        },
+        "R4": {
+          "allowed_methods": [
+            "source_proof"
+          ],
+          "minimum_method": "source_proof"
+        },
+        "R5": {
+          "allowed_methods": [
+            "source_proof"
+          ],
+          "minimum_method": "source_proof"
+        }
+      }
+    },
+    "hostile-tests": {
+      "artifact_kind": "source",
+      "description": "Finite T1-T3 integration test claims only; never authorizes an R1-R5 proof claim.",
+      "required_claims": {
+        "T1": {
+          "allowed_methods": [
+            "property_tested"
+          ],
+          "minimum_method": "property_tested"
+        },
+        "T2": {
+          "allowed_methods": [
+            "property_tested"
+          ],
+          "minimum_method": "property_tested"
+        },
+        "T3": {
+          "allowed_methods": [
+            "property_tested"
+          ],
+          "minimum_method": "property_tested"
+        }
+      }
+    }
+  },
+  "version": "1.0.0"
+}
```
