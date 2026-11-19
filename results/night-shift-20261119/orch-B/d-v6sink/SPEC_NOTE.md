# Spec-fidelity note: the commit-time re-check in StepQ6 (d-v6sink, draft)

Question: is the re-check `F.Authorizes(stored, TransOf(token))` at commit a rule that the approved spec implies, or a new rule?

What the approved text says (spec/refund/protocol.md):
- l.15-18: the host supplies charge ID, request ID, original, remaining, refund-enabled and request-open; "The amounts must satisfy 0 <= remaining <= original <= MaxMoney."
- l.22-24: "A valid proposal has a valid context, an amount between zero and the remaining amount inclusive, and an approved reason. Every such proposal must be accepted with that exact amount and reason. No extra heuristic may reject or modify it."
- l.25-26: "Zero is a legitimate authorization, distinct from fallback."
- l.79: "Rejecting every proposal is a defect."

Answer, in two parts.
1. Eligibility part: implied. The approved relation R.Eligible (RefundSpec.dfy) is exactly the "valid proposal" of l.22. The re-check accepts only an Eligible candidate, so it adds no reason that the approved text lacks.
2. Proved: StepQ6 does not reject a token that the approved relation authorizes for the stored state, unless another check of the existing sink rejects it.
   - StepQ6Exact: StepQ6 commits IFF pinned ids, sigOk, preOk, not settled, and F.Authorizes(stored, TransOf(t)).
   - AuthorizedSameAsV4: for an authorized token, StepQ6 commits IFF StepQ (V4) commits, with the same result.
   - LostExactlyUnauthorized: a token that V4 commits and V6 rejects is exactly an unauthorized one.
   - ZeroAmountCommits, LargestAmountCommits and Witness (two zero-amount refunds, then the full 1000; MaxMoney on a MaxMoney charge): these tokens commit.
   So the re-check is not an "extra heuristic" in the sense of l.24. The checks that come before it (signature, pin, settled, stale pre-state, charge id) were in the sink before this change.

What is NOT approved intent. The relation also contains three choices of impl/RefundFinality.dfy. Its header (l.6-10) says these are "not ratified intent":
   (1) the stored state of a charge is (chargeId, original, remaining, refundEnabled);
   (2) an authorized refund decreases `remaining` by the amount and changes nothing else (the post-state rule);
   (3) the request is taken as open (F.ContextOf sets requestOpen := true; the sink's settled table decides freshness).
Before this change, only the checker enforced (1)-(3). With StepQ6, the sink enforces them too: a signed token with another post-state rule is rejected at commit. If the owner later ratifies another post-state rule, the sink core must change with the checker.
DECISION FOR THE OWNER (not decided here): accept (1)-(3) as sink rules, or keep the commit path signature-only (V4/V5) and accept the brick/minting risk.
Limits: the statements above are about the Dafny core functions only. The sink's TypeScript behaviour is TESTED-UNPROVED. The JS compiler is an ASSUMPTION.
