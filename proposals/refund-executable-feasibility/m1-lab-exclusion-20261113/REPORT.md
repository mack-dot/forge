# U374–U376: lab-level installer exclusion from `good_init_state`, with no extra memory premise

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted and not used. Nothing committed in
this run. All results are local: same machine, same agent, cached parents.

Statuses: PROVED (HOL kernel accepted it in this session; `DISK_THM` only, no
hypotheses, no tagged axioms; exact-statement import), NOT_RUN, OPEN.

| Item | Status |
| --- | --- |
| All-address memory premise of U372 | **NOT DERIVABLE** from the aligned-address clause (countermodel PROVED). Replaced, not assumed |
| Revised invariant (memory constrained on a covered address set) | **PROVED** for every instruction, one step, whole run, every prefix |
| Exact initial state satisfies the revised invariant | **PROVED** from the memory clause of `good_init_state` |
| Lab-level installer exclusion, no extra memory premise | **PROVED** (`refund_lab_good_init_avoids_install`) |
| P3 target prefix lemma | **NOT_RUN** (preparation in section 5) |
| Installer exclusion at target level (U298) | **NOT ESTABLISHED** |

## 1. How memory is modelled (task 1)

`labSem` memory is a total function from addresses to `Word` or `Loc`
values. Reads and writes:

| Operation | Address used | Can it move a `Loc`? |
| --- | --- | --- |
| Word load (`mem_load`) | The computed address `w`, with the assertion `w2n w MOD (dimindex DIV 8) = 0 ∧ w ∈ mem_domain`. If the assertion fails the state is marked failed and `evaluate` returns `Error` | Yes: the register gets `s.mem w`. Only when `w` is aligned |
| Word store (`mem_store`) | Same assertion | Yes: memory gets the register value |
| Byte and 32-bit loads | `byte_align w`; the cell must be a `Word` | No: the result is a `Word` |
| Byte and 32-bit stores | `byte_align w`; the cell must be a `Word` | No: the cell stays a `Word` |
| FFI result (`write_bytearray`) | Byte stores | No |
| Shared-memory operations | No lab memory access | No |

So a code pointer can reach a register from memory only through a successful
word load, and that load is at an aligned address.

## 2. The all-address premise is too strong (task 2)

PROVED `all_address_premise_not_implied`:

```
∀G v0. ¬G v0 ⇒ ∃m:word64 → 64 word_loc.
  (∀a. ∃w. m (byte_align a) = Word w) ∧ ¬(∀a. G (m a))
```

For any value predicate with one bad value there is a memory that meets the
aligned-address clause of `good_init_state` and breaks the all-address
premise (the bad value sits at address 1). So that premise does not follow
from `good_init_state`. It was not assumed.

## 3. Revised invariant (tasks 3 and 4)

Theory `forge_labRegionAligned`, generic in `G`, `D`, `OK` and the code:

- `mval_inv G D s`: `G` of every register, and `G (s.mem a)` for every `a`
  with `D a`.
- `load_covered D`: every address `w` with `w2n w MOD (dimindex DIV 8) = 0`
  is in `D`.
- `region_inv2 G D OK code s`: `s.code = code`, `region_hyp G OK code` (the
  unchanged static hypothesis of U370), `load_covered D`, `mval_inv G D s`,
  `OK s.pc`.

All preservation lemmas were proved again for this invariant:

- `asm_inst_mval_inv`: `(∀w. G (Word w)) ∧ load_covered D ∧ mval_inv G D s ∧ ¬(asm_inst i s).failed ⇒ mval_inv G D (asm_inst i s)`.
  The non-failure premise is what `evaluate` checks before it continues. A
  successful word load is at an aligned address, hence in `D`.
- `write_bytearray_mval_inv`: FFI byte writes keep the invariant on `D`.
- Eleven branch lemmas `region2_step_*` (`Inst`, `JumpReg`, `ShareMem`,
  `Label`, `Halt`, `LocValue`, `Jump`, `JumpCmp`, `Call`, `Install`,
  `CallFFI`), `region2_one_step`, `region2_run`, and `region2_prefix`:

```
region_inv2 G D OK code s ∧ evaluate (s with clock := k) = (res,t) ⇒
region_inv2 G D OK code t ∧ OK t.pc ∧ t.code = code ∧
∀i bs n. asm_fetch t ≠ SOME (LabAsm Install i bs n)
```

- `load_covered_byte_align_64`: for 64-bit words the set
  `{x | ∃a. x = byte_align a}` is load-covered.

The runtime property is unchanged from U371: the conclusion about the
program counter, the code and the `Install` line is the same. Only the
memory part of the invariant is weaker, and the theorem is correspondingly
stronger (it needs less of the start state).

## 4. The strongest established lab-level theorem (tasks 5 and 6)

Theory `forge_refundLabExclusion`. `L` is the published `to_lab` output for
`refund_alloc_oracle` (U368).

PROVED `refund_lab_good_init_avoids_install`:

```
good_init_state mc0 ms0 bytes0 cbs0 t0 m dm0 sdm0 ∧
evaluate (make_init mc0 ffi0 t0 m dm1 sdm1 ms0 L cmp0 cbpos0 cbspace0 coracle0 with clock := k) = (res,s2) ⇒
pc_ok [Install_location; InstallData_location] L s2.pc ∧
s2.code = L ∧
∀i bs n. asm_fetch s2 ≠ SOME (LabAsm Install i bs n)
```

`good_init_state` is the published `targetSem` predicate, `make_init` the
published initial lab state of `lab_to_targetProof`, `evaluate` the published
`labSem` evaluator. `k` is arbitrary: the statement covers every evaluator
prefix. All other variables are universally quantified, including the memory
domains, the compiler function and the compile oracle of the lab state.

Also PROVED, with the exact clause that is used:
`refund_lab_aligned_init_avoids_install`, whose only state premise is
`∀a:word64. ∃w. m (byte_align a) = Word w`.

The import audits the structure of the final theorem: two premises
(`good_init_state …` and the `evaluate` equation); no `loc_good`, `val_inv`,
`mval_inv` or `region_hyp` premise; the only oracle constant is
`refund_alloc_oracle`.

Dependencies:

```
refund_lab_good_init_avoids_install
  └ refund_lab_aligned_init_avoids_install
       ├ region2_prefix ← region2_run ← region2_one_step ← 11 branch lemmas
       │     ← asm_inst_mval_inv, write_bytearray_mval_inv
       ├ load_covered_byte_align_64
       ├ refund_lab_region_hyp (U372)  ← walk evaluation, lab_forge8_to_lab (U368)
       └ targetSem$good_init_state_def, lab_to_targetProof$make_init_def [published]
```

No axiom, no `cheat`, no new assumption about the initial state. Closure:
395 theory nodes; four Boolean axioms. Not circular: the theorem does not
assume exclusion in any form, and its premises are satisfiable in the
published development (they are premises of the published compiler theorem).

What it does not say: it is about the lab semantics of `L`. It is not about
target evaluator prefixes (U298). It is stated for `refund_alloc_oracle`.

## 5. P3 preparation (task 7): not a result

P3 is NOT_RUN. Nothing below is proved.

Where the lab theorem plugs in. The published
`lab_to_targetProof$semantics_compile` (line 11295) has the premise
`good_init_state mc_conf ms bytes cbspace t m dm sdm` and relates the machine
to `make_init mc_conf ffi t m (dm ∩ byte_aligned) (sdm ∩ byte_aligned) ms code …`.
That is the shape of the theorem above (same `m`, any domains).

Prefix-state additions needed in `compile_correct` (line 7677):

1. New premise: for every clock, the lab run from `s1` does not fetch
   `LabAsm Install` (from `region2_prefix`).
2. New conclusion: for every `j < s1.clock + k`, if the target evaluator at
   clock `j` returns `TimeOut` with state `ms'`, then
   `mc_conf.target.get_pc ms' ≠ mc_conf.install_pc`.
3. Per case of the induction: the target steps of one lab line stay inside
   `prog_addresses` until the line's last step; `install_pc ∉ prog_addresses`
   by `start_pc_ok`; halt and FFI entries differ from `install_pc` by
   `start_pc_ok`; the `Install` case is excluded by the new premise.
4. The clock bookkeeping (`evaluate_add_clock`-style lemmas) must carry the
   prefix statement through the composition of cases.

Backend chain for `refund_alloc_oracle`:

- `refund_alloc_compiled` and `refund_alloc_target` (U368) are in place.
- The published `backendProof$compile_correct` is generic in the
  configuration, so it can be instantiated with
  `set_oracle arm8_backend_config refund_alloc_oracle`. The Forge theorems
  that sit on top of it (U291, U296, U347–U358) name the unspecified
  `oracle`. Their re-statement is NOT_RUN. No claim is made that they apply.

`install_exclusion_suffices` (U360) is not applicable until P3 holds.

## 6. Installed-state obligations

| # | Obligation | Status |
| --- | --- | --- |
| 1 | Complete machine record and abstract state | OPEN |
| 2 | Start-up code | OPEN |
| 3 | FFI code meets `ffi_interfer_ok` | OPEN |
| 4 | Installer | OPEN. Lab-level exclusion PROVED from `good_init_state`. Remaining: P3 and the chain for `refund_alloc_oracle` |
| 5 | Loader | OPEN |
| 6 | Processor and operating system | OPEN |

## 7. Executed commands

Run directories: `results/refund-p2-lab-aligned-local-20261113/attempt-0001`
(generic) and `results/refund-p2-lab-init-local-20261113/attempt-0001`
(application).

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Generic `run_case.py explore-0001` … `explore-0012` | 0, except 1 for `0001`, `0003`, `0005`, `0007`, `0010` | The exits 1 are explorations whose script stopped after an open lemma (memory-operation case, CallFFI memory step) or a missing library load. Not counted; no stored-proof attempt failed |
| `run_case.py aligned-0001 aligned-0001.sml …` | 0 | Twenty theorems, first attempt |
| `run_case.py aligned-import` / `aligned-repeat` | 0 / 0 | Five exact statements, 290 closure nodes; byte-identical |
| `run_case.py aligned-missing-coverage` | 1 | Intended statement mismatch |
| Application `run_case.py explore-0001` … `explore-0011` | 0, except 1 for `0001`, `0002`, `0003`, `0009` | Type errors in goal construction (the lab program type has no word-size parameter). Not counted |
| `run_case.py excl-0001 excl-0001.sml …` | 0 | Two theorems, first attempt |
| `run_case.py excl-import` / `excl-repeat` | 0 / 0 | Two exact statements with structure audit, 395 closure nodes; byte-identical |
| `run_case.py excl-missing-init` | 1 | Intended statement mismatch |
| `python3 -I -B verify_cases_r8.py` / two altered copies | 0 / 1 / 1 | Byte, exit and marker binding only |

Source SHA256: generic `93745080501cb58b54b7edbed53c8223ba977cc4f86de7efbdd30988f5b8860f`,
application `392aae63223888f133a4e385ef89105545fcea64484a8e9afa64f29ff6928679`.
Theory data: `forge_labRegionAligned` `0c735af977fb8a6043057f4a589fef08909f1687cc648b58ae1e8fa9756fba7d`,
`forge_refundLabExclusion` `41c11f8c7075f37bc40ebc53a107d865b90a757b8b52ce3f8c5362d465db1a80`.
Limit of the import: it rebuilds the two expected statements with the same
term construction as the proof script; the structure audit (premise count and
heads, constants) is independent of that construction. Clean replay: NOT_RUN.
The packet omits the byte-identical exports of the repeat runs.

## 8. Next minimal obligation

P3, first step: state the strengthened `compile_correct` (items 1 and 2 of
section 5) and prove its base cases (clock 0, `Halt`, a plain `Inst` line) in
a copy of the published proof context. That shows whether the per-line prefix
argument goes through before the full 1700-line proof is modified.
