# Master idea, Pillar I, item F1.1 — spec determinism check (U410)

Date: 2026-11-17. Diagnostic outside the gate. No protected file
changed. No evidence bundle. Not committed. `end_to_end=false`.
Pinned Dafny `4.11.0+fcb2042d…` with the gate's options
(`--resource-limit 1000000`, bundled Z3 4.12.1, one core,
`--verify-included-files`). Runner: `run_checks.py` (dispatch only).
Raw logs: `results/forge2-pillar1-20261117/attempt-0001..0003`.

## 1. Result

For each approved spec, the postcondition of the specified method is
restated as a predicate `Post`. A wrapper method that only calls the
specified method is verified with `ensures Post(...)`. So every result
that the approved spec allows satisfies `Post`. The lemma
`SpecIsDeterministic` then shows that two results that satisfy `Post`
for the same input are equal.

| Spec | File | Checker exit | Dafny summary |
| --- | --- | --- | --- |
| `spec/LedgerSpec.dfy` (`Apply`) | `LedgerDeterminism.dfy` | 0 | 11 verified, 0 errors |
| `spec/booking/BookingSpec.dfy` (`Apply`) | `BookingDeterminism.dfy` | 0 | 18 verified, 0 errors |
| `spec/refund/RefundSpec.dfy` (`Assess`) | `RefundDeterminism.dfy` | 0 | 5 verified, 0 errors |

Meaning: each of the three approved specs allows at most one
`(next state, outcome)` for every valid input. An implementation has no
freedom in its result. `dafny audit` on the three files: exit 0, 0
findings.

Limits.

- This shows "no choice". It does not show "matches intent".
- `Post` is written by hand. The checked link is one direction
  (spec result ⇒ `Post`). That direction is the one determinism needs.
  The other direction is not checked.
- Output (`print`) and other ambient effects are outside these specs.
  The Stage 5 `print` survivor is not closed by this check.
- One passing run (attempt-0003). Same machine.

## 2. Planted-bug control ("bystander" frame)

`fixtures/LedgerSpecNoFrame.dfy` is the approved ledger spec with one
change: C4 gives three separate balance equations and says nothing
about other accounts. It is a fixture, not an approved spec.

| Control | Expected | Checker exit | Result |
| --- | --- | --- | --- |
| `fixtures/NoFrameImpls.dfy`: an honest and a Trojan implementation both refine the planted spec; `NoFrameWitness.TwoAllowedResultsDiffer` | verify | 0 (32 verified) | PASS |
| `fixtures/NoFrameDeterminism.dfy`: determinism lemma for the planted spec | reject at the lemma's postcondition | 4 (1 error, line 38) | PASS |
| `fixtures/TrojanAgainstApprovedSpec.dfy`: the same Trojan body against the approved spec | reject at C4 (`spec/LedgerSpec.dfy(62,20)`) | 4 (1 error) | PASS |

Verified witness (five accounts; request 7: account 3 sends 3 to
account 1; balances `[1, 2, 2, 4, 0]`): the honest result is
`[2, 5, 2, 0, 0]`; the Trojan result is `[2, 5, 0, 0, 2]`. Both satisfy
every clause of the planted spec, including conservation and
non-negativity. The Trojan moves the balance of bystander account 2 to
account 4. The witness is a proved lemma, not a failed proof attempt.

The approved spec is not affected: its C4 is a map update, the
determinism lemma verifies, and the Trojan is rejected.

## 3. Actual exits

| Attempt | Scenario exit | Note |
| --- | --- | --- |
| attempt-0001 | 1 | approved ledger lemma verified; Trojan proofs out of resource (my proof structure); one expected-text defect in my runner |
| attempt-0002 | 0 | four cases pass after helper lemmas and a corrected expected text |
| attempt-0003 | 0 | six cases pass (booking and refund added) |

Superseded fixture versions: `superseded/`.

## 4. NOT RUN

- F1.1d: a Dafny lemma that the planted bug is invisible with four
  accounts or fewer.
- F1.1e: generation of `Post` from the spec text; gate integration
  (`gate/` is protected: needs a proposal with an exact diff).
- F1.2, F1.3, F1.4.
- Repeat on a clean checkout; Linux profile.

## 5. Added on 2026-11-17, later (U413): items F1.1d and F1.3

Raw logs: `results/forge2-pillar1-20261117/attempt-0004..0012`.
Final run: attempt-0012, scenario exit 0, eleven cases.

### 5.1 F1.1d — the planted bug is invisible with four accounts or fewer

`fixtures/NoFrameFourAccounts.dfy`, lemma `DeterministicUpToFourAccounts`:
for the planted no-frame spec, if the state has at most four accounts,
two allowed results are equal. Checker exit 0 (25 verified, 0 errors).
Balances and amounts are unbounded; only the number of accounts is
bounded. Reason: C4 fixes sender, recipient and account 0, and
conservation fixes the one account that is left.

With section 2 this gives both sides: no witness exists with four
accounts or fewer (proved), and a witness exists with five (proved).
So a test or bounded check on four accounts cannot find this bug.
Attempts: attempt-0004 and attempt-0005 out of resource; attempt-0006
passed after the proof was split into small lemmas.

### 5.2 F1.3 — spec-diff check on the approved fee change

Old spec: `spec/LedgerSpec.dfy` at commit `c909a640`
(`fixtures/LedgerSpecNoFee.dfy`, SHA-256 of the original `e9bdfd51…`,
module renamed). New spec: the approved file. `SpecDiffFee.dfy`,
checker exit 0 (59 verified, 0 errors); `dafny audit` exit 0, 0 findings.

| Lemma | Statement (about results that the specs allow) |
| --- | --- |
| `UnchangedWhenOldDoesNotAccept` | Unchanged region: every retry and every request that the old spec rejects. Same state and same outcome under both. |
| `FeeDeltaWhenBothAccept`, `BothAcceptResult` | Where both accept: the new result is the old result with one unit moved from the sender to account 0. |
| `NewlyRejectedIff`, `NewlyRejected` | Accepted by the old spec and rejected by the new one exactly when: no account 0, or the sender is 0, or the recipient is 0, or the sender balance equals the amount. |
| `ChangedWhenOldAccepts` | Changed region: every request that the old spec accepts as a fresh transfer. |
| `OldPostSatisfiable`, `NewPostSatisfiable` | Both specs allow a result for every well-formed state (the statements are not vacuous). |

So the fee change has no effect outside the old accept region, and its
effect inside is fully described by two cases.

Boundary witnesses (`gen_fee_witnesses.py` writes the lemmas and
`records/fee-change-receipt.json` from one table; the receipt is data
only):

| Witness | Input | Old spec | New spec | Status |
| --- | --- | --- | --- | --- |
| W1 | balances `[0,5,0]`, 1→2 amount 5 (balance equals amount) | Ok `[0,0,5]` | Rejected | proved |
| W2 | same, amount 4 (balance equals amount + 1) | Ok `[0,1,4]` | Ok `[1,0,4]` | **NOT PROVED**: out of resource after five attempts; the general lemma `BothAcceptResult` is proved |
| W3 | `{0:5, 1:0}`, 0→1 amount 2 (sender is account 0) | Ok `{0:3, 1:2}` | Rejected | proved |
| W4 | `{0:0, 1:5}`, 1→0 amount 2 (recipient is account 0) | Ok `{0:2, 1:3}` | Rejected | proved |
| W5 | `{1:5, 2:0}`, 1→2 amount 2 (no account 0) | Ok `{1:3, 2:2}` | Rejected | proved |
| W6 | `[0,5,0]`, 1→2 amount 6 (insufficient funds) | Rejected | Rejected | proved |

Each proved witness says: every result that the old spec allows and
every result that the new spec allows for this input are the stated
ones, and both specs allow a result.

Negative control: `fixtures/SpecDiffFalseClaim.dfy` claims "the specs
agree whenever the new one does not accept". Rejected (exit 4, 1
error). W1 is a proved counterexample to that claim.

Limits. `Post` predicates are hand-written and opaque; the checked link
is spec result ⇒ `Post`. The lemma files are hand-written for this one
change; a generator for arbitrary spec pairs (`--semantic-diff`) is NOT
built. Nothing is in the gate.

### 5.3 Actual exits, attempts 0004–0012

| Attempt | Scenario exit | Note |
| --- | --- | --- |
| 0004, 0005 | 1, 1 | four-accounts lemma out of resource |
| 0006 | 0 | seven cases pass |
| 0007 | 1 | spec-diff: two general lemmas and all witnesses out of resource |
| 0008 | 1 | opaque predicates; three general lemmas out of resource; witness well-formedness errors (mine) |
| 0009 | 1 | general lemmas pass; W2 out of resource; one expected-text defect in my runner |
| 0010, 0011 | 1, 1 | W2 out of resource (attempts four and five) |
| 0012 | 0 | W2 moved to `SpecDiffFeeWitnessesOpen.dfy`, recorded with its real exit 4 as OPEN, not counted as a pass |

## 6. Round 2 task 1 (U418): W2 proved; second spec pair

Raw logs: `results/forge2-pillar1-20261117/attempt-0013..0014`.
Final run: attempt-0014, scenario exit 0, thirteen cases.

### 6.1 W2

Cause found with `--isolate-assertions`: no single assertion of W2 is
expensive; the lemma as ONE solver batch needs more than the per-batch
limit. Fix: the attribute `{:isolate_assertions}` on W2 only. Each
assertion is then its own batch at the unchanged limit of 1,000,000.
Measured (Dafny CSV log): 61 batches, all passed; largest batch
707,136; sum 6,319,497; solver time 2.87 s. The whole Dafny invocation
took 5.5–6.5 s while two other heavy jobs ran, so "under 5 s" is shown
for the solver time only. The global options are unchanged. The five
earlier failures stay in attempts 0007–0011 and in `superseded/`.
All six fee-change witnesses are now proved (136 verified, 0 errors).

### 6.2 Second pair: approved refund spec versus a capped variant

`fixtures/RefundSpecCapped.dfy` is the approved `RefundSpec` with one
extra condition in `Eligible` (`amount * 2 <= original`). It is a
fixture, not a proposed change. `SpecDiffRefundCap.dfy`: checker exit
0 (23 verified, 0 errors).

| Lemma | Statement |
| --- | --- |
| `EligibleNewIff` | Eligible under the variant exactly when eligible under the approved spec and within the cap. |
| `UnchangedOutsideTheCap` | Same decision and plan for every input the approved spec rejects and every eligible input within the cap. |
| `NewlyRejectedAboveTheCap` | Eligible and above the cap: the approved spec authorizes; the variant rejects with an empty plan. |
| `OldDeterministic`, `NewDeterministic` | At most one result per input. |
| `OldPostSatisfiable`, `NewPostSatisfiable` | A result exists for every input. |

Eight generated boundary witnesses (R1–R8: at the cap, one above, odd
original, full refund, zero, bad reason, missing response, disabled):
39 verified, 0 errors. False-claim control ("the variant never changes
the decision"): rejected, exit 4.

### 6.3 What "harness" means here (PARTIAL against the task text)

Shared and reusable: the runner, the opaque-`Post` pattern with
projection lemmas, and the table-driven witness and receipt generators.
NOT built: a generator of the general lemmas for an arbitrary pair. The
general lemmas of both pairs are written by hand.
