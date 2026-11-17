# U393: exact ARMv8 steps of the entry stub `cake_fficlose`, of `fficlose` up to the indirect branch into `libSystem`, and after an assumed return; the stub alone meets no part of the FFI contract

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted. Nothing committed.
Local results: same machine, same agent, cached parents. No clean replay. No independent replay. No native execution.

Run directory: `results/refund-fficlose-step-local-20261116/attempt-0001`.
All U386–U392 theories are imported unchanged. `import-0001` re-checks the published `compile_correct'` identity, the exact code and
data identity (`refund_file_code`, `refund_file_bitmaps`) and every earlier negative control.

Three things are kept separate in this report:

1. Abstract FFI correctness (U392): a model function satisfies `refund_ffi_contract`. Unchanged.
2. Exact stub and C-function steps (this entry): L3 ARMv8 steps on the exact file bytes.
3. External-effect correctness of the `libSystem` call and the kernel: NOT modelled, NOT proved.

## 1. Commands and actual exits

ARMv8 context: `python3 -I -B run_arm8_case.py <case> <source> <theory-case> forge_refundCmlMainStep`.
CakeML context: `python3 -I -B run_case.py <case> <source> <deps…>` through `go.sh`, `go-imp.sh`.
Exact argument vectors: `records/ffic/<case>/command.json`. Full list: `records/exits.json`.

| Case | Exit | Kind |
| --- | --- | --- |
| `steps-0001` | 0 | exploration: the step library has a theorem for each of the 24 distinct words |
| `ffic-0001`, `ffic-0002` | 1 | authoring (ML types) |
| `ffic-0003` | 1 | authoring: the 32-bit load step needs an alignment hypothesis (section 4) |
| `ffic-0004` | 1 | authoring (ML typing) |
| `ffic-0005` | 0 | DEFECTIVE, not used: one conjunct of the suffix theorem was vacuous (variable name clash in my script) |
| `ffic-0006` | 0 | final ARMv8 theory `forge_refundFficloseStep`, 12 s |
| `bridge-0001` | 0 | final CakeML-context theory `forge_refundFficloseBridge`, 198 s |
| `import-0001` | 0 | 106 statements (104 exact, 2 identical to published), 3 structural checks, 523 closure nodes |
| `ffic-repeat`, `bridge-repeat` | 0 each | every exported file byte-identical |

Tool failures: none. Memory failures: none. Logical failures: none.
`ffic-0006` adds a freshness check and a contradiction check so that the `ffic-0005` defect fails closed.

## 2. Exact instruction words and file correspondence

Artifact: the Mach-O executable of U389 (SHA256 `b8ed5ec2…39007bb8`), never executed.

| Place | Address | File offset | Words |
| --- | --- | --- | --- |
| Entry stub `cake_fficlose` | `0x100004080` | 16512 | `14008478` (`b 0x100025260`), then three `nop` words (not executed) |
| C function `fficlose`, main path | `0x100025260`–`0x1000252A0` | 152160 | 17 words (prologue, two argument checks, load, byte reverse, `bl`, result byte, epilogue, `ret`) |
| Import stub for `close` | `0x1000258EC`–`0x1000258F4` | 153836 | `f0000010`, `f9401210`, `d61f0200` (`adrp`; `ldr x16,[x16,#0x20]`; `br x16`) |

`refund_file_fficlose_words` (kernel evaluation on `refund_file`): `TAKE 4 (DROP 16512 refund_file)`, `TAKE 68 (DROP 152160 refund_file)` and
`TAKE 12 (DROP 153836 refund_file)` are exactly these 84 bytes.
`refund_image_fficlose_code`: `refund_image_mem 0w m ⇒ fficlose_code_bytes m` (the 84 byte equations of the step proofs).
So the step theorems are about the bytes of the file, through the image predicate. The image predicate itself is ASSUMED of a memory.

## 3. The stub (exact)

**`cake_fficlose_stub_exact`:**

```
arm8_user s ∧ s.PC = 0x100004080w ∧ refund_image_mem 0w s.MEM ⇒
∃s1. arm8_run 1 s = SOME s1 ∧ s1.PC = 0x100025260w ∧ s1.REG = s.REG ∧ s1.MEM = s.MEM ∧ s1.SP_EL0 = s.SP_EL0 ∧
     s1.PSTATE = s.PSTATE ∧ s1.SCTLR_EL1 = s.SCTLR_EL1 ∧ s1.TCR_EL1 = s.TCR_EL1 ∧ s1.exception = s.exception
```

`arm8_user s`: user mode, the four control bits, no exception. The stub is one unconditional branch. It changes the pc only.
It does not touch a register, the stack pointer, the flags or memory. It does not return.

## 4. `fficlose` up to the point where execution leaves the image

`fficlose_prefix_run` (ARMv8 context, 14 steps from `0x100025260`) and **`cake_fficlose_to_import_branch`** (15 steps from the entry
address, on the image):

- Premises on the entry state: `s.SP_EL0 = b + 32w`, `aligned 3 b`, `s.REG 0w = c`, `aligned 2 c`, `s.REG 1w = 8w`, `¬word_msb (s.REG 3w)`,
  `s.REG 3w ≠ 0w`, `mem_dword s.MEM 0x100028020w = g`, the 32 frame bytes at `b` do not meet `[0x100000000, 0x100030F30)`, and do not meet
  the 8 bytes at `c`.
- Conclusion: `arm8_run 15 s = SOME s1`, `s1.PC = g`, `s1.REG 30w = 0x10002528Cw`, `s1.REG 19w = s.REG 2w`, `s1.REG 29w = b + 16w`,
  `s1.REG 16w = g`, `s1.SP_EL0 = b`, `s1.REG 0w` = the byte-reversed 32-bit word at `c + 4` (the file descriptor), user mode and control
  state unchanged, the four frame slots hold the old x20, x19, x29, x30, memory is unchanged outside the 32 frame bytes, and every register
  except 0, 8, 16, 19, 29, 30 is unchanged.

**Exit point.** Execution leaves the verified instructions at step 15: `br x16` at `0x1000258F4`. The target `g` is the content of the
`__got` slot at `0x100028020`. The dynamic loader binds that slot to `close` in `libSystem`; in the file the slot holds fixup data, not an
address. Nothing after this branch is modelled: `libSystem`, the kernel, the return. The proved link register value says where a return
is expected (`0x10002528C`).

"C run-time" boundary: the stub enters compiled C code at `0x100025260`. That code is inside the executable's `__TEXT`, so its bytes
are covered by the file constant and its main-path instructions are proved step by step. The assertion paths (`b.le`, `b.ne` to the
`cold` blocks and `__assert_rtn`) are not stepped.

Model note: `aligned 2 c` and `aligned 3 b` are hypotheses of the L3 step theorems for the 32-bit load and the stack pairs. They are
explicit premises. `x1 = 8` and `0 < x3` are the two C assertions (`clen == 8`, `alen >= 1`).

## 5. `fficlose` after the call (from an ASSUMED state)

`fficlose_suffix_run` (6 steps from `0x10002528C`): premise `fficlose_return_pre s b a v20 v19 v29 v30` (user mode, pc `0x10002528C`,
`s.SP_EL0 = b`, `aligned 3 b`, `s.REG 19w = a`, the four frame slots hold `v20`, `v19`, `v29`, `v30`, and `a` is outside the image
range and outside the frame). Conclusion: `s1.PC = v30`, x30 = `v30`, x29 = `v29`, x19 = `v19`, x20 = `v20`, `s1.SP_EL0 = b + 32w`,
the byte at `a` is 0 if the low 32 bits of x0 are 0 and 1 otherwise, memory is unchanged except at `a`, registers other than
8, 19, 20, 29, 30 are unchanged, control state unchanged.

This pre-state is an assumption about the state after `close` returns. No theorem joins section 4 to section 5 (`import-0001` checks it).

## 6. Which parts of `refund_ffi_contract` are established

| Contract part | Stub (1 step, proved) | `fficlose` instructions (20 steps, proved) | Still an obligation |
| --- | --- | --- | --- |
| Return pc = x30 | not established: the stub branches to `0x100025260` (`cake_fficlose_stub_does_not_return`) | x30 is saved in slot `b + 24`; the epilogue returns to the content of that slot | `close` and the kernel return to `0x10002528C` with sp and the frame slot unchanged |
| Result state valid (`arm8_ok`) | control state unchanged | control state unchanged in all steps | unchanged across the call; x30 aligned (contract premise) |
| Protected memory = result bytes at x2 only | no write | writes exactly the 32 frame bytes below sp, then one byte at old x2 (0 or 1) | the C stack frame is outside the protected domain (not a premise yet); the callee writes nothing in the domain; the byte equals the oracle's first result byte and the rest of the result equals the old array tail |
| Registers 19–25, 27, 28 kept | all registers kept | x19 is overwritten with x2 and restored from slot `b + 8`; x20 restored; 21–28 not touched by these instructions | the callee keeps x19–x28 and the frame slots (`fficlose_corrupted_frame_slot_clobbers_x19` shows the dependency) |
| Holds for every call state | — | proved only for `clen = 8`, `alen ≥ 1`, aligned `c` | see the finding below |

`stub_only_ffi_rejected`: the FFI model "do what the stub does" (`refund_stub_only_ffi`: set the pc to `0x100025260`) does not satisfy
`ffi_interfer_ok` at the record. Exact stub correctness is therefore not contract satisfaction.

Finding (analysis of the disassembly, NOT a theorem): the published clause quantifies over every call state with readable argument
arrays. The real function returns only when `clen = 8` and `alen ≥ 1`; otherwise it branches to an assertion block. So a faithful model
of the real `fficlose` cannot satisfy the clause for all call states. A proof for the real code needs call-site facts about the
compiled program (it calls `close` with an 8-byte configuration) or a model that is total by construction. Not resolved here.

## 7. Negative controls

Stored theorems:

1. Altered instruction word: `altered_stub_word_not_in_file` (`TAKE 4 (DROP 16512 refund_file) ≠ [121w; 132w; 0w; 20w]`);
   `altered_stub_byte_rejected` (`m 0x100004080w ≠ 120w ⇒ ¬refund_image_mem 0w m`).
   In the step scripts, a changed stub word (`14008479`) and a changed store word (`39000269`) are rejected by the fetch hypotheses.
2. Invalid return address: `cake_fficlose_stub_wrong_target_refuted`; `cake_fficlose_stub_does_not_return`;
   `fficlose_suffix_wrong_return_refuted` (the epilogue reaches no pc other than the saved value); U392 `wrong_return_address_ffi_rejected` re-checked.
3. Protected-memory corruption: the frame conjuncts of sections 4 and 5 bound every write; U392 `protected_memory_write_ffi_rejected`
   and `protected_write_breaks_interference` re-checked.
4. Register clobbering: `fficlose_corrupted_frame_slot_clobbers_x19`; U392 `clobbered_callee_saved_register_ffi_rejected` re-checked.
5. Stub versus contract: `stub_only_ffi_rejected`.

`import-0001`: all earlier statements, negative controls and scope controls pass again. New scope controls: no U393 theorem states
`ffi_interfer_ok` or the contract for the real stub or C function (the only mention is a refutation); no U393 theorem mentions the
oracle or `machine_sem`; no theorem joins the steps before the call to the steps after it; every U393 theorem is at slide 0.

## 8. Assumptions and dependency closure

| Premise | Class |
| --- | --- |
| `refund_image_mem 0w s.MEM` at the entry state (loader; no write to `__TEXT`; slide 0) | ASSUMED |
| `arm8_user s`, `s.PC = 0x100004080w` | ASSUMED (reached only if the compiled code jumps there; not composed with `machine_sem`) |
| Entry conditions of section 4 (stack pointer, alignment, `clen = 8`, `alen ≥ 1`, separations, content of the `__got` slot) | ASSUMED |
| Post-call state of section 5 | ASSUMED; the call is not modelled |
| ML file reader (U389); L3 ARMv8 model and its step library | as before |

Open and unchanged: PIE slide (`MH_PIE` set; every address here is a link address); real loader behaviour; dynamic binding of the
`__got`; the input and environment assumptions of U388–U392; the identity environment and the abstract FFI model of U392 are models.

Dependency closure (`import-0001`): 523 theory nodes; axioms only `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`,
`bool.BOOL_CASES_AX`; every stored theorem and definition of the two new theories has tag `DISK_THM` only and no hypothesis.
`forge_refundFficloseStep`: 7 theorems, 5 definitions. `forge_refundFficloseBridge`: 9 theorems, 1 definition.

## 9. Remaining FFI obligations for `close`

1. The call: a specification of `libSystem` `close` and the kernel at machine level (return address, sp, callee-saved registers,
   no write to the protected domain or the frame, result in w0). No implementation evidence is available here. OPEN.
2. Composition: stub + prefix + call + suffix as one transition, and its comparison with `refund_ffi_contract` for index 2. OPEN.
3. The C stack frame is outside the protected domain. Needs an explicit premise. OPEN.
4. Call-site facts (`clen = 8`, `alen ≥ 1`, aligned pointers) or a total model; the assertion paths. OPEN.
5. Conformance with the `basis_ffi` oracle (result byte and external effect). OPEN; not stated in HOL.
6. The other three names (`read`, `write`, `open_in`): their stubs have the same one-word form by inspection; NOT RUN.

## 10. Counterexamples and blockers

No counterexample to a stored theorem. `stub_only_ffi_rejected` is a refutation of "the stub alone meets the contract".
No logical blocker. Not done: clean replay; independent replay; native execution.

## 11. Next smallest proof step

State the call as one explicit assumption and compose. Define a relation `close_call_assumed s1 s2` (return to `s1.REG 30w`, same sp,
x19–x28 kept, frame and protected domain unchanged, control state valid) and prove: stub + prefix + assumed call + suffix give the
return-pc, register and memory parts of the contract for `clen = 8`, `alen ≥ 1`, with the C stack outside the domain.
The result is conditional and names the exact `libSystem` obligation. Same size alternative: the two assertion paths
(`clen ≠ 8`, `alen ≤ 0`) as step theorems, to turn the finding of section 6 into a theorem.

M1 open. Integration EXIT NOT_ESTABLISHED. end_to_end=false.
