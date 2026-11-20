# Stateful refund-log specification: a proposal for the owner's review (2026-11-20)

**This is a SPECIFICATION PROPOSAL.** It is NOT approved and NOT ratified. No protected file changed.
The lemmas are machine-checked statements about the specification TEXT only (one run, on this
machine; results below). Nothing here says anything about the engine (`src/silicon_sink/sink.rs`),
about a log file, or about compiled code. `end_to_end=false`. M1-B OPEN. Stage 9 deferred. Entry
U924.

The owner's decision of 2026-11-20 (verbatim): "Stateful Spec + Task V1: Approved! First open an
isolated exact-diff PR for the stateful refund-log specification (covering the effect, at-most-once
request_id, conservation fold, and flag bits, cleared via spec_clearing) for my review and merge;
then build and prove Task V1 in Dafny folding silicon_sink's real WAL with negative log controls."
This folder is the first half only. Task V1 is NOT started.

## What is asked of the owner

1. Review the clauses (about ten) of [`RefundLogSpec.dfy`](RefundLogSpec.dfy). Each one is in
   plain words, with the engine line beside it, in [`CORRESPONDENCE.md`](CORRESPONDENCE.md).
2. Decide D1, the `refundEnabled` question (below). The text uses option B.
3. Decide D2 (zero amounts) and D3 (file names and lock). The text uses the defaults below.
4. Ratify, if you agree: apply [`ratification.diff`](ratification.diff) on a new branch and merge
   it. The exact bytes and the commands are in [`RATIFICATION_DIFF.md`](RATIFICATION_DIFF.md). The
   hosted PR gate will REJECT that change (`UNAPPROVED_PROTECTED_CHANGE`): no machine approval path
   exists for files under `spec/refund/`. Your merge of the exact bytes is the ratification, as for
   pull request 76.

## The specification in ten lines

1. It imports the approved stateless `RefundSpec` (`90a21c71…`) unchanged and restates none of it.
2. State of ONE charge: charge id, original, remaining, refund flag, settled request ids, epoch.
3. Genesis: remaining = original, no settled id, epoch 0; well formed: charge id non-empty,
   `0 <= original <= MaxMoney`, `0 <= remaining <= original`.
4. `requestOpen` := the request id is not in the settled set. Read from the state.
5. `refundEnabled` := the stored bit of the charge, fixed at genesis (D1). Read from the state.
6. `Allowed(state, request)` := the approved `Eligible` on the context built from (4), (5) and the state.
7. `Effect`: remaining decreases by exactly the amount, the id joins the settled set, epoch + 1,
   nothing else changes.
8. `Step(state, request)`: `Some(post)` exactly when Allowed, with the Effect; else `None`.
9. `ValidHistory(genesis, log)` := valid genesis and the fold of `Step` over the log never gives `None`.
10. Proved for every valid history: no request id twice; `original == remaining + sum(amounts)`;
    `0 <= remaining <= original`; settled = the ids of the log, one per record; epoch = length.

## D1: where `refundEnabled` comes from (OWNER DECISION)

The approved `ValidContext` needs `refundEnabled`. The silicon sink has no stored flag: the caller
sends a bit and the sink checks only its spelling (`sink.rs:133`). The genesis record has no such
field (`sink.rs:7-11`).

| Option | Rule | Consequence |
| --- | --- | --- |
| A | constant `true` | The approved conjunct carries no meaning (a tautology). Matches what a silicon store can express today. No charge can be disabled |
| **B (proposed)** | a bit of the stored state, set at genesis, copied unchanged by every effect | Never chosen by a caller. `false` refuses every request (proved: `FlagOffIsRefused`). A disable AFTER genesis cannot be stated. A silicon genesis record has no bit, so Task V1 needs one more decision, D1b: "a silicon genesis means `true`" (then B equals A for silicon logs) or "the bit comes from outside the log" (a configuration input, as `ShellCoreV5` takes its initial charge) |
| C | "the request names the stored charge" | A tautology: the spec request names no charge, and the sink's compare-and-swap (`sink.rs:168`) checks the charge already. Withdrawn in Report D |
| D | `remaining > 0` | Changes approved behaviour: a zero-amount refund on an empty charge is committed today (`tests/silicon_sink/test_silicon_crash.py:340`) and would be refused. It repeats the amount bound |
| E | a stored bit with its own enable/disable record | The most expressive. It needs a second kind of transition, a record format change and more proof. Not minimal |

Why B is the proposal: of the options that give the bit a meaning, B is the most conservative. It
adds no new transition, a caller cannot set it, and it can only cause refusals.

## D2: zero amounts (OWNER DECISION)

The approved `Eligible` allows `amount = 0`, and the approved protocol calls zero "a legitimate
authorization". Default: keep it (lemma `ZeroAmountIsAllowed`). Each zero-amount refund with a fresh
id settles that id and advances the epoch. The alternative adds `0 < q.amount` to `Allowed`: stricter
than the approved rule (`Allowed` still implies `Eligible`), and a sink log with a zero-amount record
then fails `ValidHistory`. The task brief named "zero/negative amount" as a refusal cause; under the
default only the NEGATIVE amount is refused (lemma `NegativeAmountIsRefused`).

## D3: file names and the lock (OWNER DECISION)

Proposed: `spec/refund/RefundLogSpec.dfy` (identical bytes to this folder's file) and a new lock
`spec/refund/RefundLogSpec.lock` in the format of `spec/refund/spec.lock`. The alternative follows the
booking precedent (`spec/booking/spec.lock`): a folder `spec/refund-log/` with a file named
`spec.lock`. That name is read by `gate/coverage.py:125` (`rglob('spec.lock')`), so the new lock
would then take part in the PR gate's coverage rule. I did not run that path. See
`RATIFICATION_DIFF.md`.

## What it enables

Task V1 (`proposals/assurance-chain-20261120/REPORT_F_NEXT_IMPLEMENTATION.md`): a Dafny verifier that
folds the silicon sink's WAL and is proved against `ValidHistory` (theorem D-1 of Report D). After
ratification, V1 is relative to an APPROVED stateful specification instead of an unapproved one.

## Results (one run each, this machine)

Pinned Dafny 4.11.0 (`/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/dafny`) with the gate options of
`gate/backends/dafny.py` (Z3 4.12.1, `--resource-limit 1000000`, `--verification-time-limit 0`,
`--cores 1`, `--verify-included-files`, `--track-print-effects`). Proof slot: the first run waited
2462 s (a Goal 20 evidence job held it); later runs waited 120 s each (three free checks).

| Command/check | Actual exit | Result |
| --- | --- | --- |
| `dafny verify RefundLogSpec.dfy RefundLogSpecLemmas.dfy RefundLogSpecInstance.dfy` (attempt 1) | 4 | 43 verified, 2 errors: the two concrete witnesses `FirstStep` and `AcceptedHistoryOfTwo` (the solver did not unfold `Replay` on literal sequences). Repaired with explicit steps in the LEMMAS file only; the spec bytes did not change. `records/verify-attempt-0001.log` |
| the same (attempt 2) | 0 | 45 verified, 0 errors. `records/verify-attempt-0002.log` |
| `dafny audit` of the three files, `RefundSpec.dfy` and `impl/Refund.dfy` against `gate/expected-audit.md` (`--compare-report`) | 0 | 0 findings; the report equals the empty baseline |
| `clear_log_spec.py /Users/mackianni/forge <work> --wait-slot` (imports `scripts/spec_clearing.py` `99f1000e…`, unchanged; `clear_spec`) | 0 | verdict **NO_CHOICE**; acceptance **ACCEPTS**. Claim check: audit 0, verify 0, 42 members, none failed. Proof instance: passed (45 members). Spec probe: compiler exit 3 (the probe's expected way), the only declaration without a body is `RefundLogSpec.Decide`: passed. Acceptance instance (`AcceptedHistoryOfTwo`): audit 0, verify 0. `records/clearing-summary.json`, `records/clearing-record.json` |
| `git apply --check ratification.diff` on a fresh clone of `b1c98822` | 0 | see `RATIFICATION_DIFF.md` for all checks after the apply |
| Task V1; any engine run; hosted gate; push; pull request | NOT RUN | not part of this step |

Scope of NO_CHOICE (the tool's own words, shortened): for every input, each refinement of the
specification allows at most one result of `Decide`, and no compiled declaration is left without a
body except `Decide`. Not checked by the tool: ghost definitions without a body (there are none in
this file by reading), and that the claim lemma states the right claim (read `RefundLogClaim`, 15 lines).

## Files

| File | Content |
| --- | --- |
| [`RefundLogSpec.dfy`](RefundLogSpec.dfy) | the proposed specification (pure: one method without a body, the specified `Decide`; no assume, no axiom, no extern) |
| [`RefundLogSpecLemmas.dfy`](RefundLogSpecLemmas.dfy) | lemmas about the specification; the clearing claim module |
| [`RefundLogSpecInstance.dfy`](RefundLogSpecInstance.dfy) | one module that refines the spec with `Decide := Step` and the approved `impl/Refund.dfy`; for the clearing tool only |
| [`clear_log_spec.py`](clear_log_spec.py) | spec clearing by import of `scripts/spec_clearing.py` (unchanged), as `src/primitives_v2/py/policy_to_dfy.py` does; no file under `clearing/` |
| [`CORRESPONDENCE.md`](CORRESPONDENCE.md) | clause by clause: spec line, `sink.rs` line, gaps; what is left out and why |
| [`RATIFICATION_DIFF.md`](RATIFICATION_DIFF.md), [`ratification.diff`](ratification.diff) | the exact, UNAPPLIED change of protected paths, SHA-256 values, owner commands, interaction with pull request 76 |
| [`records/`](records/) | logs of the runs in the table above |
