# A8 contract-review matrix (U404)

Date: 2026-11-17. Prepared for a reviewer. This is NOT the review and
NOT a machine-checked equivalence. The "match" column is the proof
author's reading of two texts. A reviewer other than the author must
check every row. `spec/refund/RefundSpec.dfy` is unchanged.

Sources: `spec/refund/RefundSpec.dfy` (approved R1–R5);
`byte-boundary-20261104/records/inputs/Boundary.dfy` and its report
(U295); `forge_refundScript.sml` (`eligible_def`);
`forge_refundCertifiedProgScript.sml` (`refund_fields_def`);
`forge_refund_ioScript.sml` (`refund_request_def`). I did not re-run
any Dafny or HOL check of U262 or U295 in this run.

## 1. What is machine-checked on each side

| Side | Checked statement | Tool | Record |
| --- | --- | --- | --- |
| Dafny | `Boundary(context, response)` has no precondition; `ok ⇔ R.Eligible(context, response)`; `ok` equals an explicit formula over byte lists `Codes(U.Encoded(·))`; the six outputs are the stated conditionals; all byte values are below 256 | Dafny 4.11 | U295 |
| Dafny | UTF-8 encoding is injective; reason strings equal iff their encoded byte lists equal | Dafny 4.11 | U262, U295 (`ReasonCodes`, `CodesIdentity`) |
| HOL | `byte_fields_result`: `refund_fields` satisfies the boundary's decision and six-field relation over byte-value lists | HOL4 | U295 |
| HOL | `byte_wire_inputs`, `byte_wire_outputs`: the parser and serializer keep the nine request fields and six response fields | HOL4 | U295 |
| HOL | The compiled machine outputs `refund_render_fields (refund_fields …)` | HOL4 | U387, U404 (conditional) |

## 2. What is NOT machine-checked (the review items)

No tool relates a Dafny term to a HOL term. Each row below is a claim
that two texts mean the same thing.

| # | Dafny (approved or boundary) | HOL | Author's reading | Review status |
| --- | --- | --- | --- | --- |
| 1 | `int` (mathematical integer) | `:int` | same mathematical integers | NOT REVIEWED |
| 2 | `bool` | `:bool` | same | NOT REVIEWED |
| 3 | `seq<nat>` with all elements < 256 | `mlstring` through `MAP ORD ∘ explode` | byte lists; HOL inverse proved (`byte_roundtrip`, `byte_string_codes`) | NOT REVIEWED |
| 4 | `Codes(U.Encoded(chargeId))`, `…(requestId)` | `charge`, `request` | UTF-8 bytes of the Unicode string | NOT REVIEWED |
| 5 | `MaxMoney = 9223372036854775807` | literal `9223372036854775807` in `eligible_def` | same digits | NOT REVIEWED |
| 6 | `ValidContext`: ids non-empty, `refundEnabled`, `requestOpen`, `Money(original)`, `0 ≤ remaining ≤ original` | `charge ≠ «» ∧ request ≠ «» ∧ enabled ∧ opened ∧ 0 ≤ original ∧ original ≤ Max ∧ 0 ≤ remaining ∧ remaining ≤ original` | same conjuncts; non-empty string ⇔ non-empty byte list is proved on the Dafny side | NOT REVIEWED |
| 7 | `response.Candidate?` | `candidate : bool` | the six other constructors (`Missing`, `TimedOut`, `Failed`, `Malformed`, `Oversized`, `Unsupported`) all map to `candidate = F` | NOT REVIEWED. Check that R3 gives one fallback for all six |
| 8 | `0 ≤ response.amount ≤ context.remaining` | `0 ≤ amount ∧ amount ≤ remaining` | same; for non-candidates the boundary uses amount 0 | NOT REVIEWED |
| 9 | `AllowedReason`: three strings | three `mlstring` literals | same ASCII text | NOT REVIEWED |
| 10 | `Decision = Rejected \| Authorized(amount, reason)`, `plan : seq<RefundIntent>` | six-tuple `(ok, amount\|0, reason\|«», charge\|«», request\|«», 1\|0)` | `ok` ⇔ `Authorized`; fields 2–3 are the decision; fields 4–5 and the count are the single intent or the empty plan | NOT REVIEWED |
| 11 | R1 (authorized amount in bounds) | follows from `eligible` | consequence | NOT REVIEWED |
| 12 | R2 (authorized reason allowed) | follows from `eligible` | consequence | NOT REVIEWED |
| 13 | R3 (ineligible ⇒ `Rejected`, empty plan) | `¬ok ⇒ (F, 0, «», «», «», 0)` | same fallback | NOT REVIEWED |
| 14 | R4 (eligible ⇒ exact amount, reason, one intent with caller ids) | `ok ⇒ (T, amount, reason, charge, request, 1)` | same | NOT REVIEWED |
| 15 | R5 (intent exists exactly for an authorization; `\|plan\| ≤ 1`) | count is 1 iff `ok` | same | NOT REVIEWED |
| 16 | The boundary formula text in `Boundary.dfy` | the statement of `byte_fields_result` | the two formulas must be the same formula | NOT REVIEWED. I did not compare them line by line in this run |
| 17 | `Boundary` is tied to the approved `Assess` | — | U262/U295 say the approved implementation and spec were verified together with the transport; I did not re-read that proof | NOT REVIEWED; NOT RE-AUDITED |
| 18 | Wire text: decimal integers, `True`/`False` atoms | `refund_request_def` | producer of the wire text is outside the claim (A7) | NOT REVIEWED |

## 3. Known asymmetries (not defects found; items for the reviewer)

- HOL covers every byte string, including bytes that are not valid
  UTF-8. Those are outside the approved Unicode domain (U295: "wider
  model byte inputs are not relabeled as valid source Unicode"). The M1
  claim must speak about encoded approved inputs only.
- The Dafny verifier, its frontend and the UTF-8 library enter the
  trusted base for this link. The excluded upstream wrapper with an
  explicit axiom (U262) must stay excluded.
- The six-field tuple is a flattening chosen by Forge. Its adequacy as
  a representation of `(Decision, plan)` is row 10; no theorem states it
  in terms of the Dafny datatypes on the HOL side.

## 4. What a completed review would and would not give

It would give: a named, dated statement by an independent reviewer that
rows 1–18 hold, with the file hashes reviewed. It would not give a
machine-checked equivalence. An M1 claim that rests on it must say
"R1–R5 as identified by review (A8)". Whether that satisfies the M1
criteria is the owner's decision (U402 Q4, U403 R2).
