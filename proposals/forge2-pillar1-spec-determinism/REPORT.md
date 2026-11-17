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
