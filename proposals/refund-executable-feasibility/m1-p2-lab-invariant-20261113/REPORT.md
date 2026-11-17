# U371–U373: P2 proved at lab level; runtime exclusion of the installer line for the exact lab program

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted and not used. Nothing committed in
this run. All results are local: same machine, same agent, cached parents.

Statuses: PROVED (HOL kernel accepted it in this session; `DISK_THM` only, no
hypotheses, no tagged axioms; exact-statement import), NOT_RUN, OPEN.

| Item | Status |
| --- | --- |
| CallFFI branch | **PROVED** (`region_step_callffi`) |
| Other ten instruction branches | **PROVED** (`region_step_*`) |
| Combined one-step theorem | **PROVED** (`region_one_step`) |
| Whole-run and every-prefix theorems | **PROVED** (`region_run`, `region_prefix`) |
| P2 for the exact lab program | **PROVED**, with one premise on the start memory (`refund_lab_init_run_avoids_install`) |
| P3 target prefix lemma | **NOT_RUN** |
| Installer exclusion at target level (U298) | **NOT ESTABLISHED** |

## 1. Why the earlier combined tactic failed, and what changed

`explore-0017` of the previous run (exit −24) applied one tactic to all
branches and ended each leaf with `metis_tac` over two higher-order lemmas.
It printed no residue: the search did not end inside one step. No unsolved
goal was recorded.

Changed strategy: one lemma for each fetched line; a shared prefix; an
explicit leaf (`irule` of a successor lemma, then a fixed choice of value and
program-counter tactics). Proof search is used only on first-order local
assumptions. Each run takes 6 to 10 seconds.

## 2. Generic theorems (theory `forge_labRegionStep`)

Generic in a value predicate `G`, a program-counter predicate `OK` and the
code. They do not mention the refund program or any oracle.

`region_inv G OK code s` is: `s.code = code`, the static hypothesis
`region_hyp G OK code`, `G` of every register and memory cell, and `OK s.pc`.

Branch lemma, one for each of `Inst`, `JumpReg`, `ShareMem`, `Label`, `Halt`,
`LocValue`, `Jump`, `JumpCmp`, `Call`, `Install`, `CallFFI`:

```
region_inv G OK code s ∧ s.clock ≠ 0 ∧ asm_fetch s = SOME <line> ∧ evaluate s = (res,t) ⇒
(∃s2. evaluate s2 = (res,t) ∧ region_inv G OK code s2 ∧ s2.clock < s.clock) ∨ t = s
```

`region_one_step`: the same without the fetch premises.
`region_run`: `s.clock = k ∧ region_inv G OK code s ∧ evaluate s = (res,t) ⇒ region_inv G OK code t`.
`region_prefix`:

```
region_inv G OK code s ∧ evaluate (s with clock := k) = (res,t) ⇒
region_inv G OK code t ∧ OK t.pc ∧ t.code = code ∧
∀i bs n. asm_fetch t ≠ SOME (LabAsm Install i bs n)
```

`k` is arbitrary, so this covers every evaluator prefix of the lab
semantics.

CallFFI, as modelled by `labSem$evaluate`:

| Effect | Treatment |
| --- | --- |
| Program counter | Set to the resolution of the link register. The link register holds a `Loc`; the value invariant gives that it resolves to an `OK` counter |
| Registers | Each becomes its old value or `Word w` from the interference oracle. Both satisfy `G`, for every oracle |
| Memory | `write_bytearray` of the returned bytes. `write_bytearray_val_inv`: it only writes `Word` cells. Holds for every returned byte list |
| FFI state, clock | Not part of the invariant |
| `FFI_final` | Halt with the state unchanged |

So within the model a returning FFI call cannot create a code pointer and
cannot redirect control except through a `Loc` that already satisfies `G`.
The model assumption itself (the native FFI code behaves as this) is the
installed-state obligation 3 and is not proved.

Counterexample search:

- For the stated theorem: none exists; it is proved for all inputs.
- For the claim without the static hypothesis: a concrete counterexample is
  PROVED in control `step-refute-weakened-v3` (two sections, one jump; the
  program counter leaves the `OK` set).
- Fall-through, indirect transfers, return labels and FFI behavior are each
  a case of `step_ok` or of the value invariant. A `Call` line would need a
  return-label argument; the hypothesis excludes it and the exact program has
  none (U369).
- Non-vacuity: `region_hyp_witness` shows the hypothesis is satisfiable.

## 3. Bridge and application to the exact lab program

Theory `forge_labRegionWalk` (generic): `hyp_walk_region_hyp`. An executable
walk over a program, which visits lines as `labSem$asm_fetch_aux` counts
them, implies `region_hyp (loc_good okp code) okp code`. `loc_good okp code v`
says: if `v` is a `Loc` and it resolves under the published `loc_to_pc`, it
resolves to a counter that satisfies `okp`.

Theory `forge_refundLabRun`. `L` is the published `to_lab` output for
`refund_alloc_oracle` (U368). `OKL = pc_ok [Install_location; InstallData_location] L`.

- PROVED `refund_lab_region_hyp`: `region_hyp (loc_good OKL L) OKL L ∧ OKL 0`,
  by in-logic evaluation of the walk on `L`. For {29} alone the walk is
  false (PROVED `refund_lab_walk_not_closed_29`).
- PROVED `refund_lab_run_avoids_install`:

```
s.code = L ∧ val_inv (loc_good OKL L) s ∧ OKL s.pc ∧ evaluate (s with clock := k) = (res,t) ⇒
OKL t.pc ∧ t.code = L ∧ val_inv (loc_good OKL L) t ∧
∀i bs n. asm_fetch t ≠ SOME (LabAsm Install i bs n)
```

Theory `forge_refundLabRunInit`, PROVED `refund_lab_init_run_avoids_install`,
for the published initial lab state `lab_to_targetProof$make_init`:

```
(∀a. loc_good OKL L (m a)) ∧
evaluate (make_init mc0 ffi0 t0 m dm0 sdm0 ms0 L cmp0 cbpos0 cbspace0 coracle0 with clock := k) = (res,s2) ⇒
OKL s2.pc ∧ s2.code = L ∧ ∀i bs n. asm_fetch s2 ≠ SOME (LabAsm Install i bs n)
```

The register and program-counter premises are discharged: `make_init` puts
`Word` values in every register and starts at counter 0.

Remaining premise: `∀a. loc_good OKL L (m a)`, for every address `a` of the
initial lab memory `m`. The published `good_init_state` gives `Word` values
at byte-aligned addresses only. So this premise is not yet discharged from
`installed`. It is OPEN. Either prove that `m` holds no `Loc` anywhere, or
weaken the invariant to aligned addresses (the semantics reads and writes
words only at aligned addresses).

## 4. Dependencies and the oracle audit

```
refund_lab_init_run_avoids_install
  └ refund_lab_run_avoids_install
       ├ region_prefix ← region_run ← region_one_step ← 11 branch lemmas
       │     ← asm_inst_val_inv, write_bytearray_val_inv (U370)
       └ refund_lab_region_hyp
             ├ hyp_walk_region_hyp (generic)
             ├ hyp_walk1_eq, line_ok1_eq, loc_pc_thm (executable forms = generic forms)
             ├ cv_eval of the walk on lab_forge8
             └ lab_forge8_to_lab (U368)
```

`refund_lab_refs_resolve_outside` (U369) is not a dependency: the walk
re-checks label resolution in the exact form that `step_ok` needs. It stays
as an independent static fact.

Oracle audit. The only oracle constant in the new statements is
`forge_refundLabClosure$refund_alloc_oracle` (checked in the import logs).
No theorem that names the unspecified `forge_refundArm8Compile$oracle` is
used. No claim is made that those older theorems apply to
`refund_alloc_oracle`; their re-statement is NOT_RUN. What links the new
results to the executable is `refund_alloc_compiled` and
`refund_alloc_target` (U368): the published compiler maps `L` to the stored
`code`.

Closure: 394 theory nodes for the last theorem; four Boolean axioms. No
axiom, no `cheat`. The trusted base includes `cv_compute` and the published
cv translation, as before.

## 5. P3 readiness

P2 is established at lab level, up to the memory premise. P3 is NOT_RUN.
Precise modifications that P3 needs in the published
`lab_to_targetProof$compile_correct` (line 7677):

1. Its conclusion gives one target result for some clock `k`. P3 needs, for
   every target clock `j` below that, that a `TimeOut` prefix state has a
   program counter different from `mc.install_pc`.
2. In each case of that proof the target takes the steps of one lab line.
   The intermediate counters are inside `prog_addresses` (the encoded line),
   and `install_pc ∉ prog_addresses` by `start_pc_ok`. The only step that
   leaves to `install_pc` is the encoded jump of the `Install` line.
3. So the change is a strengthened conclusion plus one prefix argument per
   case, with the new premise "the lab run never fetches `Install`", which
   `region_prefix` provides. The `Install` case itself becomes unreachable.
4. The proof script is about 1700 lines. A modified copy must be rebuilt in
   the CakeML proof context. Not attempted.

Also needed before the composition: the memory premise of section 3; the
re-statement of the backend chain for `refund_alloc_oracle` (so that the lab
state of the published simulation is the `make_init` state for `L`).

`install_exclusion_suffices` (U360) is not applicable until P3 holds.

## 6. Installed-state obligations

| # | Obligation | Status |
| --- | --- | --- |
| 1 | Complete machine record and abstract state | OPEN |
| 2 | Start-up code | OPEN |
| 3 | FFI code meets `ffi_interfer_ok` | OPEN |
| 4 | Installer | OPEN. Done: word closure, lab closure, lab runtime exclusion (one memory premise). Remaining: memory premise, P3 |
| 5 | Loader | OPEN |
| 6 | Processor and operating system | OPEN |

## 7. Executed commands

Run directories: `results/refund-p2-lab-invariant-local-20261113/attempt-0002`
(generic) and `results/refund-p2-lab-run-local-20261113/attempt-0001`
(application).

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Generic `run_case.py explore-0001` … `explore-0009` | 0 each | Staged explorations; residues printed per stage |
| `run_case.py step-0001 …` | 1 | SCRIPT ERROR in the type annotation of the non-vacuity witness, after the 16 other proofs passed. Nothing exported. Counted as one failed run of the store script |
| `run_case.py step-0002 …` | 0 | Seventeen theorems |
| `run_case.py step-import` | 1 | Reader-side error: a hand-written quantifier order for one branch lemma. Not a theorem failure |
| `run_case.py step-import-0002` | 0 | Five statements (outer quantifier order ignored for the branch lemma); 290 closure nodes |
| `run_case.py step-repeat` | 1 | Repeat of the failed `step-0001` source |
| `run_case.py step-repeat-0002` | 0 | Exports byte-identical |
| `run_case.py step-missing-hyp` | 1 | Intended statement mismatch |
| `run_case.py step-refute-weakened` / `-v2` | 1 / 1 | SCRIPT ERRORS after the counterexample fact was proved. Not counted |
| `run_case.py step-refute-weakened-v3` | 1 | Intended: weakened claim refuted by a concrete run |
| `run_case.py walk-0001` / `walk-import` / `walk-repeat` | 0 / 0 / 0 | Three theorems; byte-identical |
| Application `run_case.py explore-0001` / `0002` / `0003` | 1 / 1 / 0 | Two script errors (a variable name that is a constant; a rename that hit an ML name), then walk check `T` for {29, 31}, `F` for {29} |
| `run_case.py run-0001 …` | 0 | Five theorems, first attempt |
| `run_case.py run-import` / `run-repeat` | 0 / 0 | Four exact statements, 389 closure nodes; byte-identical |
| `run_case.py run-missing-premise` / `run-naive` | 1 / 1 | Intended mismatch; fresh evaluation rejects section 29 alone |
| `run_case.py init-0001` | 1 | SCRIPT ERROR: a variable name that is an overloaded constant. Not counted |
| `run_case.py init-0002` / `init-import` / `init-repeat` | 0 / 0 / 0 | One theorem; 394 closure nodes; byte-identical |
| `python3 -I -B verify_cases_r7.py` / two altered copies | 0 / 1 / 1 | Byte, exit and marker binding only |

Source SHA256: generic step `f57e63ea21b53a5ab14ef934f74a8e87b8dc8f25c68a894c7861b9c289a5c4bd`,
walk `98081a71d2d143b2a19c1da8d36b8f278cfbc2e395886cb3b588857dabe31285`,
application `a235171d3fd0444743bc1f61652e7d754b527e5b319928fdbd618b954ee84efc`.
Theory data: `forge_labRegionStep` `7cf102992292a82c9c05efcfda13e908f4457fa9d21d00805426546d2ba42a53`,
`forge_labRegionWalk` `9a16104455ea50a744d7a7ed28a18ec99a032fc33544275ac3c3618515dc758e`,
`forge_refundLabRun` `b83205b1a6b810bc6a2bd8c3ae64bf56b5e64f89c3a263e1bec13dac7b64e53a`,
`forge_refundLabRunInit` `e92e9541bf4718583bb89f621e1cc174cc183676d24a5933e7113220c74fe450`.
Clean replay of these theories: NOT_RUN. The packet omits the byte-identical
exports of the repeat runs.

## 8. Next smallest obligation

The memory premise: either `∀a. loc_good OKL L (m a)` from the published
initial-state facts, or the region invariant restated for byte-aligned
addresses (then `good_init_state` discharges it). After that, P3 as in
section 5.
