# U383: strengthened simulation proved under a step-closed lab invariant; exact-program exclusion not established

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted and not used. Nothing committed.
Local results: same machine, same agent, cached parents. No clean replay.

## 1. Exact theorems (theory `forge_simReplay`, run `final-0003`, exit 0)

```
compile_no_install_prefix
⊢ lab_step_closed Inv ⇒
  ∀s1 res mc_conf s2 code2 labs t1 ms1.
    oracle_tie mc_conf ms1 s1 ∧ evaluate s1 = (res,s2) ∧ res ≠ Error ∧
    encoder_correct mc_conf.target ∧ state_rel (mc_conf,code2,labs,p) s1 t1 ms1 ⇒
    Inv s1 ∧ code_layout_ok (:α) code2 ⇒
    no_install_prefix mc_conf s1.ffi s1.clock ms1

compile_correct_no_install_prefix
⊢ lab_step_closed Inv ⇒
  ∀s1 res mc_conf s2 code2 labs t1 ms1.
    (published premises) ∧ Inv s1 ∧ code_layout_ok (:α) code2 ⇒
    (∃k t2 ms2. evaluate mc_conf s1.ffi (s1.clock + k) ms1 = (res,ms2,s2.ffi)) ∧
    no_install_prefix mc_conf s1.ffi s1.clock ms1

target_install_exclusion_conditional
⊢ lab_step_closed Inv ∧ (∀k. Inv (s1 with clock := k)) ∧
  (∀k. FST (evaluate (s1 with clock := k)) ≠ Error) ∧
  oracle_tie mc_conf ms1 s1 ∧ encoder_correct mc_conf.target ∧
  state_rel (mc_conf,code2,labs,p) s1 t1 ms1 ∧ code_layout_ok (:α) code2 ⇒
  ∀n. no_install_prefix mc_conf s1.ffi n ms1

lab_step_closed Inv ⇔
  (∀s i bs n. Inv s ⇒ asm_fetch s ≠ SOME (LabAsm Install i bs n)) ∧
  (∀s m r ad bs n. Inv s ⇒ asm_fetch s ≠ SOME (Asm (ShareMem m r ad) bs n)) ∧
  (∀s s'. Inv s ∧ lab_step s = SOME s' ⇒ Inv s')
```

`lab_step` is generated from the published `labSem$evaluate_def`: each
recursive call `evaluate X` becomes `SOME X`, each final result becomes
`NONE`. `lab_step_evaluate` (`lab_step s = SOME s' ⇒ evaluate s = evaluate s'`)
is proved.

Fidelity (machine check, proof run and import): removing the two added
premises and the added conclusion from `compile_correct_no_install_prefix`
gives the published `compile_correct`. Its first conjunct is the published
theorem itself; behavior, termination and FFI results are unchanged.

## 2. Differences from the U381 proposed statement

| Item | U381 proposal | Proved here |
| --- | --- | --- |
| Lab premise | no Install fetch at the end of the run for every clock | a step-closed invariant `Inv` that excludes Install and ShareMem lines |
| Prefix length | `s1.clock + k`, with the simulation's `k` | `s1.clock`; the all-clock corollary gives every `n` |
| Shared memory | not mentioned | excluded by the invariant premise |

The U381 statement as written is NOT PROVED. The form proved is sufficient
for the exclusion once an invariant exists (corollary above).

## 3. Method

The prefix property needs no new existential witness, so the published
conclusion is not replayed. A separate induction (published
`labSem$evaluate_ind`) proves the prefix property. Each case runs the
published tactic text up to the use of the induction hypothesis, then a
Forge finish: the published segment equation (with its interference
equation), `segment_compose_no_install_prefix` (U382), and the hypothesis.
33 local lemmas of the published script are re-proved from their published
text (`extract.py`); the published file is not changed (SHA256 prefix
`6cfb4a5f` checked by `make_replay.py`).

## 4. Nine simulation cases

| Case | Status | Note |
| --- | --- | --- |
| Asm (Inst, JumpReg) | PROVED | interior states ordinary; end state by the hypothesis |
| Jump | PROVED | |
| JumpCmp (taken, not taken) | PROVED | |
| Call | PROVED | contradiction, as in the published proof |
| LocValue | PROVED | |
| CallFFI (FFI_return, FFI_final) | PROVED | FFI entry is not the installer entry; `step_nip`, `final_nip` |
| Halt | PROVED | `no_install_prefix_halt`; halt and installer entries distinct (`state_rel_ctx`) |
| Install | PROVED, vacuous | excluded by the invariant premise; this is the intended premise |
| ShareMemOp | CONDITIONAL | excluded by the invariant premise; the general case is NOT PROVED |

## 5. Not established

- Target-level installer exclusion (U298) for the exact refund program: NOT
  ESTABLISHED. Missing: (a) an invariant `Inv` for the exact lab program with
  `lab_step_closed Inv` and `Inv` at the initial state for every clock (the
  U375 region invariant is the candidate; no bridge lemma yet; no check yet
  that the exact program has no ShareMem line); (b) the backend chain for
  `refund_alloc_oracle` that gives `state_rel`, `oracle_tie` and
  `encoder_correct` at the installed state (first link only, U378);
  (c) lab run without Error for every clock; (d) the identification of the
  installed bytes with `prog_to_bytes code2` (inside the published proof).
- Six installed-state obligations: all OPEN. Obligation 4 (installer) now
  has both halves as theorems (lab level U375; transport, conditional, here)
  but no link between them.

## 6. Executed commands

Run directory: `results/refund-p3-replay-local-20261113/attempt-0001`.
Heap: `cakeml/cv_translator/cake_compile_heap` (the earlier Forge theories
need it; the published build used `misc/cakeml-heap`).

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `go.sh base-0001`, `base-0002` | 1, 1 | my heap choice and extraction errors; not counted |
| `go.sh base-0003` (control: published text unchanged) | 1 | 7 published cases replay; the published Install case fails in this extraction context; Halt not reached |
| `go.sh replay-0001` … `replay-0016`, `skel-0001` | 1 each (`replay-0002` stopped, −15) | my splice, tactic and ordering errors; not counted |
| `go.sh replay-0017` | 0 | 7 case groups proved as subgoals |
| `go.sh replay-0018` … `replay-0025` | 1 each | CallFFI attempts; not counted |
| `go.sh replay-0026` | 0 | CallFFI proved as a subgoal |
| `go.sh final-0001` | 1 | nine cases and finalisation passed; my corollary tactic failed |
| `go.sh final-0002` | 0 | two main theorems stored |
| `go.sh final-0003` | 0 | final: 8 theorems, 4 definitions, tags and fidelity checked |
| `go.sh final-import` | 1 | my expected term typed an unused bound variable; not counted |
| `go.sh final-import-0002` | 0 | 5 exact statements, 4 tag checks, 297 closure nodes, fidelity, 2 statement controls, both negative controls re-read |
| `go.sh final-repeat` | 0 | `.sig` byte-identical; `.dat` identical after replacing the case directory name (the theory data records the source path); `.sml` differs only in the embedded data hash |

Source `final-0003.sml` SHA256
`aa7d6a1fa26032ea3a6cf2b8471b4d8582363722cae2ff474f746fd826bcb325`; theory
data `ae5ce5c25caa626c3d6c4c21273c729e9d24d5aaaaa49f98716303c46607ce6b`
(see `MANIFEST.json`). The exact-statement check compares up to renaming of
type variables. Clean replay: NOT_RUN. Independent replay: NOT_RUN.

## 7. Next smallest obligation

A lab bridge for the exact program: an invariant `Inv` with
`lab_step_closed Inv` and `∀k. Inv (s0 with clock := k)` for the published
`make_init` state. First steps: count ShareMem lines in the exact lab
program by evaluation, then show that the U375 region invariant is closed
under `lab_step`.
