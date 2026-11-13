# U349: initializer reduced from 14 to 6 premises by the published ARM8 machine-config predicate

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Local HOL runs with the pinned tools. No hosted action or protected edit.
Status of the theorem: PROVED, local scope only. Its two negative controls
are NOT_RUN.

## Ranking of the 14 conditions of U347

| # | Condition | Free variables | Source of discharge | Difficulty |
| --- | --- | --- | --- | --- |
| 1 | link register not in `save_regs` | `mc` | Published `is_arm8_machine_config` | Low: computation |
| 6–8 | three `find_name ... ∈ save_regs` | `mc` | Same | Low |
| 9–13 | five `find_name ... = mc.<reg>` | `mc` | Same | Low |
| 2, 3 | `target_io_regs`, `target_cc_regs` give `NONE` on saved registers | `mc`, `ms`, FFI state | Needs the FFI interference contract of the real runtime | High: physical |
| 4, 5 | every address in `dm`, `sdm` is a multiple of 8 | `dm`, `sdm` | Needs the concrete memory-domain witness | Medium |
| 0 | `memory_assumption` | machine and memory state | Needs the complete installed-memory relation | Highest: physical |

Nine conditions mention only the machine configuration `mc`. One published
fact discharges all nine. That is the highest-leverage step, so it was
attempted first. The published compiler proof uses the same instantiation
`save_regs := set mc.callee_saved_regs` (`backendProofScript.sml`, proof of
`compile_correct'`).

## Theorem

`forge_refundInitializerMachine.refund_initialization_machine`:

```
is_arm8_machine_config mc ∧
memory_assumption ... ∧
(∀k i n. k ∈ set mc.callee_saved_regs ⇒ target_io_regs mc (basis_ffi ext cl fs) ms n i k = NONE) ∧
(∀k n.   k ∈ set mc.callee_saved_regs ⇒ target_cc_regs mc (basis_ffi ext cl fs) ms n k = NONE) ∧
(∀x. x ∈ dm ⇒ w2n x MOD 8 = 0) ∧ (∀x. x ∈ sdm ⇒ w2n x MOD 8 = 0)
⇒ <unchanged conclusion of refund_initialization_code, with
   save_regs := set mc.callee_saved_regs and mc at the ARM8 state type>
```

The script builds this statement from the audited theorem
`refund_initialization_code` (U347). It instantiates one type variable and the
free variable `save_regs`. It keeps the five conditions that mention more than
`mc`, unchanged, and replaces the nine `mc`-only conditions by the published
predicate. No frozen statement is modified; this is a new corollary.
`is_arm8_machine_config mc` already is a premise of U310's theorem and row C3
of the runtime matrix. It fixes the abstract machine record. It is not a claim
about the physical process.

## Actual results

All commands ran in `results/refund-initializer-machine-local-20261112/attempt-0001`.
Each import of the stack theory uses `code-0004` of U347.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `python3 -I -B run_stack_case.py explore-0001 explore-0001.sml <code-0004> forge_refundInitialStackCode` | 0 | Goal-manager exploration. Nine config goals; the tactic closes them one at a time. No theorem. |
| `... machine-0001 machine-0001.sml <code-0004> forge_refundInitialStackCode` | 0 | `REMAINING_ANTECEDENTS 6`; nine `DISCHARGED_CONDITION` lines; `RUNTIME_PROOF_COMPLETE`; four exports. |
| `... repeat machine-0001.sml <code-0004> forge_refundInitialStackCode` | 0 | Four exports byte-identical. |
| `... audit audit.sml ...` (first start) | none | INTERRUPTED by the operator (SIGTERM) under memory pressure. No result record. Not a result. |
| `... audit-0002 audit.sml <code-0004> forge_refundInitialStackCode machine-0001 forge_refundInitializerMachine` | 0 | Statement rebuilt from the imported base and compared by `aconv`; 6 premises; first is the predicate; five kept premises equal; conclusion equal; `DISK_THM` only; theorem count 1; 485 closure nodes; four Boolean axioms. |
| `no-machine-config.sml`, `missing-memory.sml` controls | NOT RUN | Prepared, not executed. Blocker: host memory and disk headroom (see U350). |
| `python3 -I -B verify_cases.py` (in `results/m1-closure-20261112/attempt-0001`) | 0 | Separate reader binds hashes, exits and markers. |

Proof source [machine-0001.sml](records/machine-0001.sml), SHA256
`d4a4e464af45e5195b5ddbf0125a2cd63b341423433313fcc87accb257a0a77d`. Tactic:
match the instantiated base theorem, accept the five kept premises, unfold
`is_arm8_machine_config_def` and evaluate. No axiom, `cheat` or new oracle.
Theory data SHA256 `8e8cb008d8a9e43cad68f9a2b8cc62997d0b728c85355698f24b6975a3c4af72`.

| Case | Wall s | Child CPU s (user + system) | Max RSS bytes |
| --- | --- | --- | --- |
| machine-0001 | 104.500 | 98.256 + 32.737 | 2432024576 |
| repeat | 157.273 | 158.058 + 49.673 | 2392784896 |
| audit-0002 | 142.320 | 96.819 + 32.505 | 1598259200 |

## Limits

The audit derives the expected statement from the imported base theorem. It
does not compare against an independently written statement text. Same
machine and agent; cached parent theories; no independent replay. The five
kept premises are open. Their physical applicability is NOT_ESTABLISHED.

## Next check

Run the two prepared controls when memory headroom allows. Then derive
conditions 2–5 from the published `installed`/`good_init_state` predicates,
as `compile_correct'` does, so that the initializer depends on one published
installed-state premise instead of five separate ones.
