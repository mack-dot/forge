# Refund wire proof and unfinished I/O composition

CURRENT stage: none. Active milestone: M1. Stage 12 is unauthorized.
`end_to_end=false`. Parent local commit:
`9b9747c6e3c7523b330898370a9ebba144ff9a2a`.
This is a saved local experiment. The proposal is not adopted or published.

## What is checked

The proposed `refund_dispatch` uses the published CakeML parser, serializer and
translator. It decodes the existing strict request schema, computes the complete
refund result and formats all six response fields. The original method and
wrapper remain unchanged. No approved input domain or refund rule changed.

The local HOL build returned 0 and exported these seven theorems:

| Theorem | Checked model claim |
| --- | --- |
| `refund_run_wire_valid` | A serialized request returns the rendered complete refund result |
| `refund_render_fields_roundtrip` | Response serialization and decoding retain all six fields |
| `refund_run_wire_decode_error` | A decoder error remains an error |
| `refund_run_wire_trailing` | A nonempty parser remainder is rejected |
| `refund_run_wire_malformed` | A parser error produces the required invalid-input error |
| `refund_dispatch_valid` | The translated dispatcher returns the required string under the CF application judgment |
| `refund_dispatch_error` | The translated dispatcher raises the required exception under that judgment |

These claims concern modeled byte strings and mathematical integers. The earlier
Unicode source proof remains separate. The complete source/model/native binding
is not established. A refund intent is not a bank operation.

## What failed

All three I/O builds failed at `refund_main_valid`. No I/O theory was exported.
Attempt 1 used `NONE` and `SOME` in quoted CakeML code. The published library uses
`None` and `Some`. Attempt 2 corrected those constructors but left a read-rule
obligation. A diagnostic exposed an existential option-representation witness.
Attempt 3 supplied that witness and unfolded the string representation, but the
complete proof still failed. Its remaining failing subgoal is not yet localized.

The diagnostic with exit 0 only inspected intermediate goals. It did not prove
`refund_main_valid` or `refund_main_error`. Do not count it as a passing I/O proof.
There have been three full I/O attempts. Preserve that count and all diagnostics.

## Actual commands and results

Commands ran from `/Users/mackianni/forge`. `OUT` below denotes
`results/refund-wire-library-2026-11-04/attempt-0001`.
The proof and GitHub records were recovered during this Markdown checkpoint;
they were not rerun. The saved-record validation did run for this checkpoint.

| Command or saved operation | Actual exit | Result |
| --- | --- | --- |
| `python3 -B "$OUT/run.py" wire-0001` | 0 | Seven wire/dispatcher theorems; six exports |
| `python3 -B "$OUT/run_stdio.py" stdio-0001` | 1 | Constructor mismatch; no accepted theory |
| `python3 -B "$OUT/run_stdio.py" stdio-0002` | 1 | Read-rule proof incomplete; no accepted theory |
| `python3 -B "$OUT/run_stdio.py" stdio-0003` | 1 | `refund_main_valid` still fails; no accepted theory |
| Saved HOL diagnostics 1/2/3/4 | 1/1/1/0 | Last result is subgoal inspection only |
| `python3 -B "$OUT/readback.py"` | 0 | Exact sources, exports, failures and 30 frozen inputs checked |
| `gh api repos/mack-dot/forge/rules/branches/main` | 0 | Effective rules returned |
| `gh api repos/mack-dot/forge/rulesets` | 0 | Active ruleset returned |
| `gh api repos/mack-dot/forge/branches/main/protection` | 1 | HTTP 404 for classic protection; does not negate the active ruleset |
| `gh api repos/mack-dot/forge/rulesets/26065125` | 0 | Exact rule details returned |

Exact argv, working directories, logs, source snapshots and exit codes are in
`records/`. Failed proof heaps remain in the raw experiment and toolchain
directories. This packet excludes those large heaps; it does not delete them.

Wire source SHA256:
`417b69d41a58da1ab3831e25cc3cf4ec6db7c0fcafd8af50be0caf9fd2306fb9`.
Wire theory data SHA256:
`17482ed974f856688298b957aee8d5155b5d56e2a104bbe3ec2a02056a690ae1`.
Latest failed I/O source SHA256:
`17813e63c2a6f122aa82a4c9e408bc15e09c944ed44208736bb509dc6c0f59c1`.

Wire repeat, new wire adversarial controls and a fresh closure audit are
**NOT RUN**. Prior library controls do not substitute for these checks.
Imported proof objects remain a trust boundary. File hashes do not authenticate
the producer. No independent review or complete native correctness claim exists.

## Repository and operational snapshot

The saved GitHub read shows main at
`f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3`. PRs 34, 36 and 37 remain open and
unmerged at `46e5aa426bf7800df7c98c732a764337e716f6bb`,
`705457e069abbe399128808b1efc7242d8eaeaa1` and
`fc85ecc2c7f12caa6c8991fa002410bdf78dd51d`, respectively. PRs 34 and 37 are drafts.
PR 34 remains a demonstration, not a merge target. PR 36 stays separate.
Review objects were not fetched; this snapshot does not establish review approval.

The effective `protect-main` ruleset requires one approving review, code-owner
review, last-push approval, stale-review dismissal and resolved review threads.
It also prohibits deletion and non-fast-forward updates and requires linear
history. The returned effective set has no required status-check or workflow
rule. The recorded bypass permission was not used. No setting changed.
This resolves protection visibility for this snapshot, not release eligibility.

The owner reports an off-machine backup. Exact archive hashes and a restore
from that independent copy remain unverified. No backup completion is inferred.
Native refund execution, hosted refund measurements and new admission are NOT RUN.

## Next authorized work and completion conditions

- [ ] Inspect the saved third I/O proof goal. Identify the exact remaining premise
  before another build. Do not repeat the same failure without a relevant change.
- [ ] Complete modeled stdin/stdout and error proofs with the existing TextIO
  rules. Preserve the complete result and strict input refusal.
- [ ] Require swapped response IDs, ignored trailing input and suppressed errors
  to fail at the intended obligations. Check output suppression once I/O passes.
- [ ] Rebuild the positive source; compare all exports and audit the exact closure.
- [ ] Derive the whole-program initialization and compiler premises. Bind the
  exact native artifact and runtime assumptions, including the Unicode boundary.
- [ ] Independently review the exact claim, implementation, checker closure and
  allowed assumptions before protected adoption and new authenticated admission.

Only the first item is the immediate next check. Later items remain pending.
No new framework, stage, acceptance policy or persistent infrastructure is needed
for that check. Publication, merge, workflow dispatch, signing, admission and
deployment retain their separate authorization boundaries. M2–M4 remain later
work. M1 and strict integration EXIT remain `NOT_ESTABLISHED`.

A separate audit thread reported owner approval for the local ad-hoc signature
needed for eventual macOS arm64 refund execution. Its original exchange could
not be read because the local thread service failed. The report is preserved in
`records/reported-native-approval.json`. No signing or native execution occurred.
Read that original exchange before relying on its scope. It does not report
authority for release signing, publication, deployment or Stage 12.
