# U394: the complete `cake_fficlose` path as one conditional machine-level theorem, with the external `close` call as an explicit assumed relation

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted. Nothing committed.
Local results: same machine, same agent, cached parents. No clean replay. No independent replay. No native execution.

Run directory: `results/refund-fficlose-compose-local-20261116/attempt-0001`.
All U386–U393 theories are imported unchanged. `import-0001` re-checks the published `compile_correct'` identity, the exact code and
data identity, the U393 statements and every earlier negative control.

Scope: the name `close` only. Nothing here is a claim about `read`, `write` or `open_in`.
Not modelled and not proved: `libSystem` `close`, the kernel, dynamic binding of the `__got`, oracle conformance, the loader, the PIE slide.

## 1. Commands and actual exits

ARMv8 context: `python3 -I -B run_arm8_case.py <case> <source> (<theory-case> <theory>)…`.
CakeML context: `python3 -I -B run_case.py <case> <source> <deps…>` through `go.sh`, `go-imp.sh`.
Exact argument vectors: `records/compose/<case>/command.json`. Full list: `records/exits.json`.

| Case | Exit | Kind |
| --- | --- | --- |
| `assert-0001` | 0 | two assertion paths, ARMv8 context |
| `compose-0001`–`0013` | 1 each | authoring (proof structure of the third part and of the contract instance) |
| `compose-0014` | 0 | composed theorem and contract instance checked; superseded |
| `compose-0015`–`0017` | 1 each | authoring (conjunction nesting; two variable names that are stored constants) |
| `compose-0018` | 0 | final theory `forge_refundFficloseCompose`, 146 s |
| `import-0001` | 0 | 122 statements (120 exact, 2 identical to published), structural checks, 525 closure nodes |
| `assert-repeat`, `compose-repeat` | 0 each | every exported file byte-identical |

Tool failures: none. Memory failures: none. Logical failures: none. Sixteen authoring failures; no failed proof was replaced by an assumption.

## 2. Definitions

`close_call_rel dm s1 s2` (the ASSUMED relation across the external call; `s1` is the state at the branch into `libSystem`, `s2` the state when control is back):

1. `arm8_user s2` (user mode, the four control bits, no exception);
2. `s2.PC = s1.REG 30w` (return to the link address);
3. `s2.SP_EL0 = s1.SP_EL0`;
4. registers 19–28 unchanged;
5. the 32 bytes at `s1.SP_EL0` unchanged (the caller's frame);
6. every byte in `[0x100000000, 0x100030F30)` unchanged (the image range);
7. every byte in the protected domain `dm` unchanged.

The result register x0 is unconstrained. Nothing is said about external effects.

`fficlose_call_pre dm s b c g`: the entry premises of U393 (`arm8_user s`, `s.PC = 0x100004080w`, `refund_image_mem 0w s.MEM`,
`s.SP_EL0 = b + 32w`, `aligned 3 b`, `s.REG 0w = c`, `aligned 2 c`, `s.REG 1w = 8w`, `¬word_msb (s.REG 3w)`, `s.REG 3w ≠ 0w`,
`mem_dword s.MEM 0x100028020w = g`, frame outside the image range, frame outside the 8 configuration bytes) and three new ones:
the frame is outside `dm`; the result address `s.REG 2w` is outside the frame; `s.REG 2w` is outside the image range.

`fficlose_path dm s s3 ⇔ ∃s1 s2. arm8_run 15 s = SOME s1 ∧ close_call_rel dm s1 s2 ∧ arm8_run 6 s2 = SOME s3`.
`close_result_byte x0 = if w2w x0 = 0w then 0w else 1w` (32-bit test of the result register).

## 3. Strongest theorem

**`cake_fficlose_path`:**

```
fficlose_call_pre dm s b c g ⇒
∃s1. arm8_run 15 s = SOME s1 ∧ s1.PC = g ∧ s1.REG 30w = 0x10002528Cw ∧
     ∀s2. close_call_rel dm s1 s2 ⇒
          ∃s3. arm8_run 6 s2 = SOME s3 ∧ s3.PC = s.REG 30w ∧ s3.SP_EL0 = s.SP_EL0 ∧ arm8_user s3 ∧
               (∀r. MEM r [19w; …; 28w] ⇒ s3.REG r = s.REG r) ∧
               ∀q. q ∈ dm ⇒ s3.MEM q = if q = s.REG 2w then close_result_byte (s2.REG 0w) else s.MEM q
```

It composes: the entry stub (1 step), the `fficlose` prefix (14 steps), the assumed relation, the `fficlose` suffix (6 steps).
Parts: `cake_fficlose_reaches_call`, `close_call_rel_gives_return_state`, `fficlose_after_call`.

Reading: from a valid call state, the 15 proved steps reach the branch into `libSystem`. For every state that the assumed relation
permits after the call, the 6 proved steps return to the caller's link address with the stack pointer restored, registers 19–28
restored, and the protected domain unchanged except one byte at the result address, set to 0 or 1.

## 4. Relation to `refund_ffi_contract` for `close`

**`cake_fficlose_path_contract_instance`:**

```
t1.mem_domain = dm ∧
read_bytearray (s.REG 2w) (w2n (s.REG 3w)) (λa. if a ∈ dm then SOME (s.MEM a) else NONE) = SOME bytes2 ∧
target_state_rel arm8_target (t1 with pc := 0x1000040D0w − n2w ((3 + 2) * 16)) s ∧ aligned 2 (t1.regs 30) ∧
fficlose_call_pre dm s b c g ∧ fficlose_path dm s s3 ⇒
∃v. (v = 0w ∨ v = 1w) ∧ arm8_ok s3 ∧ s3.PC = t1.regs 30 ∧
    (∀a. a ∈ dm ⇒ s3.MEM a = asm_write_bytearray (t1.regs 2) (v :: TL bytes2) t1.mem a) ∧
    (∀r. MEM r [19; 20; 21; 22; 23; 24; 25; 27; 28] ⇒ s3.REG (n2w r) = t1.regs r)
```

The conclusion is the conclusion of the contract at index 2 with `new_bytes = v :: TL bytes2`.
It is not a proof of `refund_ffi_contract`, for four reasons:

1. The path is a relation with an assumed call, not a function `ffi_interfer`.
2. The contract quantifies over every `new_bytes` of the right length. The real code writes one byte. The theorem covers only the
   shape `v :: TL bytes2`.
3. The contract quantifies over every call state. The theorem needs `fficlose_call_pre` (valid lengths, stack and separation premises).
4. Only index 2 (`close`). `import-0001` checks that no U394 theorem states `ffi_interfer_ok` or `refund_ffi_contract`.

Oracle side (model fact, `ffi_close_accepts_only_valid_lengths`): `ffi_close cfg8 arr fsys = SOME (FFIreturn nb fsys') ⇒ LENGTH cfg8 = 8 ∧ 1 ≤ LENGTH arr ∧ ∃v. (v = 0w ∨ v = 1w) ∧ nb = v :: TL arr`.
So the oracle's accepted calls and its result shape agree with what the machine path needs and produces. That the two values `v`
agree (the real `close` succeeds exactly when the file-system model closes the descriptor) is oracle conformance: OPEN.

## 5. The `clen = 8` and `alen ≥ 1` requirements

- Not proved at the call site. No theorem derives `s.REG 1w = 8w` or a positive `s.REG 3w` for the state in which the compiled
  code jumps to the stub. They are explicit conjuncts of `fficlose_call_pre`.
- Other outcomes are represented by step theorems, not assumed away:
  - `zero_alen_reaches_assert_block`: with `s.REG 3w = 0w`, 6 steps from the entry address reach `0x1000252A4`.
  - `invalid_clen_reaches_assert_block`: with a positive `alen` and `s.REG 1w ≠ 8w`, 8 steps reach `0x1000252A8`.
  - Both addresses are calls into the assertion blocks (`__assert_rtn`). What happens there is not modelled. A negative `alen`
    (`word_msb`) is NOT RUN as a step theorem.
- `invalid_arguments_not_covered`: with `clen ≠ 8`, `alen = 0` or a negative `alen`, `fficlose_call_pre` is false. The composed theorem
  claims nothing there.
- Evidence toward the call site, model level only: the oracle fact of section 4. In the machine semantics an FFI step whose oracle call
  fails ends the run with an FFI outcome, and the behaviour theorems exclude that outcome. A proof that this gives the two register
  facts at the call state is NOT RUN.

## 6. Conditions for the external call to return to the suffix

Sufficient (proved, `close_call_rel_gives_return_state`): conjuncts 1, 2, 3, 5, 6 of `close_call_rel` and x19 unchanged give the
pre-state of the suffix. Conjunct 4 for x20–x28 and conjunct 7 are needed for the register and memory conclusions, not for the return.
`corrupted_return_state_not_in_relation`: a state with a different pc, a different stack pointer, a different x19 or a changed frame
byte is not in the relation. U393 `fficlose_suffix_wrong_return_refuted` and `fficlose_corrupted_frame_slot_clobbers_x19` show what
such states do. Necessity of each conjunct for the conclusion is not proved in general.

Stack-frame separation: explicit premises (frame outside `dm`, outside the image range, outside the configuration bytes; result
address outside the frame). They are not derived from anything. `prefix_writes_the_frame` shows the frame really is written, and
`frame_in_protected_domain_not_covered` shows that an overlapping frame is outside the theorem.

## 7. Non-vacuity

- `fficlose_call_pre_satisfiable`: `∃dm s b c g. fficlose_call_pre dm s b c g`. Constructed witness: the U389 image memory, frame base
  `0x400000000`, configuration pointer `0x200000200`, result address `0x200000100`, `dm = {0x200000100w}`, `clen = 8`, `alen = 1`.
  All 16 conjuncts are proved one by one (`WITNESS_CONJUNCTS 16`).
- `close_call_rel_inhabited`: for every `s1` in user state, `s1 with PC := s1.REG 30w` is in the relation.
- `cake_fficlose_path_inhabited`: `∃dm s b c g s3. fficlose_call_pre dm s b c g ∧ fficlose_path dm s s3`. So the composed theorem has
  a complete instance: 15 steps, a permitted call transition, 6 steps.
- `import-0001` checks that the premise of `cake_fficlose_path` is exactly the predicate shown inhabited.
- `overlapping_configuration_is_vacuous_case`: `¬fficlose_call_pre dm s b b g`. An instance with the configuration at the frame base
  has a false premise; the check distinguishes it from the inhabited case.
- The step scripts keep the U393 guards (fresh frame variable; a contradictory frame hypothesis fails the run).

The witnesses are constructed states. They are not evidence about a loader, `libSystem` or a real process.

## 8. Negative controls

| Control | Stored theorem |
| --- | --- |
| Invalid arguments | `invalid_arguments_not_covered`; `invalid_clen_reaches_assert_block`; `zero_alen_reaches_assert_block`; ARMv8-context `fficlose_clen_bad_reaches_assert`, `fficlose_alen_zero_reaches_assert` |
| Corrupted return state | `corrupted_return_state_not_in_relation`; U393 suffix controls re-checked |
| Memory overlap | `frame_in_protected_domain_not_covered`; `prefix_writes_the_frame` |
| Vacuous proof | `overlapping_configuration_is_vacuous_case`; the three inhabitation theorems; the premise-identity check in `import-0001` |

`import-0001`: all U386–U393 statements, negative controls and scope controls pass again. New scope controls: `close_call_rel` occurs
only as a premise, in a refutation and in the constructed-inhabitant lemma; no theorem derives it from an implementation; no U394
theorem states `ffi_interfer_ok` or `refund_ffi_contract`; none relates `ffi_close` to machine steps; every U394 theorem is at slide 0.

## 9. Assumptions and dependency closure

| Assumption | Class |
| --- | --- |
| `close_call_rel dm s1 s2` for the real call (AAPCS64 return, callee-saved registers, no write to the caller's frame, the image range or the domain; valid user state) | ASSUMED; `libSystem` and the kernel are not modelled |
| `refund_image_mem 0w s.MEM` (loader; slide 0) | ASSUMED |
| `arm8_user s`, `s.PC = 0x100004080w` (the compiled code reaches the stub in such a state) | ASSUMED; not composed with `machine_sem` |
| `clen = 8`, positive `alen`; aligned `c`; `s.SP_EL0 = b + 32w`, `aligned 3 b` | ASSUMED (call site and C stack) |
| Frame separations; result address outside the frame and the image range | ASSUMED |
| Content of the `__got` slot (`g`): a parameter. The theorem holds for every `g`; that `g` is `close` is dynamic binding | OPEN |
| Oracle conformance; the other three FFI names; PIE slide; input and environment assumptions of U388–U392 | OPEN |
| ML file reader (U389); L3 ARMv8 model and step library | as before |

Dependency closure (`import-0001`): 525 theory nodes; axioms only `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`,
`bool.BOOL_CASES_AX`; every stored theorem and definition of the two new theories has tag `DISK_THM` only and no hypothesis.
`forge_refundFficloseAssert`: 2 theorems, 2 definitions. `forge_refundFficloseCompose`: 22 theorems, 5 definitions.

## 10. Verdict against the success criterion

A non-vacuous conditional theorem for the full `cake_fficlose` path exists (`cake_fficlose_path`, inhabited by
`cake_fficlose_path_inhabited`). Every external implementation assumption is a named premise: `close_call_rel` and the conjuncts of
`fficlose_call_pre`. Local result with cached parents; not independently replayed. No correctness claim for the real FFI.

## 11. Counterexamples and blockers

No counterexample. No logical blocker.

## 12. Next smallest proof step

The call-site link in the model: in the published machine semantics, an FFI step at index 2 whose oracle call succeeds has
`LENGTH bytes = 8` and `1 ≤ LENGTH bytes2`, where the lengths are `w2n` of x1 and x3 at the call state. Prove that from
`read_ffi_bytearrays` and `ffi_close_accepts_only_valid_lengths`. It removes `clen = 8` and `alen ≥ 1` as free premises relative to
the oracle. Remaining after that for `close`: the sign condition on `alen`, the C stack premises, `close_call_rel` itself, oracle conformance.

M1 open. Integration EXIT NOT_ESTABLISHED. end_to_end=false.
