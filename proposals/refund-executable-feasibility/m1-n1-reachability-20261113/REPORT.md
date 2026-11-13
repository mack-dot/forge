# U364–U365: lemma N1 — code labels of the installer stubs in the exact word program

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false. Nothing committed.
No profile approved. The U298 exclusion premise is not adopted and not used.
All results are local: same machine, same agent, cached parent theories.

Statuses: PROVED (HOL kernel accepted it in this session; `DISK_THM` only, no
hypotheses, no tagged axioms; exact-statement import), FALSE (negation
PROVED), OPEN, PROPOSED (a lemma that was written down and not run).

## 1. N1 status

N1 as stated in U360 ("`Install_location` is not call-reachable", read as
"no other function refers to it") is **FALSE**. `InstallData_location`
(31) calls `Install_location` (29) directly. PROVED:
`refund_pre_alloc_not_closed_29`.

N1 corrected is **PROVED** at the syntactic level, for every allocation
oracle. Theory `forge_refundInstallReach`, theorem `install_stubs_unreferenced`:

```
∀orac n m pp md.
  MEM (n,m,pp,md)
    (SND (to_word arm8_config (set_oracle arm8_backend_config orac) refund_prog)) ∧
  n ≠ Install_location ∧ n ≠ InstallData_location ⇒
  Install_location ∉ word_get_code_labels pp ∧
  InstallData_location ∉ word_get_code_labels pp
```

`word_get_code_labels` is the published `wordConvs$get_code_labels`: every
direct call target (`Call _ (SOME x)`) and every code-pointer constant
(`LocValue _ x`), through all nested return and exception handlers.

Meaning: in the word program that the published compiler produces for the
exact refund program, the set {`Install_location`, `InstallData_location`}
has no incoming code label from the other functions. The statement covers the
program after `word_to_word`, whatever the allocation oracle is.

This is a syntactic closure fact. It is not the exclusion `E`, and it does
not say that the installer stub is never executed. Section 4 lists what is
missing.

## 2. Word-level control-flow facts (task 1)

All PROVED by in-logic evaluation (`cv_eval`) of the published compiler on
the pre-allocation word program
`P0 = SND (to_word_0 arm8_config arm8_backend_config refund_prog)`.

| Fact | Theorem |
| --- | --- |
| `P0` has 552 functions | `refund_pre_alloc_count` |
| Functions of `P0` with a code label 29: `[31]` | `refund_install_callers` |
| Functions of `P0` with a code label 31: `[31]` (self-recursion) | `refund_install_data_callers` |
| {29, 31} is closed in `P0`; every function has `good_handlers` | `refund_pre_alloc_closed` |
| {29} alone is not closed | `refund_pre_alloc_not_closed_29` |

Source reading, not a theorem: in `data_to_wordScript.sml` the only other
reference to `InstallData_location` is `assign_Install` (line 2706), the
translation of the data-level `Install` operation. `P0` has no such call, in
agreement with the evaluation.

Entry paths to `Install_location`, by kind:

| Kind | Word-level source | Status |
| --- | --- | --- |
| Direct call | `Call _ (SOME 29)` | PROVED: only inside function 31. `Call _ (SOME 31)` only inside function 31 |
| Indirect call or jump | `Call _ NONE` on a `Loc` value. A `Loc l _` with a function entry comes from `LocValue` | PROVED: no `LocValue` of 29 or 31 outside {29, 31}. OPEN: the semantic step that every `Loc` value in a reachable state comes from a `LocValue`, a return label or the initial state |
| Return path | Return to a label pushed by a `Call` with a return handler | NOT CHECKED here. Returning into function 29 or 31 needs a frame that 29 or 31 pushed. The published label conventions (return label `l1` equals the function name) were not instantiated in this run |
| Exception handler | Handler label of a `Call` | PROVED for `P0`: `good_handlers` holds for all 552 functions (handler labels stay in their own function) |
| Initial state | `make_init` gives `Loc 1 0` in local 0 (U303) | Not 29 or 31. Memory and store contents at start: OPEN at the semantic level |
| Fall-through between functions | None at word level | Lab level: OPEN |

## 3. Proof dependencies

```
install_stubs_unreferenced                      [PROVED, all oracles]
  ├ backend$to_word_thm                         [published]
  ├ to_word_0_oracle_independent                [PROVED: P0 does not depend on the oracle]
  ├ to_word_0_arm8_link                         [PROVED: specialised function = published at arm8_config]
  ├ refund_pre_alloc_closed                     [PROVED by cv_eval on P0]
  │    └ no_label_thm                           [PROVED: checker ⇔ label ∉ published get_code_labels]
  └ word_to_word_labels                         [PROVED, generic]
       └ word_to_word_labels_single             [PROVED, generic]
            └ wordConvsProof$word_good_code_labels_word_to_word   [published]
```

`word_to_word_labels`: for every configuration and oracle, each function
after `word_to_word$compile` has its labels inside {its own name} ∪ the
labels of the same function before, given `good_handlers`. It uses the
published whole-program theorem on a one-function program, because the
published per-pass label lemmas are local to their script.

New constants: three checker definitions (`no_label`, `labels_closed`,
`label_callers`). The final statement does not mention them. No axiom, no
`cheat`. Closure: 477 theory nodes, four Boolean axioms. The trusted base now
includes the HOL `cv_compute` primitive and the published cv translation of
the compiler, as for `refund_arm8_compiled`.

Finding: `forge_refundArm8Compile$oracle` is a specified constant. Its value
is not available (the evaluation library deletes the temporary definition).
So the exact post-allocation program cannot be evaluated directly. The proof
therefore holds for every oracle.

## 4. Why N1 does not give the exclusion; minimum instrumentation (task 3)

Existing compiler theorems are insufficient (U360: no stored theorem
concludes a prefix program-counter inequality). The published label theorems
below word level (`word_to_stack_good_code_labels`,
`stack_to_lab_stack_good_code_labels`) bound the union of all labels by the
set of all names. Names 29 and 31 are in that set, so those theorems cannot
carry the closure fact down.

Minimum instrumentation, all PROPOSED, none run:

| # | Lemma | Level | Kind |
| --- | --- | --- | --- |
| P1 | Lab-level closure: in the exact lab program, no line outside sections 29 and 31 has a label of either section (jump, call, `LocValue`), and no section falls through into them | lab | Either per-function versions of the published label theorems for `word_to_stack`, `stack_rawcall`, `stack_alloc`, `stack_remove`, `stack_names` and `stack_to_lab`; or evaluation of the published `to_lab_all_arm8` with an explicit oracle, plus a re-evaluation that this oracle gives the same bytes |
| P2 | Lab semantic invariant: from an initial state with no `Loc 29 _` or `Loc 31 _` value in registers or memory, `labSem$evaluate` never has its program counter in sections 29 or 31, so it never executes the `Install` line | lab | New induction over `labSem$evaluate` with a state invariant |
| P3 | Target prefix lemma: in the published lab-to-target simulation, a prefix state has `PC = install_pc` only when the lab step executes the `Install` line | target | A strengthened conclusion of `lab_to_targetProof$compile_correct`. The published proof does not expose prefix states, so this needs a modified copy of that proof |

P1 + P2 + P3 give `E` for the exact program. P3 is the expensive part.
Implemented and tested in this run: none of P1–P3. The word-level base
(section 1) is the part that was feasible.

## 5. Failed approaches

| Approach | Result |
| --- | --- |
| N1 as "no function other than 29 refers to 29" | FALSE: function 31 does. PROVED negation; control `naive-closure` exits 1 |
| Evaluate the exact post-allocation word program | Not possible: the allocation oracle is an unspecified constant |
| Use the published whole-program label theorem directly | Too weak: it bounds labels by all names, which include 29 and 31 |
| Re-use the published per-pass label lemmas | Not possible: all are `[local]` |
| `explore-0007` (`EVAL_TAC` on a symbolic compiler term) | Did not end; the agent stopped it after 614 s (exit −15). Not counted |

## 6. Executed commands

Run directory: `results/refund-n1-reachability-local-20261113/attempt-0001`.
Heap and working directory: those of the published in-logic compile.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `run_case.py explore-0001` | 0 | Compile theory and ARM8 pipeline constants listed |
| `explore-0002` / `0004` / `0005` / `0011` / `0015` | 1 / 1 / 1 / 1 / 1 | SCRIPT ERRORS (missing open, lookup type, type name, tactic without message, superfluous rule). Not counted; no `store_thm` attempt failed |
| `explore-0003` / `0006` | 0 / 0 | Checker translated; 552 functions; callers of 29 are `[31]`; naive check is `F` |
| `explore-0007` | −15 | Stopped by the agent. Not counted |
| `explore-0008` / `0009` / `0010` / `0012` / `0013` | 0 each | Linking lemmas and the one-function lemma in the goal manager |
| `explore-0014` / `0016` | 0 / 0 | List lemma, closure check `T` for {29, 31}, final composition in the goal manager |
| `run_case.py proof-0001 proof-0001.sml` | 0 | Eleven theorems checked; three exports |
| `run_case.py import import.sml …` | 0 | Ten exact statements; 477 closure nodes; four Boolean axioms |
| `run_case.py repeat proof-0001.sml` | 0 | Exports byte-identical |
| `run_case.py naive-statement …` | 1 | `Exact statement mismatch: naive N1 without the InstallData exclusion` |
| `run_case.py naive-closure …` | 1 | Fresh evaluation: pair closed (harness), `Install_location` alone rejected with `F` |
| Three shell-loop invocations with a joined argument | — | Runner error before any HOL child; three stray directories are kept. Not counted |
| `python3 -I -B verify_cases_r5.py` (first version) | 1 | Reader error: it expected four exports; this heap writes three. Corrected |
| `python3 -I -B verify_cases_r5.py` / two altered copies | 0 / 1 / 1 | Byte, exit and marker binding only |

Proof source SHA256 `82bac31188e0a8116dea4897c6df96d35c0d7b96cf2fe7f0103b0219383e6c9c`;
theory data `9566c1c595da7f236c206350b067f58c6c80d28678079bf17a2edc701d20c73a`.
Clean replay of this theory: NOT_RUN (it needs the CakeML build; U362).

## 7. Installed-state obligations after N1 (task 6)

Numbering of [INSTALLED-STATE.md](../m1-exclusion-profile-20261113/INSTALLED-STATE.md), section 3.

| # | Obligation | After N1 |
| --- | --- | --- |
| 1 | Complete machine record and abstract state | Unchanged. Independent of N1 |
| 2 | Start-up code | Unchanged |
| 3 | FFI code meets `ffi_interfer_ok` | Unchanged |
| 4 | Installer: exclusion or native proof | Not dischargeable yet. Reduced: the word-level syntactic base is PROVED; P1, P2 and P3 remain. When they are proved, `install_exclusion_suffices` (U360) removes the `install_interfer_ok` clause |
| 5 | Loader | Unchanged |
| 6 | Processor and operating system | Unchanged |

None of the six becomes dischargeable from N1 alone.

## 8. Next minimal obligation

P1 by evaluation: re-run the published in-logic compile with the oracle
definition kept, show that it gives the same `code`, and evaluate a lab-level
closure check on `to_lab_all_arm8`. NOT_RUN. Its truth is not known; the
fall-through part in particular is not known.
