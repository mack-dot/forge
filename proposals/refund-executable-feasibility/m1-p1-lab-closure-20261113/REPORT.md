# U368–U370: P1 lab-level closure proved; P2 static cases proved, semantic core open; P3 not run

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted and not used. Nothing committed in
this run. All results are local: same machine, same agent, cached parents.

Statuses: PROVED (HOL kernel accepted it in this session; `DISK_THM` only, no
hypotheses, no tagged axioms; exact-statement import), FAILED, NOT_RUN,
PROPOSED (written down, not proved).

| Lemma | Status |
| --- | --- |
| P1 lab-level closure (labels) | **PROVED** |
| P2, static part: label resolution and fall-through at program-counter level | **PROVED** |
| P2, semantic part: the invariant over `labSem$evaluate` | **NOT PROVED**. Two supporting lemmas PROVED; the one-step lemma is open |
| P3 target prefix lemma | **NOT_RUN** |
| Installer exclusion (U298) | **NOT ESTABLISHED** |

## 1. The allocation oracle is now a kept, defined constant

`forge_refundArm8Compile$oracle` has no available value (U364). This run
recomputes the oracle with the published pipeline (in-logic `to_livesets`,
then the published external allocator `reg_allocComputeLib`, algorithm `Irc`)
and keeps the result as the defined constant `refund_alloc_oracle` (552
entries). No oracle was chosen by hand.

PROVED, `refund_alloc_compiled`:

```
∃c1. compile arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog
       = SOME (code,data,c1)
```

`code` and `data` are the existing constants of `forge_refundArm8Compile`.
The proof script fails closed unless the recomputed code, data, FFI names and
encoded configuration are syntactically the stored constants. So the lab
program below is a program whose published encoding is the exact `code`
(PROVED, `refund_alloc_target`).

Not shown: `refund_alloc_oracle = oracle`. Every earlier Forge theorem that
names `oracle` uses only the `compiled` specification. Re-stating them for
`refund_alloc_oracle` is a mechanical step that was NOT_RUN.

## 2. P1: PROVED

Exact lab program: `L = SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))`,
with the published `backend$to_lab`.

Theory `forge_refundLabClosure`, theorem `refund_lab_install_closure`:

```
∀sec n1 n2.
  MEM sec L ∧ Section_num sec ≠ Install_location ∧ Section_num sec ≠ InstallData_location ∧
  (n1,n2) ∈ sec_get_labels sec ⇒
  n1 ≠ Install_location ∧ n1 ≠ InstallData_location
```

`sec_get_labels` is the published `labProps` function (labels of `Jump`,
`JumpCmp` and `LocValue` lines). The checker is stricter: it also covers
`Call` lines. Function 31 calling function 29 is accounted for: the closed
set is {29, 31}. For {29} alone the closure is false (PROVED,
`refund_lab_not_closed_29`).

Facts about `L` (PROVED, `refund_lab_stats`): 558 sections; the only section
with an `Install` line is 29; 553 `JumpReg` lines; 1206 `LocValue` lines; the
sections that mention a label of 29 or 31 are exactly 29 and 31.

Dependencies:

```
refund_lab_install_closure
  ├ lab_closed_labels            [PROVED: checker ⇒ statement on published sec_get_labels]
  └ refund_lab_closed            [PROVED: cv_eval of the checker on lab_forge8, then]
       └ lab_forge8_to_lab       [PROVED: computed program = published to_lab output]
            ├ forge8_links       [definitions: each re-specialised function IS the published
            │                     function at forge8_config; forge8_config = arm8_config]
            ├ word_to_word_inlogic ⇒ word_to_word$compile   [re-proved; published lemma is local]
            └ backend$to_lab_def, to_stack_def, to_word_thm, word_to_stack$compile_def [published]
refund_alloc_compiled            [PROVED: cv_eval + published compile_cake_arm8_thm]
```

Why re-specialise: the published `backend_asmLib` overwrites the defining
link of each ARM8-specialised function, so the stored theory has no theorem
that connects them to the published functions. This run defines nine
functions again (code as in `backend_asmLib.asm_spec`) and keeps the links.

Vacuity and circularity: `L` has 558 sections and section 29 holds the
`Install` line, so the statement is not vacuous. The import rebuilds each
expected statement from written text, not from the proof script. The
definitions of the checkers are printed in the import log for review.

## 3. P2, static part: PROVED

A hazard that P1 does not cover: in the published `labSem$loc_to_pc`, a label
at the end of a section resolves to the first instruction of the next
section. So label names alone do not bound where a jump lands.

Theory `forge_refundLabResolve`, theorem `refund_lab_refs_resolve_outside`:

```
∀sec a i bs len n1 n2 p.
  MEM sec L ∧ Section_num sec ≠ Install_location ∧ Section_num sec ≠ InstallData_location ∧
  MEM (LabAsm a i bs len) (Section_lines sec) ∧ (n1,n2) ∈ labs_of a ∧
  loc_to_pc n1 n2 L = SOME p ⇒
  pc_ok [Install_location; InstallData_location] L p
```

`pc_ok ls L p` says that program counter `p` (counted as
`labSem$asm_fetch_aux` counts) is not inside a section of `ls`. Also PROVED
(`refund_lab_resolve_closed`): no instruction line outside {29, 31} that is
followed by a line of 29 or 31 can fall through (it is `Jump`, `JumpReg` or
`Halt`). Counts (PROVED): 29095 instruction lines, 5244 with a label
reference, 0 `Call` lines, first line in section 0. `loc_pc_thm` proves the
executable twin equal to the published `loc_to_pc`.

## 4. P2, semantic part: NOT PROVED

Minimum invariants (task 3), for a value predicate `G` and a program-counter
predicate `OK`:

| Invariant | Covers |
| --- | --- |
| `OK s.pc` | Reachable program counters |
| `∀r. G (s.regs r)` and `∀a. G (s.mem a)`, with `G (Loc n1 n2)` meaning "if it resolves, it resolves to an `OK` counter" | Code-pointer provenance, indirect jumps (`JumpReg`), FFI return to the link register |
| `s.code` unchanged | Only the `Install` line changes code |
| Static hypothesis `region_hyp`: each line at an `OK` counter is `step_ok` | Direct jumps, conditional jumps, `LocValue`, fall-through, no `Call`, no `Install` |

Return labels need no separate invariant at lab level: `L` has no `Call`
line, so every return address is a `LocValue` constant and is covered by the
value invariant.

Theory `forge_labRegionInvariant` (generic in `G` and `OK`; it does not
mention the refund program):

- PROVED `asm_inst_val_inv`: `(∀w. G (Word w)) ∧ val_inv G s ⇒ val_inv G (asm_inst i s)`.
- PROVED `write_bytearray_val_inv`: FFI byte writes keep the memory invariant.
- PROPOSED, not proved, one-step lemma:
  `region_inv G OK code s ∧ evaluate s = (res,t) ⇒ (∃s2. evaluate s2 = (res,t) ∧ region_inv G OK code s2 ∧ s2.clock < s.clock) ∨ t = s`.
- PROPOSED, not proved, whole-run theorem (follows from the one-step lemma by
  induction on the clock).

Failed proof obligations: in the goal manager the branches for plain
instructions, indirect jumps and shared-memory operations of the one-step
lemma were closed one at a time. The combined tactic did not end within the
300 s CPU limit (`explore-0017`, exit −24): proof search in the leaf tactic
does not terminate on some branch of the labelled instructions (`CallFFI` is
the largest). No `store_thm` attempt failed. No counterexample was found.

Also open for P2: the instantiation for `L`. It needs two list lemmas that
relate `asm_fetch_aux` and `sec_at` to the flat line list, and the initial
state fact that registers and memory hold no `Loc` value that resolves into
29 or 31.

`install_stubs_unreferenced` (U364) was not used to infer any runtime fact.

## 5. P3 and the exclusion

P3 is NOT_RUN. It needs the P2 theorem and a modified copy of the published
`lab_to_targetProof$compile_correct` proof, because that proof does not
expose prefix states. Installer exclusion is NOT ESTABLISHED.
`install_exclusion_suffices` (U360) is not applicable yet.

## 6. Installed-state obligations

| # | Obligation | Status after this run |
| --- | --- | --- |
| 1 | Complete machine record and abstract state | OPEN. Unchanged |
| 2 | Start-up code | OPEN. Unchanged |
| 3 | FFI code meets `ffi_interfer_ok` | OPEN. Unchanged |
| 4 | Installer | OPEN. Static parts PROVED (U364, P1, P2 static). Remaining: P2 semantic, P3 |
| 5 | Loader | OPEN. Unchanged |
| 6 | Processor and operating system | OPEN. Unchanged |

All six remain open.

## 7. Executed commands

Run directories: `results/refund-p1-lab-closure-local-20261113/attempt-0001`
(P1, resolution) and `results/refund-p2-lab-invariant-local-20261113/attempt-0001` (P2).

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| P1 `run_case.py explore-0001` … `explore-0012` | 0, except `0004` −24 and `0011` 1 | `0004`: CPU limit in an over-broad tactic; `0011`: script read an unfinished goal. Not counted |
| `run_case.py proof-0001 proof-0001.sml` | 0 | Nine theorems; recomputed compile equals the stored constants |
| `run_case.py import …` / `repeat` | 0 / 0 | Eight exact statements, 384 closure nodes; byte-identical (the allocator is deterministic here) |
| `run_case.py naive-statement` / `naive-closure` | 1 / 1 | Intended mismatch; fresh evaluation rejects section 29 alone |
| `run_case.py resolve-0001 …` | 0 | Six theorems |
| `run_case.py resolve-import` / `resolve-repeat` | 0 / 0 | Five exact statements, 385 closure nodes; byte-identical |
| `run_case.py resolve-naive` | 1 | Fresh evaluation rejects section 29 alone |
| P2 `explore-0001` … `explore-0017` | 0, except `0004` −24, `0009` 1, `0017` −24 | Resource stops and one script error. Not counted |
| `run_case.py lemmas-0001 lemmas-0001.sml` | 0 | Two lemmas; the two open statements are printed as PROPOSED |
| `run_case.py lemmas-import` / `lemmas-repeat` | 0 / 0 | Two exact statements, 289 closure nodes; byte-identical |
| `run_case.py lemmas-missing-premise` | 1 | Intended statement mismatch |
| `python3 -I -B verify_cases_r6.py` / two altered copies | 0 / 1 / 1 | Byte, exit and marker binding only |

Source SHA256: P1 `e8c374be010e96186d241f786739ff39fccc7391f68c80c386619a48675defda`,
resolution `665f0dcac1e85882cfb076deea028ce51d75eab59728180c37f7bdb1e339e3ab`.
Theory data: `forge_refundLabClosure` `6899ad2a3e5469128087f6c4e947821ead95c0d11e683331f6de33833be1ae08`,
`forge_refundLabResolve` `b6246a203e9975a0bd56313f5c630bc5f6803dc0cb9b83c2192b617300f6c2d5`,
`forge_labRegionInvariant` `bca9b622f6566e4443bc2e179f4e3ce4979c9ff8f93d18f8ccde26d7c4861777`.
Clean replay of these theories: NOT_RUN (needs the CakeML build, U362). The
packet omits the byte-identical exports of the three repeat runs; they are in
the run directories.

## 8. Next smallest obligation

Close the one-step lemma of section 4: prove its labelled-instruction
branches one by one with explicit tactics (no open-ended proof search),
`CallFFI` first. Then the whole-run theorem, then the two list lemmas for the
instantiation.
