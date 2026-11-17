# U395: `clen = 8` and `alen ≠ 0` proved at every reachable `close` call state of the model machine; not yet for the real process

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted. Nothing committed.
Local results: same machine, same agent, cached parents. No clean replay. No independent replay. No native execution.

Run directory: `results/refund-callsite-local-20261116/attempt-0001`.
All U386–U394 theories are imported unchanged. `import-0001` re-checks the published `compile_correct'` identity, the exact code and
data identity and every earlier negative control, including the invalid-argument and vacuity controls of U394.

Scope: the name `close` (index 2) only.

## 1. Commands and actual exits

`python3 -I -B run_case.py <case> <source> <deps…>` through `go.sh`, `go-imp.sh` (CakeML context).
Exact argument vectors: `records/site/<case>/command.json`. Full list: `records/exits.json`.

| Case | Exit | Kind |
| --- | --- | --- |
| `site-0001` | 0 | definitions, reachability lemma, normal-step inclusion; superseded |
| `site-0002`, `site-0003` | 1 | authoring (one type annotation; assembly of the main theorem) |
| `site-0004` | 0 | main call-site theorem checked; superseded |
| `site-0005` | 0 | final theory `forge_refundCallSite`, 221 s |
| `import-0001` | 0 | 133 statements (131 exact, 2 identical to published), structural checks, 526 closure nodes |
| `site-repeat` | 0 | every exported file byte-identical |

Tool failures: none. Memory failures: none. Logical failures: none.

## 2. The code path to the entry stub

From the published definitions (read, not re-proved here): the lab-level instruction `CallFFI name` is compiled as an unconditional
jump (`lab_inst w (CallFFI n) = Jump w`) to the entry address `pc − 16·(3 + index)`. In the published machine semantics
`targetSem$evaluate`, a state whose pc is outside the program addresses, is not the halt or install address, and is found in
`ffi_entry_pcs` at an index with an external-call name is an FFI call state: the semantics reads the two byte arrays through
x0/x1 and x2/x3 (`read_ffi_bytearrays`), calls the oracle (`call_FFI`), and continues with `ffi_interfer`.
For the model record the entry for `close` is `0x100004080` (U391).

Not done: the compiled instruction that performs the jump was not located in the code bytes, and no L3 step theorem covers it.
The result below is semantic (from the machine semantics and the proved behaviour), not an instruction-level trace of the caller.

## 3. Reachability

- `refund_static mc dm`: the record's FFI names, entry addresses, halt and install addresses, empty `mmio_info`, program addresses
  `dm` with `0x100004080w ∉ dm`, target `arm8_target`, and the four argument registers.
- `machine_step mc ffi ms mc' ffi' ms'`: one clock tick of the published evaluation leads from the first configuration to the second
  (`∀k. evaluate mc ffi (k + 1) ms = evaluate mc' ffi' k ms'`), the oracle function is unchanged, and the static record fields are unchanged.
- `machine_reach`: finitely many `machine_step`s.

`machine_reach` is defined on the published evaluation function. It is an over-approximation: it contains every configuration with
the same future evaluation. The real transitions are inside it:

- `normal_step_is_machine_step`: an ordinary instruction step of `evaluate` is a `machine_step`.
- `extcall_step_is_machine_step`: a successful external-call step of `evaluate` is a `machine_step`.
- Not shown as steps: the install transition and shared-memory transitions. The model record has no shared-memory name, and the U298
  exclusion theorem says that its install address is not reached under the same premises.

`machine_reach_n_evaluate`: a reachable configuration `(mc1, ffi1, ms1)` after `n` steps has
`∀k. evaluate mc ffi (k + n) ms = evaluate mc1 ffi1 k ms1`, the same oracle function and the same static fields.

## 4. Strongest theorem

**`close_call_site_arguments`:**

```
machine_reach mc ffi ms mc1 ffi1 ms1 ∧ refund_static mc dm ∧ ffi.oracle = basis_ffi_oracle ext ∧
machine_sem mc ffi ms ⊆ extend_with_resource_limit {Terminate Success io} ∧ ms1.PC = 0x100004080w ⇒
ms1.REG 1w = 8w ∧ ms1.REG 3w ≠ 0w ∧
∃cbytes abytes. read_ffi_bytearrays mc1 ms1 = (SOME cbytes, SOME abytes) ∧ LENGTH cbytes = 8 ∧ 1 ≤ LENGTH abytes
```

It holds for every reachable call state, not for one witness.

Why it is not circular. No premise says that an oracle call succeeds. The proof is by contradiction with the behaviour inclusion:

1. If the argument arrays are not readable, one evaluation step gives `Error` (`close_call_unreadable_errors`), so `Fail ∈ machine_sem`.
   `fail_not_in_success_limit` excludes it.
2. If the oracle call ends the run, one step gives `Halt (FFI_outcome …)` (`close_call_final_halts`), so that outcome is in
   `machine_sem`. `ffi_outcome_not_in_success_limit` excludes it.
3. So the oracle returned. For `basis_ffi_oracle` and the name `close` that needs an 8-byte configuration and a non-empty array
   (`close_call_return_lengths`, from U394 `ffi_close_accepts_only_valid_lengths`).
4. The array lengths are `w2n` of x1 and x3 (`close_call_read_lengths`).

The behaviour inclusion is itself a proved theorem for the model record (U392 `refund_behavior_abstract_env`). It rests on the
published `compile_correct'`, the source specification and the source non-Fail theorem. So the argument validity comes from the proved
calling code (through compiler correctness), not from an assumption about the oracle.

**Instance at the model record, `close_call_site_arguments_model`:** under the premises of `refund_behavior_abstract_env`
(entry pre-state, conditions on `e`, `refund_heap_clear`, the program-address equation, the four input premises):

```
∃ms. arm8_run 27 s = SOME ms ∧ ms.PC = 0x1000040D0w ∧
     ∀mc1 ffi1 ms1. machine_reach (refund_mc 0x1000040D0w (refund_abs_env envmc)) (basis_ffi ext cl fs) ms mc1 ffi1 ms1 ∧
                    ms1.PC = 0x100004080w ⇒ ms1.REG 1w = 8w ∧ ms1.REG 3w ≠ 0w
```

`refund_abs_record_static` proves `refund_static` for that record.

## 5. Composition with `cake_fficlose_path` and premises removed

`fficlose_call_pre_no_len`: the 16 conjuncts of `fficlose_call_pre` without `s.REG 1w = 8w` and `s.REG 3w ≠ 0w` (14 kept).

**`cake_fficlose_path_at_reachable_call`:** under the same premises, for the state `ms` after the 27 start-up steps, every reachable
configuration `(mc1, ffi1, ms1)` of the model record with `fficlose_call_pre_no_len dm ms1 b c g` satisfies the conclusion of
`cake_fficlose_path`: 15 steps reach the branch into `libSystem`; for every `s2` with `close_call_rel dm s1 s2`, 6 steps return to
`ms1.REG 30w` with the stack pointer and x19–x28 restored and the domain unchanged except the result byte.

| Premise of the U394 composition | After U395 |
| --- | --- |
| `s.REG 1w = 8w` (`clen = 8`) | REMOVED for reachable call states of the model record |
| `s.REG 3w ≠ 0w` (`alen ≠ 0`) | REMOVED for reachable call states of the model record |
| `¬word_msb (s.REG 3w)` (`alen` not negative as a signed value) | KEPT. The model reads `w2n x3` bytes; a value of 2^63 or more is not excluded without a size bound on the domain |
| `arm8_user s`, image in memory, stack pointer and alignment, aligned `c`, the separations, `__got` content | KEPT |
| `close_call_rel` | KEPT, explicit, unproved |

## 6. Limits (the missing connection to the real process)

1. Model machine only. The reachable states are states of `refund_mc 0x1000040D0w (refund_abs_env envmc)`: identity environment and
   the abstract FFI transition of U392. In that model an FFI call is one transition; it does not execute the stub or `fficlose`.
   The path theorem describes the real instructions from the same state. That a real execution passes through the model's call
   states is the open simulation obligation (`ffi_interfer_ok` and `interference_ok` for the real system).
2. It is not shown that any `close` call state is reachable. The theorem is a statement about all of them; for the refund program
   the set may be empty. The name is in the FFI list because the basis library is linked.
3. `machine_reach` over-approximates; the theorem holds for the larger set. Install and shared-memory transitions are not shown as steps.
4. The premises of `refund_behavior_abstract_env` stay assumed (image at slide 0, entry state, heap premise, input premises).
5. The sign condition on `alen` and every C-stack premise stay explicit.
6. `libSystem`, dynamic binding, oracle conformance, the loader and the PIE slide stay open. `end_to_end` stays false.

## 7. Negative controls

Stored theorems (`site-0005`):

1. `ffi_close_rejects_invalid_lengths`: `LENGTH cfg8 ≠ 8 ∨ arr = [] ⇒ ffi_close cfg8 arr fsys = NONE`.
2. `invalid_clen_call_halts_in_model`: at a call state with readable arrays and a configuration length other than 8, one step of the
   model halts with an FFI outcome. Invalid arguments are a represented outcome of the model, not an ignored case.
3. `fail_not_in_success_limit`, `ffi_outcome_not_in_success_limit`: the two exclusions used by the proof.
4. `resource_limit_is_in_success_limit`: a resource-limit termination is inside the behaviour set, so the inclusion premise is not
   stronger than stated.
5. `machine_reach_refl`: the start configuration is reachable (the quantification is not empty by definition).

Kept from U394 and re-checked: `invalid_arguments_not_covered`, `invalid_clen_reaches_assert_block`, `zero_alen_reaches_assert_block`,
`overlapping_configuration_is_vacuous_case`, the inhabitation theorems, `corrupted_return_state_not_in_relation`,
`frame_in_protected_domain_not_covered`. `fficlose_call_pre_no_len_weaker` shows the reduced premise is implied by the full one,
so the U394 witness also satisfies it.

`import-0001` scope controls: the call-site theorem assumes reachability and the behaviour inclusion and no oracle success; the two
theorems that conclude `x1 = 8` are stated for reachable states only; no U395 theorem states `ffi_interfer_ok` or
`refund_ffi_contract`; every U395 theorem is at slide 0; the composed theorem keeps `close_call_rel` as a premise.

## 8. Assumptions and dependency closure

| Assumption | Class |
| --- | --- |
| Premises of `refund_behavior_abstract_env` (entry pre-state at slide 0, conditions on `e`, `refund_heap_clear`, program-address equation, input premises, oracle `basis_ffi`) | ASSUMED |
| Model record: identity `next_interfer`, `refund_abs_ffi` | MODEL ASSUMPTION |
| `fficlose_call_pre_no_len` at the call state (14 conjuncts) | ASSUMED |
| `close_call_rel` | ASSUMED, unproved |
| Published `compile_correct'`, source specification, source non-Fail theorem | proved earlier; inside the behaviour inclusion |

Dependency closure (`import-0001`): 526 theory nodes; axioms only `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`,
`bool.BOOL_CASES_AX`; every stored theorem and definition of `forge_refundCallSite` (21 theorems, 6 definitions) has tag `DISK_THM`
only and no hypothesis.

## 9. Verdict against the success criterion

A machine-checked theorem establishes `x1 = 8` and `x3 ≠ 0` for every reachable `close` call state of the model machine, without
assuming oracle success. The missing connection, stated precisely: (a) a simulation between the real process and the model machine
at call states; (b) the sign of `alen`; (c) existence of a reachable `close` call is not shown.

## 10. Counterexamples and blockers

No counterexample. No logical blocker.

## 11. Next smallest proof step

Remove the sign premise for the model: prove `w2n (ms1.REG 3w) < 2^63` at a reachable call state from a size bound on the
program-address set (a readable array of `n` bytes needs `n` distinct addresses in the domain), with one explicit premise that the
heap range is shorter than 2^63 bytes. Then `alen ≥ 1` holds as a signed statement and only stack, image and `close_call_rel`
premises remain for `close`.

M1 open. Integration EXIT NOT_ESTABLISHED. end_to_end=false.
