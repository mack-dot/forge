# U390: explicit asm state and memory domains; 23 of 30 installed-state clauses proved for the start-up end state at slide 0; the other 7 are one explicit residual premise

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted. Nothing committed.
Local results: same machine, same agent, cached parents. No clean replay. No independent replay. No native execution.

Run directory: `results/refund-memory-domain-local-20261115/attempt-0001`.
All U386–U389 theories are imported unchanged. The published `compile_correct'` control is re-checked in `import-0003`.

## 1. Commands and actual exits

`python3 -I -B run_case.py <case> <source> <deps…>` through `go.sh`, `go-asm.sh`, `go-imp.sh` (CakeML context).
Exact argument vectors: `records/dom/<case>/command.json`. Full list: `records/exits.json`.

| Case | Exit | Kind |
| --- | --- | --- |
| `dom-0001` | 0 | domains, asm state, domain lemmas, `target_state_rel`, `target_configured`, end state, 93 s |
| `asm-0001` | 1 | authoring (clause classification; two closing tactics) |
| `asm-0002` | 0 | clause proofs, forward assembly, compositions, controls, 76 s |
| `import-0001`, `import-0002` | 1 | authoring (form of two expected terms) |
| `import-0003` | 0 | 65 exact statements, 518 closure nodes, controls |
| `dom-repeat`, `asm-repeat` | 0 each | every exported file byte-identical |

Tool failures: none. Memory failures: none. Logical failures: none.
The two repeats are cheap local repeats with cached parents. They are not a clean or independent replay.

## 2. Definitions (`forge_refundInstalledDomains`, `dom-0001`)

- `refund_code_dm = {a | 0x1000040D0w ≤₊ a ∧ a <₊ 0x100024000w}`: compiled code (130436 bytes) and code buffer (428 bytes).
- `refund_mem_dm h e = refund_code_dm ∪ {w | h ≤₊ w ∧ w <₊ e} ∪ refund_bitmaps_dm`: code, heap and stack, bitmaps.
  The heap-and-stack set is the set that the installed-state predicate itself names (`heap_stack_dm`); `h` and `e` are the values of x1 and x3.
  `refund_bitmaps_dm` is the U389 set.
- `refund_heap_clear h e ⇔ ∀a. h ≤₊ a ∧ a <₊ e ⇒ ¬(0x100000000w ≤₊ a ∧ a <₊ 0x100030F30w)`.
  This is the explicit heap/image non-overlap premise. It is a premise of the theorems. It is not a fact about a real loader or `malloc`.
- `refund_t ms = <| regs := (λi. ms.REG (n2w i)); fp_regs := (λi. 0w); mem := ms.MEM; mem_domain := refund_mem_dm (ms.REG 1w) (ms.REG 3w); pc := ms.PC; lr := 30; align := 2; be := F; failed := F |>`.
- `refund_end_state ms`: user mode, the four control bits, no exception, `ms.PC = 0x1000040D0w`, x1 and x3 aligned, ordered, 8192 apart,
  `refund_heap_clear (ms.REG 1w) (ms.REG 3w)`, `refund_image_mem 0w ms.MEM`, and the five header words.

## 3. Theorems

End state and state relation (`dom-0001`):

- `refund_end_state_established`: `refund_entry_pre s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧ refund_heap_clear h e ⇒ ∃ms. arm8_run 27 s = SOME ms ∧ ms.REG 1w = h ∧ ms.REG 3w = e ∧ refund_end_state ms`.
  Preservation across start-up: the image predicate at `ms` comes from U389 `refund_image_preserved` and the frame of `cml_main_run_frame`.
- `refund_t_target_state_rel`: `refund_end_state ms ⇒ target_state_rel arm8_target (refund_t ms) ms`.
- `refund_t_target_configured`: `is_arm8_machine_config mc0 ∧ mc0.prog_addresses = refund_mem_dm (ms.REG 1w) (ms.REG 3w) ⇒ target_configured (refund_t ms) mc0`.
  Published `target_configured` requires `t.mem_domain = mc.prog_addresses`. So the program-address set of the machine record must be exactly the explicit domain.
- Domain lemmas: `refund_bitmaps_dm_range`, `refund_heap_bitmaps_closed`, `refund_heap_bitmaps_disjoint`, `refund_code_addr_in_dm`,
  `refund_code_addr_not_excluded`, `refund_code_bytes_in_mem`, `refund_code_buffer_in_dm`, `refund_heap_bitmaps_subset`, `refund_code_loaded`.
- `refund_heap_clear_IMP_header_separation`: with the conditions on `e`, the new premise implies the 40-byte header separation of `refund_entry_pre`.

Assembly (`forge_refundInstalledAssembly`, `asm-0002`). The script instantiates the stored definition of `refund_installed_no_handler` with
`t = refund_t ms`, `m = λa. Word (mem_dword ms.MEM a)`, `bitmap_ptr = 0x10002C018w`, `bitmaps_dm = refund_bitmaps_dm`,
`sdm = mc0.shared_addresses`, `cbspace = 428`, `data_sp = 0`. It has 30 clauses. 23 are proved one by one. 7 are collected unchanged:

```
refund_installed_rest mc0 ms ⇔
  start_pc_ok mc0 ms.PC ∧
  interference_ok mc0.next_interfer (mc0.target.proj mc0.prog_addresses) ∧
  ffi_interfer_ok ms.PC mc0 ∧
  (∀a. byte_align a ∈ mc0.shared_addresses ⇒ a ∈ mc0.shared_addresses) ∧
  DISJOINT mc0.prog_addresses mc0.shared_addresses ∧
  refund_lab_conf2.ffi_names = SOME mc0.ffi_names ∧
  (the shared-memory `mmio` clause, unchanged)
```

The predicate is then derived forward in the kernel (conjunction, five existential introductions, the definition).

- `refund_installed_from_end_state`: `is_arm8_machine_config mc0 ∧ mc0.prog_addresses = refund_mem_dm (ms.REG 1w) (ms.REG 3w) ∧ refund_end_state ms ∧ refund_installed_rest mc0 ms ⇒ refund_installed_no_handler mc0 ms 428 0`.
- `refund_installed_from_entry`: the same from `refund_entry_pre`, the conditions on `e` and `refund_heap_clear h e`, for the state after the 27 steps.

**Strongest new theorem, `refund_behavior_from_entry`:**

```
refund_entry_pre s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧ refund_heap_clear h e ∧
envmc.prog_addresses = refund_mem_dm h e ∧
stdin_content fs = SOME text ∧ wfcl cl ∧ wfFS fs ∧ STD_streams fs ⇒
∃ms. arm8_run 27 s = SOME ms ∧
     (refund_installed_rest (refund_mc base0 envmc) ms ⇒
      ∃io_events. machine_sem (refund_mc base0 envmc) (basis_ffi ext cl fs) ms ⊆
                  extend_with_resource_limit {Terminate Success io_events})
```

`refund_u298_exclusion_from_entry` has the same premises and concludes, under the same residual, the exact U298 statement at `refund_mc`:
no `TimeOut` state has its pc at `install_pc`. It holds for every installer handler. It states nothing about the behaviour set.

Reading limits:

- The residual premise sits inside the existential. If the residual is false at the end state, the theorem says nothing.
  `refund_installed_rest` is not proved and is not shown satisfiable.
- `start_pc_ok` in the residual forces `base0` to be the end pc and keeps the halt, install and FFI entry addresses outside the program-address set.

## 4. Clause ledger for `refund_installed_no_handler (mc0) ms 428 0`

| # | Clause | Class |
| --- | --- | --- |
| 1 | `target_state_rel mc0.target t ms` | PROVED from `refund_end_state` |
| 2 | `target_configured t mc0` | PROVED given `mc0.prog_addresses = refund_mem_dm …` |
| 3, 5 | pc equation; pc alignment | PROVED |
| 4 | `start_pc_ok mc0 ms.PC` | RESIDUAL (obligation 1) |
| 6 | `interference_ok …` | RESIDUAL (obligation 6) |
| 7 | `ffi_interfer_ok ms.PC mc0` | RESIDUAL (obligation 3) |
| 8 | `code_loaded code mc0 ms` | PROVED |
| 9 | `bytes_in_mem ms.PC code ms.MEM (refund_mem_dm …) (heap ∪ bitmaps)` | PROVED |
| 10, 11 | heap ∪ bitmaps ⊆ domain; `byte_align` closure | PROVED |
| 12, 13 | shared-address closure; `DISJOINT prog_addresses shared_addresses` | RESIDUAL (simple for `refund_mc`: its shared set is ∅; not done here) |
| 14 | byte memory against word memory | PROVED |
| 15, 16 | code-buffer clause; size bound | PROVED |
| 17–21 | register alignment, bitmap pointer alignment, order, distance | PROVED from `refund_end_state` (values assumed at entry) |
| 22 | `DISJOINT heap bitmaps` | PROVED from `refund_heap_clear` |
| 23–27 | five header words | PROVED |
| 28 | bitmap `word_list` clause | PROVED |
| 29 | `refund_lab_conf2.ffi_names = SOME mc0.ffi_names` | RESIDUAL (proved for `refund_mc` in U388; not joined here) |
| 30 | shared-memory `mmio` clause | RESIDUAL |

"PROVED" means: proved from `is_arm8_machine_config mc0`, the program-address equation and `refund_end_state ms`. Those are premises.

By obligation: 5 (loader-memory content and domains) is now proved from the explicit premises; loader behaviour itself stays ASSUMED.
2 is CONDITIONAL on the entry state; slide OPEN. 6: `target_state_rel` done, `interference_ok` OPEN. 1: `target_configured` done,
`start_pc_ok` and the simple record clauses OPEN. 3 OPEN. 4 has no clause; the U298 exclusion holds for every handler.

## 5. Assumption ledger for `refund_behavior_from_entry`

| Premise | Class |
| --- | --- |
| `refund_entry_pre s h stk e` (image in memory at slide 0, control bits, pc, slot values, header separation) | ASSUMED |
| `aligned 3 e`, `h ≤₊ e`, `8192w ≤₊ e − h` | ASSUMED |
| `refund_heap_clear h e` | ASSUMED, explicit; not a fact about a real allocator |
| `envmc.prog_addresses = refund_mem_dm h e` | ASSUMED (choice of the machine record; ties the record to the run-time heap bounds) |
| `refund_installed_rest (refund_mc base0 envmc) ms` | RESIDUAL, unproved, satisfiability not shown |
| `stdin_content fs = SOME text`, `wfcl`, `wfFS`, `STD_streams`; FFI model `basis_ffi` | ASSUMED |
| ML file reader of U389; L3 ARMv8 model | as in U389 |

Dependency closure (`import-0003`): 518 theory nodes; axioms only the four of `bool`; every stored theorem and definition of the two new
theories has tag `DISK_THM` only and no hypothesis. `forge_refundInstalledDomains`: 13 theorems, 5 definitions.
`forge_refundInstalledAssembly`: 10 theorems, 1 definition.

## 6. Negative controls

Stored theorems (`asm-0002`):

1. `heap_on_code_rejected`: a heap range that contains `0x1000040D0` refutes `refund_heap_clear` and refutes the `bytes_in_mem` clause for every memory and domain.
2. `heap_on_bitmaps_rejected`: a heap range that contains `0x10002C018` refutes `DISJOINT heap bitmaps`.
3. `code_outside_domain_rejected`: a code address outside the domain refutes `bytes_in_mem`.
4. `prog_addresses_mismatch_rejected`: `mc0.prog_addresses ≠ (refund_t ms).mem_domain ⇒ ¬target_configured (refund_t ms) mc0`.
5. `unaligned_heap_end_not_closed`: the heap range `[0, 1)` is not closed under `byte_align`. The alignment premise is needed.

Non-vacuity: `refund_entry_and_heap_premises_satisfiable` (the constructed U389 witness also satisfies `refund_heap_clear`).
It is not evidence about a loader. It does not cover the residual premise.

`import-0003`: the U386–U389 exact statements, the seven U386 negative controls, the six U389 negative controls and all earlier scope
controls pass again. New scope controls: `refund_installed_rest` holds exactly the seven unproved clauses; it occurs only as a premise;
no U390 theorem states the installed-state predicate without it; every U390 theorem about `arm8_run` is at slide 0 and has
`refund_heap_clear` as a premise; the exclusion theorem contains no behaviour-set statement.

## 7. Slide and correspondence

- Mach-O code and bitmap correspondence: unchanged from U389 (`refund_file_code`, `refund_file_bitmaps`); U390 uses the same stored constants.
- Load slide: OPEN. Every address in `refund_code_dm`, `refund_heap_clear`, `refund_end_state` and `refund_t` is a link address.
  `MH_PIE` is set. No theorem covers a non-zero slide. Not independently proved; not measured.

## 8. Counterexamples and blockers

No new counterexample. No logical blocker. Not done: clean replay; independent replay (not started; it needs separate authorization
and a budget); native execution; loader, C run-time and slide models.

## 9. Smallest next step

Discharge the simple part of the residual at `refund_mc`: clauses 12, 13 and 29 (shared set ∅; stored `refund_mc_fields`), the
`mmio` clause (needs `refund_lab_conf2.shmem_extra = []` by evaluation), and `start_pc_ok` with `base0 = 0x1000040D0w`
(by the symbol table, the halt, install and FFI entry stubs are in `[0x100004070, 0x1000040D0)`, below `refund_code_dm`; this is an expectation, NOT RUN). Then the residual is
`interference_ok` and `ffi_interfer_ok` only: the processor/OS obligation and the FFI-code obligation.

M1 open. Integration EXIT NOT_ESTABLISHED. end_to_end=false.
