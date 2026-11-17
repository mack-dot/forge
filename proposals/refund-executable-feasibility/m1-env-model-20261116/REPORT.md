# U392: `interference_ok` discharged for a concrete identity environment; exact FFI contract for `ffi_interfer_ok`; an abstract FFI model satisfies it; the real environment and C code stay unproved

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted. Nothing committed.
Local results: same machine, same agent, cached parents. No clean replay. No independent replay. No native execution.

Run directory: `results/refund-env-model-local-20261116/attempt-0001`.
All U386–U391 theories are imported unchanged. The published `compile_correct'` control is re-checked in `import-0001`.
No stored definition was changed.

## 1. Commands and actual exits

`python3 -I -B run_case.py <case> <source> <deps…>` through `go.sh`, `go-imp.sh` (CakeML context).
Exact argument vectors: `records/env/<case>/command.json`. Full list: `records/exits.json`.

| Case | Exit | Kind |
| --- | --- | --- |
| `env-0001`, `env-0002` | 1 | authoring and exploration (goal shapes of the contract equivalence; one control) |
| `env-0003`, `env-0004` | 1 | authoring (one direction of the equivalence; one control) |
| `env-0005` | 0 | full theory `forge_refundEnvModel`, 104 s |
| `import-0001` | 0 | 94 statements (92 exact, 2 identical to published), 521 closure nodes, controls |
| `env-repeat` | 0 | every exported file byte-identical |

Tool failures: none. Memory failures: none. Logical failures: none.
The repeat is a cheap local repeat with cached parents. It is not a clean or independent replay.

## 2. Concrete `next_interfer` and `interference_ok`

Definition: `refund_id_interfer (i:num) (ms:arm8_state) = ms`.

- `refund_id_interfer_ok`: `∀proj. interference_ok refund_id_interfer proj`. PROVED.
- Status of `interference_ok`: DISCHARGED for the record whose `next_interfer` is `refund_id_interfer` (section 4).
  For a general or real environment: NOT ESTABLISHED.

The identity environment is an abstract modelling assumption. It says: between two machine steps nothing changes.
It is not a proof about the macOS scheduler, signals, interrupts, page faults or other threads.

Exact condition (the weakest relation that preserves the projection), `interference_ok_arm8_iff`:

```
interference_ok env (arm8_target.proj dm) ⇔
∀i ms. (env i ms).PSTATE = ms.PSTATE ∧ (env i ms).SCTLR_EL1 = ms.SCTLR_EL1 ∧ (env i ms).TCR_EL1 = ms.TCR_EL1 ∧
       (env i ms).exception = ms.exception ∧ (env i ms).REG = ms.REG ∧ (env i ms).PC = ms.PC ∧
       ∀a. a ∈ dm ⇒ (env i ms).MEM a = ms.MEM a
```

This is an equivalence, so nothing weaker suffices for this clause. An environment may change memory outside `dm` and any state
component that `arm8_proj` does not include. It may not change a general register, the pc, the listed control state, or a byte in `dm`.
A real preemption fits only if the kernel restores all of these before the next user instruction, and no other thread or signal
handler writes the protected domain. That is the real-system obligation; it is OPEN.

Non-identity example: `refund_outside_interfer dm f i ms = ms with MEM := (λa. if a ∈ dm then ms.MEM a else f i ms a)`.
`refund_outside_interfer_ok`: `∀dm f. interference_ok (refund_outside_interfer dm f) (arm8_target.proj dm)`.
`refund_outside_interfer_not_identity`: it differs from the identity when it writes an address outside `dm`.
The identity theorem is not generalized beyond these two stored environments and the equivalence.

## 3. FFI contract required by `ffi_interfer_ok`

Names (U391): index 0 `read` (entry `0x1000040A0`), 1 `write` (`0x100004090`), 2 `close` (`0x100004080`), 3 `open_in` (`0x100004070`).
`refund_ffi_names_list`: `refund_lab_conf2.ffi_names = SOME [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»]`.

Contract (definition `refund_ffi_contract dm ffi_i`), for every `k`, `index < 4`, `new_bytes`, machine state `ms2`, asm state `t1`:

- Pre-conditions: `t1.mem_domain = dm`; the two argument arrays are readable inside `dm` (x0 with length x1 gives `bytes`; x2 with length x3 gives `bytes2`);
  `LENGTH new_bytes = LENGTH bytes2`; `target_state_rel arm8_target (t1 with pc := 0x1000040D0w − n2w ((3 + index) * 16)) ms2`; `aligned 2 (t1.regs 30)`.
- Return-pc contract: `(ffi_i k (index,new_bytes,ms2)).PC = t1.regs 30` (the link register), and the result state is `arm8_ok`
  (user mode, the four control bits, no exception, pc aligned).
- Memory-write contract: for every `a ∈ dm`, the result byte is `asm_write_bytearray (t1.regs 2) new_bytes t1.mem a`.
  So inside the protected domain the call writes exactly `new_bytes` at x2 and nothing else.
- Register-preservation contract: registers 19, 20, 21, 22, 23, 24, 25, 27, 28 keep their values. All other registers are free.

`ffi_interfer_ok_iff_contract`: `ffi_interfer_ok 0x1000040D0w (refund_mc 0x1000040D0w envmc) ⇔ refund_ffi_contract envmc.prog_addresses envmc.ffi_interfer`.
It is an equivalence for a general `envmc`. The contract is therefore exact: no weaker FFI condition gives the clause.
The shared-memory half of the published definition is empty here (no such name). The empty-name clause is vacuous (no name is «»).

Observable-effect contract. `ffi_interfer_ok` does not mention the oracle. It holds for every `new_bytes`.
In the machine semantics the oracle `basis_ffi` supplies `new_bytes` and the event. For a real process this needs a separate statement:
the real call with the same name and arguments has the external effect that the oracle records, and it writes the oracle's result
bytes. That statement (FFI model conformance) is not part of `ffi_interfer_ok`, is not stated in HOL here, and is OPEN.

## 4. Abstract FFI model and the strongest theorem

`refund_abs_ffi k (index, new_bytes, ms) = ms with <| PC := ms.REG 30w; MEM := asm_write_bytearray (ms.REG 2w) new_bytes ms.MEM |>`
(stored with projections `FST`/`SND` of the argument).

- `refund_abs_ffi_contract`: `∀dm. refund_ffi_contract dm refund_abs_ffi`. So an abstract implementation can satisfy the contract. PROVED.
- `refund_abs_env envmc = envmc with <| next_interfer := refund_id_interfer; ffi_interfer := refund_abs_ffi |>`.
  The installer handler `install_interfer` stays a parameter.
- `refund_abs_env_rest2`: `ms.PC = 0x1000040D0w ⇒ refund_installed_rest2 (refund_mc 0x1000040D0w (refund_abs_env envmc)) ms`.

**Strongest theorem, `refund_behavior_abstract_env`:**

```
refund_entry_pre s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧ refund_heap_clear h e ∧
envmc.prog_addresses = refund_mem_dm h e ∧
stdin_content fs = SOME text ∧ wfcl cl ∧ wfFS fs ∧ STD_streams fs ⇒
∃ms. arm8_run 27 s = SOME ms ∧ ms.PC = 0x1000040D0w ∧
     ∃io_events. machine_sem (refund_mc 0x1000040D0w (refund_abs_env envmc)) (basis_ffi ext cl fs) ms ⊆
                 extend_with_resource_limit {Terminate Success io_events}
```

It has no residual premise. Also stored: `refund_installed_abstract_env` (the installed-state predicate holds for the abstract record)
and `refund_u298_exclusion_abstract_env` (the exact U298 statement at the abstract record, for every installer handler; no
behaviour-set statement).

## 5. Scope of the abstract-model guarantees

The three theorems of section 4 are about a model machine: the L3 ARMv8 step function on the exact code bytes, an environment that
does nothing between steps, and FFI calls that are replaced by one model transition each (write the oracle's bytes at x2, return to x30).
They are valid statements about that model. They are not statements about a process on macOS:

- The four C functions and their entry stubs are not modelled. `refund_abs_ffi` is not related to any executable byte.
- The C run-time, `libSystem`, the dynamic loader and the kernel are not modelled.
- The identity environment is assumed, not derived.
- The premises on the entry state, the image, the heap and the machine record are assumed (section 6).
- Whether all premises together are satisfiable (including the four input premises) is not shown. `refund_entry_and_heap_premises_satisfiable`
  (U390) covers the entry and heap premises only.

`end_to_end` stays false.

## 6. Assumption ledger

| Premise or model choice | Class |
| --- | --- |
| `refund_entry_pre s h stk e` (image in memory at slide 0, control bits, pc, slot values, header separation) | ASSUMED |
| `aligned 3 e`, `h ≤₊ e`, `8192w ≤₊ e − h`; `refund_heap_clear h e` | ASSUMED, explicit |
| `envmc.prog_addresses = refund_mem_dm h e` | ASSUMED (choice of the machine record) |
| `stdin_content fs = SOME text`, `wfcl`, `wfFS`, `STD_streams`; oracle `basis_ffi` | ASSUMED |
| `next_interfer = refund_id_interfer` | MODEL ASSUMPTION; real scheduler and signals OPEN |
| `ffi_interfer = refund_abs_ffi` | MODEL ASSUMPTION; real C functions and stubs OPEN |
| FFI model conformance (real effects equal the oracle's events and bytes) | OPEN; not stated in HOL |
| Loader produces the image; path from process entry to `cml_main` | OPEN |
| Load slide (`MH_PIE` set; every theorem at slide 0) | OPEN |
| ML file reader (U389); L3 ARMv8 model; recorded allocation oracle | as before |

Dependency closure (`import-0001`): 521 theory nodes; axioms only `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`,
`bool.BOOL_CASES_AX`; every stored theorem and definition of `forge_refundEnvModel` (20 theorems, 9 definitions) has tag `DISK_THM`
only and no hypothesis.

## 7. Negative controls

Stored theorems (`env-0005`):

1. Modified protected memory, environment: `protected_write_breaks_interference`: `a ∈ dm ⇒ ¬interference_ok (λi ms. ms with MEM := (a =+ ms.MEM a + 1w) ms.MEM) (arm8_target.proj dm)`.
2. Changed pc, environment: `pc_change_breaks_interference`.
3. Incorrect return address, FFI: `wrong_return_address_ffi_rejected`: `¬ffi_interfer_ok 0x1000040D0w (refund_mc 0x1000040D0w (envmc with ffi_interfer := refund_bad_return_ffi))` (returns to x30 + 4).
4. Modified protected memory, FFI: `protected_memory_write_ffi_rejected`: for `a ∈ envmc.prog_addresses`, the FFI model that also changes byte `a` is rejected.
5. Clobbered callee-saved register, FFI: `clobbered_callee_saved_register_ffi_rejected` (x19 := 1).

Controls 3–5 use `refund_ffi_contract_at_witness` (one explicit state with zero-length arrays) and the equivalence of section 3.
So they refute the published predicate itself, not only the contract.

`import-0001`: all U386–U391 statements, negative controls (seven of U386, six of U389, five of U390, four of U391) and scope controls
pass again; exact code/data identity (`refund_file_code`, `refund_file_bitmaps`) and the `compile_correct'` identity are re-checked.
New scope controls: the three theorems without a residual are stated only for `refund_abs_env`, keep `refund_entry_pre` and
`refund_heap_clear`, and are at slide 0; `refund_abs_ffi` has no oracle and no U392 theorem relates it to executable bytes; the
contract equivalence is for a general `envmc` and proves `ffi_interfer_ok` for no real `ffi_interfer`; the exclusion theorem contains
no behaviour-set statement.

## 8. Outstanding obligations for the FFI contract on the real executable

For each of `read`, `write`, `close`, `open_in`:

1. Stub: ARMv8 steps from the entry address to the C function (`cake_ffiread` … `cake_ffiopen_in` at `0x1000040A0` … `0x100004070`). NOT RUN.
2. C function body (`ffiread`, `ffiwrite`, `fficlose`, `ffiopen_in` in the linked `__TEXT`): a machine-level specification that gives
   the return-pc, memory-write and register-preservation contracts. This includes calls into `libSystem` (`read`, `write`, `close`,
   `open`) through the `__got`, and the kernel. No model exists. NOT RUN.
3. Conformance with the oracle: the bytes written are the `basis_ffi` result bytes and the external effect is the oracle's event. OPEN.
4. Composition of many instructions into one `ffi_interfer` transition (the published semantics treats the call as one step). OPEN.

## 9. Counterexamples and blockers

No counterexample. No logical blocker. Not done: clean replay; independent replay; native execution.

## 10. Next smallest proof step

One entry stub. Take `cake_fficlose` at `0x100004080` (16 bytes): prove with the L3 ARMv8 model, on the exact file bytes
(`refund_image_mem`), what the stub does up to its branch into C (which registers it sets, where it branches, what it leaves
unchanged). This is obligation 1 of section 8 for one name. It needs no C or kernel model and fixes the precise interface
that the C-level specification must then meet. Alternative of the same size: the load-slide version of the 27 start-up steps.

M1 open. Integration EXIT NOT_ESTABLISHED. end_to_end=false.
