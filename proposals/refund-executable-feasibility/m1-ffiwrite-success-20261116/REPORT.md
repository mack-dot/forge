# M1 — the successful `cake_ffiwrite` execution path (U398)

Date: 2026-11-16. Local runs, same machine, same agent, cached parent
theories. No clean replay. No independent replay. No native execution.
CURRENT none. M1 open. Stage 12 unauthorized. No profile approved.
`end_to_end=false`. Nothing committed. Continues U397.

Run directory: `results/refund-ffiwrite-success-local-20261116/attempt-0001`.

## 1. Verdict

The successful-write path is now composed. Strongest new theorem:
`cake_ffiwrite_path_returns`. It covers both outcomes of the external call
in one statement. It is conditional on `ffiwrite_call_pre`, on the assumed
relation `write_call_rel`, and on one new explicit premise on the return
state: `¬s2.SCTLR_EL1.A`. It is non-vacuous
(`cake_ffiwrite_success_path_inhabited`, a constructed state with
`a + 1` odd). No reachable `write` call state is proved. The real `write`
and the output effect remain unverified.

## 2. The store at `a + 1`

- Word `78001269` at 0x10002523C: `sturh w9, [x19, #1]`.
- Decoded (L3): `LoadStoreImmediate@16 (1w, T, MemOp_STORE, AccType_NORMAL,
  F, F, F, F, F, F, 1w, 19w, 9w)`. No write-back.
- Address: `x19 + 1` = `a + 1`. Width: 2 bytes.
- Memory change: `a + 1 ↦ (7 >< 0) w9`, `a + 2 ↦ (15 >< 8) w9`
  (little-endian, under `¬SCTLR_EL1.E0E`). Nothing else changes.
- With `w9` = byte-reversed `w0` shifted right by 16, the final bytes are
  `a[1] = (15 >< 8) w0`, `a[2] = (7 >< 0) w0` (big-endian count), `a[0] = 0`.

## 3. What the L3 model says about alignment

`CheckAlignment_def`: an unaligned access raises `ALIGNMENT_FAULT` only if
the access type is `ATOMIC` or `ORDERED`, or `SCTLR.A` is set. At EL0 the
register is `SCTLR_EL1`. Otherwise the state is unchanged and the access
proceeds. The model has no Normal/Device memory distinction. Nothing is
claimed about Device memory.

Machine-checked, from the definitions, with the library's own evaluator
(`utilsLib.STEP`), no axiom, no alignment assumption:

- `check_alignment_no_fault`: `EL = 0 ∧ ¬SCTLR_EL1.A ∧ acctype ∉ {ATOMIC,
  ORDERED} ⇒ CheckAlignment (address, n, acctype, iswrite) s = s`.
- `write_mem2_no_alignment`: the 2-byte `write'Mem` under those premises
  and `¬E0E`.
- `sturh_w9_x19_1_step_no_alignment`: `NextStateARM8` for word `78001269`.
  Premises: no exception, EL0, `¬E0E`, `¬SCTLR_EL1.A`, `aligned 2 PC`, the
  four fetched bytes. No condition on the data address.

Exception behavior (controls):

- `check_alignment_fault`: with `SCTLR_EL1.A` set and `¬aligned 1 address`
  the check sets `exception := ALIGNMENT_FAULT`.
- `sturh_w9_x19_1_alignment_fault`: then `NextStateARM8 s = NONE` for this
  word. Premises shown satisfiable
  (`sturh_alignment_fault_premises_satisfiable`).

## 4. Composition

- `ffiwrite_suffix_ok_unaligned_run` (10 steps) under
  `ffiwrite_return_ok_na_pre` (the U397 return pre-state, with
  `¬SCTLR_EL1.A` in place of `aligned 1 (a + 1w)`).
- `cake_ffiwrite_path_successful_write`: from `ffiwrite_call_pre`, 23
  steps reach `pc = g`, `x30 = 0x10002522C`. For every `s2` with
  `write_call_rel dm s1 s2`, `¬s2.SCTLR_EL1.A` and bit 31 of w0 clear, 10
  more steps give `s3` with:
  - `s3.PC = s.REG 30w` (caller return address), `s3.SP_EL0 = s.SP_EL0`;
  - x19–x28 equal to the entry values; `arm8_user s3`;
  - `a[0] = 0`, `a[1] = (15 >< 8) w0`, `a[2] = (7 >< 0) w0`;
  - every `q ∈ dm` other than `a`, `a+1`, `a+2` unchanged.
- `cake_ffiwrite_path_returns`: both outcomes. For every `s2` with
  `write_call_rel dm s1 s2 ∧ ¬s2.SCTLR_EL1.A` there are `n`, `s3` with the
  common conclusions above, and: bit 31 set → `n = 6` and
  (`a ∈ dm ⇒ a[0] = 1`); bit 31 clear → `n = 10` and the three bytes.
- U397 `cake_ffiwrite_path_failed_write` re-imported exact, unchanged.

## 5. Exact proof assumptions

1. `ffiwrite_call_pre dm s b c a g` (19 conjuncts, unchanged from U397):
   user state at pc 0x100004090; `refund_image_mem 0w s.MEM` (slide 0);
   `sp = b + 32`, `aligned 3 b`; `x0 = c`, `aligned 2 c`; `x2 = a`,
   `aligned 1 a`; `x1 = 8`; `¬word_msb x3`; `n + off + 4 ≤₊ x3`; the
   `__got` slot value `g`; frame, image, `c`, `a` separations; frame
   outside `dm`.
2. `write_call_rel dm s1 s2` for the external call. ASSUMED. No theorem
   derives it from an implementation. It says nothing about the output.
3. `¬s2.SCTLR_EL1.A` on the return state. NEW, explicit. The relation
   does not preserve `SCTLR_EL1`, so the premise is on `s2`.
4. The L3 ARMv8 model as the machine semantics.

Not strengthened: `clen = 8` and the buffer bound stay premises of
`ffiwrite_call_pre`. The oracle does not enforce them
(`ffi_write_accepts_wrong_clen`, re-imported). The oracle contract is
unchanged.

## 6. Controls

New: `sturh_w9_x19_1_alignment_fault` (alignment fault);
`write_success_result_bytes_exact`, `write_wrong_result_bytes_refuted`
(incorrect bytes); `write_return_to_wrong_address_not_in_relation`,
`write_success_caller_return_address_exact` (return addresses);
`write_result_bytes_in_image_not_covered` (protected memory); changed
store word `78001268` rejected; without the new step theorem the library
rejects the store. Import controls: no 2-byte alignment condition in the
new step, suffix or pre-state; the success theorem's only premise is the
unchanged U397 pre-state; `¬SCTLR_EL1.A` explicit; `write_call_rel` only
as a premise, in refutations, or with constructed inhabitants; no U398
theorem mentions `machine_reach`, `machine_sem`, `ffi_interfer_ok`,
`refund_ffi_contract` or `ffi_write`.

Preserved (re-imported exact): U397 failed-write theorem,
`write_call_rel_def`, `write_wrong_clen_not_covered`,
`corrupted_return_state_not_in_write_relation`,
`write_frame_in_protected_domain_not_covered`,
`write_result_bytes_in_frame_not_covered`,
`ffiwrite_ok_alignment_conflict`. The U394–U396 `close` theorems are in
the closure; the full 172-statement import was NOT re-run.

## 7. Defects found and excluded

- `fault-0001` exited 0, but its theorem had a `BigEndian` premise that
  contradicts `¬E0E`. It is vacuous. Not used. Replaced by `fault-0003`.
- `wsucc-0001`: the first form of `cake_ffiwrite_path_returns` had a
  failed-write branch that asserted nothing. Not used. Corrected in
  `wsucc-0002`.

## 8. Formal reachability of `write` (investigated; NOT proved)

Record: `records/success/reachability-investigation.txt`.

- The exported top-level theorem (`refund_behavior_abstract_env`) has
  `∃io_events` with no constraint. It cannot show that a `write` event
  occurs. So no reachable `write` call state follows from present
  theorems.
- A proof route exists in two lemmas, both NOT RUN:
  (a) target semantics: if the event trace gains a `write` event, a state
  with pc 0x100004090 was reached (`machine_reach`); induction on
  `evaluate`, plus a machine step for the install branch.
  (b) the source specification gives
  `STDIO (add_stdout (fastForwardFD fs 0) output)`; from `extract_fs`,
  non-empty `output` implies a `write` event. This needs the trace kept
  in the exported theorem.
- A resource-limit stop before any call stays possible. The reachable
  statement is "a run that terminates with non-empty output reaches the
  call", not "every run".
- No witness was constructed for a reachable call. All inhabitants here
  are constructed states.

## 9. Actual exits

| Case | Exit | Note |
| --- | --- | --- |
| `dbg-0001` / `dbg-0002` / `dbg-0003` | 1 / −15 / 0 | diagnostics; no theorem |
| `uns-0001`–`0004`, `0006` | 1 each | authoring |
| `uns-0005` | −24 | CPU limit (non-terminating fault tactic) |
| `uns-0007` | 0 | `forge_refundFfiwriteUnaligned` |
| `uns-0007r` | 0 | repeat; statements identical |
| `fault-0001` | 0 | DEFECTIVE (vacuous); not used |
| `fault-0002` | 1 | authoring |
| `fault-0003` | 0 | `forge_refundFfiwriteFault` |
| `wsucc-0001` | 1 | authoring; defective statement not used |
| `wsucc-0002` | 0 | `forge_refundFfiwriteSuccess` |
| `import-0001` | 0 | 18 exact statements; 533 closure nodes; four `bool` axioms |
| Repeats of `wsucc`/`import`; full import; reachability proof | NOT RUN | swap 11.5 of 13.3 GiB used |

Failures: authoring as listed. Tool: none. Memory: none (swap near its
limit throughout). Logical: two defective statements, found and excluded.

## 10. Remaining FFI obligations

1. `write_call_rel` for the real `libSystem` `write`; dynamic binding of
   `g`; that the real process has `SCTLR_EL1.A` clear and keeps it clear.
2. Output effect and oracle conformance (`ffi_write` against the real
   call). Unverified.
3. `clen = 8`, the buffer bound, alignment of `c` and `a`, stack and
   separation premises: not derived from the published semantics.
4. Formal reachability (section 8); real-process/model simulation.
5. `read` (0x1000040A0) and `open_in` (0x100004070): not started.
6. `close`: assumptions of U394–U396 unchanged. Load slide: open.

## 11. Smallest next step

Lemma (a) of section 8: "a new `write` event in the target-semantics
trace implies a reachable state at pc 0x100004090". It needs one
CakeML-context theory and no new assumption.
