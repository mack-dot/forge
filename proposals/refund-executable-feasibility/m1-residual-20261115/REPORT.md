# U391: five of the seven residual installed-state clauses proved at `refund_mc 0x1000040D0w envmc`; the residual is now `interference_ok` and `ffi_interfer_ok`, both unproved

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted. Nothing committed.
Local results: same machine, same agent, cached parents. No clean replay. No independent replay. No native execution.

Run directory: `results/refund-residual-local-20261115/attempt-0001`.
All U386–U390 theories are imported unchanged. The published `compile_correct'` control is re-checked in `import-0001`.
No definition was changed. No failed proof was replaced by an assumption.

## 1. Commands and actual exits

`python3 -I -B run_case.py <case> <source> <deps…>` through `go.sh`, `go-res.sh`, `go-imp.sh` (CakeML context).
Exact argument vectors: `records/res/<case>/command.json`. Full list: `records/exits.json`.

| Case | Exit | Kind |
| --- | --- | --- |
| `diag-0001` | 0 | diagnostic: form of the stored compile theorem; no theorem stored |
| `ffi-0001` | 0 | FFI names and `shmem_extra` of `refund_lab_conf2`, 87 s |
| `res-0001`, `res-0002` | 1 | authoring (goal shape; one control) |
| `res-0003` | 0 | five clauses, reduction, compositions, four negative controls, 93 s |
| `import-0001` | 0 | 76 exact statements, 520 closure nodes, controls |
| `ffi-repeat`, `res-repeat` | 0 each | every exported file byte-identical |

Tool failures: none. Memory failures: none. Logical failures: none.
The repeats are cheap local repeats with cached parents. They are not a clean or independent replay.

## 2. FFI names and `shmem_extra` in the proof context (`forge_refundFfiFacts`, `ffi-0001`)

Finding (`diag-0001`): the published theorem `refund_arm8_compiled` is stated for the specified constants `oracle` and `info`.
Nothing relates `oracle` to the recorded `refund_alloc_oracle`, so its `ffi_names` and `shmem_extra` facts do not apply to `refund_lab_conf2`
directly. No stored theorem gave the name list of `refund_lab_conf2`.

Method (as in U345): the published in-logic compiler `compile_cake_arm8` is evaluated again with `refund_alloc_oracle`.
The stored `code`, `data`, `ffis` and `conf` constants must be syntactically the recomputed values (`SAME_AS_STORED code data ffis conf`).
Published `compile_cake_arm8_thm`, `compile_eq_to_target`, `attach_bitmaps_SOME` and stored `refund_lab_compile` then give:

- `refund_lab_conf2_ffis`: `refund_lab_conf2.shmem_extra = [] ∧ ffis = ffinames_to_string_list (the [] refund_lab_conf2.ffi_names)`.
- `refund_ffi_names`: `∃names. refund_lab_conf2.ffi_names = SOME names ∧ LENGTH names = 4 ∧ mmio_pcs_min_index names = SOME 4 ∧ ffinames_to_string_list names = [«read»; «write»; «close»; «open_in»] ∧ refund_lab_conf2.shmem_extra = []`.
- General lemmas: `mmio_index_LENGTH_all_ExtCall`, `ffinames_to_string_list_LENGTH`.

The count 4 is proved, not read from the symbol table. All four names are external calls; there is no shared-memory entry.

## 3. The five clauses (`forge_refundResidual`, `res-0003`)

Record: `refund_mc 0x1000040D0w envmc`. `refund_mc_concrete_fields` evaluates its fields: entry addresses
`[0x1000040A0w; 0x100004090w; 0x100004080w; 0x100004070w]`, halt `0x1000040C0w`, install `0x1000040B0w`, `mmio_info = []`,
shared set ∅, program addresses those of `envmc`, target `arm8_target`.

`refund_stub_outside_domain`: `refund_heap_clear h e ∧ 0x100000000w ≤₊ a ∧ a <₊ 0x1000040D0w ⇒ a ∉ refund_mem_dm h e`.

Each clause is proved separately from `refund_heap_clear h e ∧ envmc.prog_addresses = refund_mem_dm h e ∧ ms.PC = 0x1000040D0w`:

| U390 residual clause | Result |
| --- | --- |
| `start_pc_ok mc0 ms.PC` | PROVED. Halt and install addresses outside the program and shared sets; both pc equations; `1w && pc = 0w`; index 4; for each index below 4: entry address outside both sets, different from halt and install, and `find_index` gives the index; the upper range is empty; lengths equal |
| `∀a. byte_align a ∈ shared_addresses ⇒ a ∈ shared_addresses` | PROVED (shared set ∅) |
| `DISJOINT prog_addresses shared_addresses` | PROVED (shared set ∅) |
| `refund_lab_conf2.ffi_names = SOME mc0.ffi_names` | PROVED |
| `mmio` clause | PROVED (`shmem_extra = []`, index 4, size bound) |
| `interference_ok mc0.next_interfer (mc0.target.proj mc0.prog_addresses)` | KEPT, UNPROVED |
| `ffi_interfer_ok ms.PC mc0` | KEPT, UNPROVED |

`refund_installed_rest2 mc0 ms ⇔ interference_ok mc0.next_interfer (mc0.target.proj mc0.prog_addresses) ∧ ffi_interfer_ok ms.PC mc0`
(the two stored clauses, taken unchanged by program from `refund_installed_rest_def`).

`refund_installed_rest_reduced`: `refund_heap_clear h e ∧ envmc.prog_addresses = refund_mem_dm h e ∧ ms.PC = 0x1000040D0w ∧ refund_installed_rest2 (refund_mc 0x1000040D0w envmc) ms ⇒ refund_installed_rest (refund_mc 0x1000040D0w envmc) ms`.

## 4. Strongest theorem

`refund_behavior_from_entry_reduced`:

```
refund_entry_pre s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧ refund_heap_clear h e ∧
envmc.prog_addresses = refund_mem_dm h e ∧
stdin_content fs = SOME text ∧ wfcl cl ∧ wfFS fs ∧ STD_streams fs ⇒
∃ms. arm8_run 27 s = SOME ms ∧ ms.PC = 0x1000040D0w ∧
     (refund_installed_rest2 (refund_mc 0x1000040D0w envmc) ms ⇒
      ∃io_events. machine_sem (refund_mc 0x1000040D0w envmc) (basis_ffi ext cl fs) ms ⊆
                  extend_with_resource_limit {Terminate Success io_events})
```

Also stored: `refund_installed_from_entry_reduced` (concludes `refund_installed_no_handler (refund_mc 0x1000040D0w envmc) ms 428 0`
under the two-clause residual) and `refund_u298_exclusion_from_entry_reduced` (the exact U298 statement at this record; no behaviour-set
statement; for every installer handler).

## 5. Assumption ledger

| Premise | Class |
| --- | --- |
| `refund_entry_pre s h stk e` (image in memory at slide 0, control bits, pc, slot values, header separation) | ASSUMED |
| `aligned 3 e`, `h ≤₊ e`, `8192w ≤₊ e − h` | ASSUMED |
| `refund_heap_clear h e` | ASSUMED, explicit |
| `envmc.prog_addresses = refund_mem_dm h e` | ASSUMED (choice of the machine record) |
| `stdin_content fs = SOME text`, `wfcl`, `wfFS`, `STD_streams`; FFI model `basis_ffi` | ASSUMED |
| `refund_installed_rest2 (refund_mc 0x1000040D0w envmc) ms` | UNPROVED; satisfiability not shown |
| ML file reader (U389); L3 ARMv8 model; recorded allocation oracle (checked by recomputation) | as before |

Dependency closure (`import-0001`): 520 theory nodes; axioms only the four of `bool`; every stored theorem and definition of the two new
theories has tag `DISK_THM` only and no hypothesis. `forge_refundFfiFacts`: 6 theorems, 1 definition (the re-translated program constant).
`forge_refundResidual`: 10 theorems, 1 definition.

## 6. Remaining obligations: exact expressions and smallest missing lemmas

1. `interference_ok (refund_mc 0x1000040D0w envmc).next_interfer ((refund_mc 0x1000040D0w envmc).target.proj (refund_mc 0x1000040D0w envmc).prog_addresses)`.
   By the published definition and the stored field facts this is
   `∀i ms. arm8_target.proj (refund_mem_dm h e) (envmc.next_interfer i ms) = arm8_target.proj (refund_mem_dm h e) ms`.
   Smallest missing lemma: that equation for the chosen `envmc.next_interfer`. For the identity environment it is immediate, but then the
   statement "the real processor and operating system change nothing that `arm8_proj` sees between steps" becomes the assumption.
   Class: OPEN (processor and OS obligation). Not established.
2. `ffi_interfer_ok 0x1000040D0w (refund_mc 0x1000040D0w envmc)`.
   By the published definition, for each of the 4 names (index below 4) and each state related to an asm state `t1` at the entry address
   `0x1000040D0w − n2w ((3 + index) * 16)` with a readable argument pair: the state `envmc.ffi_interfer k (index, new_bytes, ms2)` must be
   `arm8_ok`, have its pc at `t1.regs 30`, hold in the domain exactly `asm_write_bytearray (t1.regs 2) new_bytes t1.mem`, and keep
   the callee-saved registers (19–28, except avoided register 26). The shared-memory half is vacuous here (index 4, no such name).
   Smallest missing lemma: that statement for a definite `envmc.ffi_interfer`. This needs a model of the four C functions and their
   stubs (`ffiread`, `ffiwrite`, `fficlose`, `ffiopen_in` in `basis_ffi.c`, and the code at `0x100004070`–`0x1000040AF`).
   No published ARMv8 lemma exists for it (`arm8_configProof` has none). Class: OPEN (FFI-code obligation). Not established.

Other open items, unchanged: the entry state and the image premise (loader, C run-time); load slide (`MH_PIE` set; all theorems at
slide 0); `refund_heap_clear` and the program-address equation for a real process; absent input and general `ffi`; clean replay,
independent replay and native execution NOT RUN. The installed-state predicate is not established without the two-clause residual.

## 7. Negative controls

Stored theorems (`res-0003`):

1. `wrong_base0_rejected`: `base0 ≠ pc ⇒ ¬start_pc_ok (refund_mc base0 envmc) pc`.
2. `halt_stub_in_domain_rejected`: `base0 − n2w ffi_offset ∈ envmc.prog_addresses ⇒ ¬start_pc_ok (refund_mc base0 envmc) pc`.
3. `heap_on_halt_stub_rejected`: a heap range that contains `0x1000040C0` refutes `start_pc_ok` at the concrete record.
4. `ffi_entry_stub_in_domain_rejected`: `0x1000040A0w ∈ envmc.prog_addresses ⇒ ¬start_pc_ok (refund_mc 0x1000040D0w envmc) 0x1000040D0w`.

`import-0001`: all U386–U390 exact statements, negative controls and scope controls pass again. New scope controls:
`refund_installed_rest2` is exactly the two clauses and occurs only as a premise; no U391 theorem states `interference_ok`,
`ffi_interfer_ok`, or the installed-state predicate without it; every U391 theorem about `arm8_run` is at slide 0 with
`refund_entry_pre` and `refund_heap_clear` as premises; the reduced exclusion theorem contains no behaviour-set statement.

Not shown: that the two-clause residual is satisfiable together with the other premises.

## 8. Counterexamples and blockers

No counterexample. No logical blocker.

## 9. Smallest next step

Owner decision first: which of the two clauses to treat, and in which form.
(a) `interference_ok`: state it as a named, explicit environment assumption for a definite `next_interfer`; small proof, large assumption.
(b) `ffi_interfer_ok`: start with one name. The smallest unit is the stub at one entry address plus one C function, with an ARMv8 step
proof in the style of `cml_main_run`. This is the first step of the FFI authorization and confinement property (P3 of the
behavior-containment proposal) for the refund executable.

M1 open. Integration EXIT NOT_ESTABLISHED. end_to_end=false.
