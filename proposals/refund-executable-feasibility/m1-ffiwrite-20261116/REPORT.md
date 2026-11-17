# M1 — the real `write` FFI execution path (U397)

Date: 2026-11-16. Local runs, same machine, same agent, cached parent
theories. No clean replay. No independent replay. No native execution.
CURRENT none. M1 open. Stage 12 unauthorized. No profile approved.
`end_to_end=false`. Nothing committed.

Run directory: `results/refund-ffiwrite-local-20261116/attempt-0001`.
Executable: `results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund`
(Mach-O arm64, never executed).

## 1. Result in one paragraph

A conditional machine-level execution theorem for `write` is checked:
`cake_ffiwrite_path_failed_write`. It is non-vacuous
(`ffiwrite_call_pre_satisfiable`, `cake_ffiwrite_failed_path_inhabited`).
It covers the complete path only for the outcome "the external call
returns a negative 32-bit value". For the outcome "the external call
succeeds", the path to the call (23 steps) and the return suffix (10 steps)
are each checked, but they are NOT composed. No reachable `write` call
state is proved. The success criterion is met in part only.

## 2. Bytes and file correspondence (machine-checked)

| Item | Address | File offset | Words |
| --- | --- | --- | --- |
| `cake_ffiwrite` stub | 0x100004090 | 0x4090 | `14008454` = `b 0x1000251E0` |
| `_ffiwrite` | 0x1000251E0–0x100025254 | 0x251E0 | 30 words (see `refund_file_ffiwrite_words`) |
| import stub for `write` | 0x1000259C4 | 0x259C4 | `f0000010 f9405a10 d61f0200` |
| `__got` slot read by the stub | 0x1000280B0 | — | value `g`, not fixed by the file |

- `refund_file_ffiwrite_words`: the three slices of `refund_file`.
- `refund_image_ffiwrite_code`: `refund_image_mem 0w m ⇒ ffiwrite_code_bytes m`.
- `cake_ffiwrite_stub_exact`: one step from 0x100004090 to 0x1000251E0;
  registers, memory, stack pointer unchanged.
- `cake_ffiwrite_stub_does_not_return`: the stub is a jump, not a call.

## 3. Path from the entry to the external-call boundary

`cake_ffiwrite_to_import_branch` (23 steps = 1 stub + 19 body + 3 import
stub), under `ffiwrite_call_pre dm s b c a g` (19 conjuncts):

- Register inputs: x0 = `c` (configuration bytes), x1 = 8 (`clen`),
  x2 = `a` (array), x3 = `alen`, sp = `b + 32`, x30 = caller return address.
- Stack: 32 bytes at `b`. Saved x20, x19 at `b`, `b+8`; x29, x30 at `b+16`,
  `b+24`. `b` is 8-aligned.
- Memory reads: 4 bytes at `c + 4` (file descriptor, byte-reversed);
  halfwords at `a` and `a + 2` (`n`, `off`, byte-reversed); the `__got`
  slot at 0x1000280B0.
- Memory writes before the call: only the 32-byte frame.
- Dynamic-call target: `br x16` with x16 = `g`. The theorem ends at
  `pc = g`. `g` is a variable. Dynamic binding is not modelled.
- State at the boundary: x0 = fd, x1 = `a + off + 4`, x2 = `n`,
  x19 = `a`, x30 = 0x10002522C, sp = `b`.
- `ffiwrite_clen_bad_reaches_assert`: with x1 ≠ 8 the code reaches
  0x100025258 (the `assert` cold path) in 5 steps. That path is not followed.

## 4. Return suffix under the explicit external-call relation

`write_call_rel dm s1 s2` (assumed, not proved for any implementation):
user state; `pc = x30` of the call state; sp, x19–x28, the 32 frame bytes,
the image range and `dm` unchanged. It does not constrain x0 or the output.

- `cake_ffiwrite_path_failed_write`: from `ffiwrite_call_pre`, 23 steps
  reach the call; for every `s2` with `write_call_rel dm s1 s2` and bit 31
  of w0 set, 6 more steps return to the caller's x30 with sp and x19–x28
  restored, and memory in `dm` unchanged except `a[0] = 1`.
- `ffiwrite_suffix_ok_run` (standalone, 10 steps): `a[0] = 0`, `a[1..2]` =
  the 16-bit result, big-endian. Its premise needs `aligned 1 (a + 1w)`.

### Limitation: the success outcome is not composed

The code reads halfwords at `a` and stores a halfword at `a + 1`. The
ARMv8 step library gives step theorems only under alignment hypotheses.
`ffiwrite_ok_alignment_conflict`: `¬(aligned 1 a ∧ aligned 1 (a + 1w))`.
`write_success_suffix_premise_excluded`: `ffiwrite_call_pre ⇒ ¬aligned 1 (a + 1w)`.
The L3 model itself permits the unaligned store when `SCTLR_EL1.A` is
clear. So this is a gap in the available step theorems, not evidence of a
fault in the code. Closing it needs a step theorem for an unaligned
halfword store, derived from the model. NOT RUN.

## 5. Call-site argument requirements from the published semantics

Model machine only (`machine_reach`, `refund_static`, behaviour inclusion
in success-or-resource-limit, oracle `basis_ffi_oracle`).

- `write_call_site_facts`: at every reachable model state with
  pc = 0x100004090, both byte arrays are readable, `4 ≤ LENGTH abytes` and
  `4 ≤ w2n x3`.
- NOT derivable this way: `clen = 8` and `n + off + 4 ≤ alen`.
  `ffi_write_accepts_wrong_clen`: the oracle returns a result for an empty
  configuration. The C `assert`s have no counterpart that the oracle
  enforces. Their origin is the basis source (`writei`). They stay premises.
- Also premises, not derived: alignment of `c` and `a`, `¬word_msb x3`,
  stack placement and all separation conjuncts.

## 6. Does the program reach `write`?

- Source inspection (`records/ffiwrite/reachability-evidence-write.txt`):
  `refund_main` calls `print`; `print` = `output stdOut`; `output` →
  `write` → `writei` → `#(write)`. Text inspection, NOT a proof.
- Formal reachability: NOT PROVED. The behaviour set admits a
  resource-limit stop before any call, so "every run reaches `write`" is
  false as stated. A statement of the form "a run with output `io ≠ []`
  passes pc 0x100004090" was not attempted.
- No witness was constructed for a reachable call. The inhabitant of
  `ffiwrite_call_pre` is a constructed state (`sat_mem`); no theorem
  relates it to `machine_reach`.

## 7. Smallest external-call contract and observable effects

Contract used: `write_call_rel` (section 4) plus a case on the sign of w0.

Observable effects, SPECIFIED ONLY. Not proved, not authorized, not part of
any theorem:

- Input to the external call: fd = 4 bytes at `c+4` (big-endian as stored),
  buffer `a + off + 4`, count `n`.
- Expected effect: at most `n` bytes from the buffer are appended to the
  open file `fd`; w0 = count written, or negative on error.
- Model counterpart: `ffi_write` in `fsFFI` (result bytes `0, nw_hi, nw_lo`
  or `1`). No theorem relates `ffi_write` to machine steps or to
  `write_call_rel` (import control).

## 8. Negative controls (all checked)

`cake_ffiwrite_stub_does_not_return`; changed-word control (stub word
`14008455` is rejected by the fetch hypotheses); `ffiwrite_clen_bad_reaches_assert`;
`write_wrong_clen_not_covered`; `write_length_violation_not_covered`
(incorrect buffer length); `corrupted_return_state_not_in_write_relation`
(wrong return address, sp, x19, frame bytes);
`write_frame_in_protected_domain_not_covered` and
`write_result_bytes_in_frame_not_covered` (memory overlap);
`ffiwrite_ok_alignment_conflict`; `ffi_write_accepts_wrong_clen`.
Import controls: no U397 theorem asserts a reachable `write` call, states
`ffi_interfer_ok` or `refund_ffi_contract`, or derives `write_call_rel`.

## 9. Preserved

- U394–U396 `close` theorems re-imported exact, with their limitations.
  The `close` obligation stays in the published universal FFI contract.
- `compile_correct'` and the code/data identity re-checked in `import-0001`.
- Closure: 531 nodes; axioms only the four of `bool`. 172 `IMPORTED` lines.

## 10. Actual exits

| Case | Exit | Note |
| --- | --- | --- |
| `steps-0001` | 0 | step theorems exist for every word |
| `ffiw-0001`–`0004`, `0006`, `0007` | 1 each | authoring |
| `ffiw-0005` | -15 | diagnostic; stopped by the agent |
| `dbg-0001` | 0 | diagnostic; no theorem |
| `ffiw-0008` | 0 | `forge_refundFfiwriteStep` |
| `ffiw-0008r` | 0 | repeat; statements identical |
| `wpath-0001` | 1 | authoring (wrong offset in the script) |
| `wpath-0002` | 0 | `forge_refundFfiwritePath` |
| `wcomp-0001` | 0 | `forge_refundFfiwriteCompose` |
| `wsite-0001`, `0002` | 1 each | authoring |
| `wsite-0003` | 0 | `forge_refundFfiwriteSite` |
| `import-0001` | 0 | import and controls |
| Repeat of path/compose/site/import | NOT RUN | swap near its limit |

Failures: authoring as listed. Tool: none. Memory: none. Logical: none.

## 11. Remaining FFI obligations

1. Success outcome of `write`: unaligned-store step theorem, then composition.
2. `write_call_rel` for the real `libSystem` `write`; dynamic binding of `g`.
3. Output effect and oracle conformance (`ffi_write` against the real call).
4. `clen = 8`, the length bound, alignment, stack and separation premises.
5. Formal reachability of the call state; real-process/model simulation.
6. `read` (0x1000040A0) and `open_in` (0x100004070): not started.
7. `close`: assumptions of U394–U396 unchanged. Load slide: open.

## 12. Next step (owner decision)

Recommended: derive an unaligned halfword-store step theorem from the L3
model (`SCTLR_EL1.A` clear as an explicit premise) and compose the success
outcome. Alternative: apply the same method to `read`.
