# Proposal (NOT APPLIED): close the Stage 5 `print` survivor with Dafny's own print-effect tracking (U414)

Master idea item F1.2. Status: PROPOSAL. It changes protected files
(`gate/**`). Nothing was changed. It needs the owner's approval of the
exact bytes in `candidate.diff`.

## Reason

`docs/spec-quality.md`: the mutant `print_effect` (a `print` statement
added to `Ledger.Apply`) survives. Printed output is outside C1–C5, so
no proof obligation fails. Pinned Dafny 4.11.0 has an option
`--track-print-effects`: a compiled method may print only when it has
the attribute `{:print}`, and a method without the attribute cannot
call one that has it. With that option and one non-printing caller of
`Ledger.Apply` in the gate's binding file, Dafny itself rejects every
implementation whose `Apply` can print. No text scan and no new checker
are needed.

## Exact change

`candidate.diff` (42 lines; `git apply --check` exit 0 on the working
tree; not applied):

| File | Base SHA-256 | Candidate SHA-256 | Change |
| --- | --- | --- | --- |
| `gate/backends/dafny.py` | `ef81d8d1…` | `a9114abf…` | add `'--track-print-effects'` to `OPTIONS` |
| `gate/ContractBinding.dfy` | `da994efa…` | `575dca82…` | add module `NoPrintEffects` with one caller of `Ledger.Apply` |
| `toolchain/pins.json` | `74dcc4b8…` | `4b612d88…` | add the option to `verification_options` (the gate compares the two) |

## Measured with the pinned Dafny and the gate's options

Runner `run_checks.py`; logs `results/forge2-print-effects-20261117/
attempt-0001..0005` (attempt-0001 scenario exit 1: my expectation that
`--enforce-determinism` passes the booking implementation was wrong;
attempts 0002–0005 exit 0).

| Case | Checker exit | Result |
| --- | --- | --- |
| print mutant, current gate options | 0 | the survivor is reproduced |
| print mutant, `--track-print-effects` | 2 | rejected: "to use a print statement, the enclosing method must be marked with {:print}" |
| print mutant with `{:print}` on `Apply` (also spelled `{: print }`), option only | 0 | **accepted**: the option alone can be bypassed |
| the same two, option plus the caller module | 2 | rejected: "to call a method with print effects, the enclosing method must be marked with {:print}" |
| the marked mutant with the caller module, WITHOUT the option | 0 | accepted: both parts are needed |
| approved `impl/Ledger.dfy`, option plus caller module | 0 | 13 verified, 0 errors |
| approved `impl/Ledger.dfy`, `impl/Booking.dfy`, `impl/Refund.dfy`, option only | 0, 0, 0 | no regression from the option |
| candidate `gate/ContractBinding.dfy` (from the diff) with approved impl; with marked mutant | 0; 2 | as intended |

## What this does NOT cover

- Booking and refund gates share `OPTIONS`. They get the option, but
  they have no caller module in this diff. A `{:print}` attribute there
  is still accepted. Each needs its own caller; not written.
- Other ambient effects (`{:extern}`, files, network). `dafny audit`
  already reports `{:extern}`; not re-tested here.
- Printing is rejected at resolution (exit 2), not by a proof. In
  Stage 5 terms this is a tool rejection, not a spec-proof kill. The
  Stage 5 driver and `docs/spec-quality.md` need a separate category.

## Required follow-up if approved (all NOT RUN)

1. Regenerate `evidence.json` and the booking and refund evidence:
   `verification_options` and `verified_obligations` change, so the
   bytes change. Update every place that compares those bytes.
2. `toolchain/linux-pins.json` holds the same option list for CI.
3. Re-run the EXIT commands of Stages 0–8 and 11 with fresh checker
   runs. Re-run `scripts/exit_stage_5.py` and record the new class for
   `print_effect`.
4. Add caller modules for the booking and refund bindings (new
   proposals).

## Not proposed: `--enforce-determinism`

Measured: it rejects a nondeterministic assignment (exit 2) and passes
the ledger and refund implementations, but it REJECTS the approved
`impl/Booking.dfy` (line 13, assign-such-that in a compiled method).
Enabling it needs a change of that implementation first. Recorded for
a later decision.
