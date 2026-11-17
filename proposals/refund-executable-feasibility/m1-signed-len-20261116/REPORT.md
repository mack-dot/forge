# U396: signed `alen ≥ 1` at reachable `close` call states of the model, under one new explicit premise; no reachable `close` call is established, and the sources indicate there is none

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted. Nothing committed.
Local results: same machine, same agent, cached parents. No clean replay. No independent replay. No native execution.

Run directory: `results/refund-signed-len-local-20261116/attempt-0001`.
All U386–U395 theories are imported unchanged. `import-0002` re-checks the published `compile_correct'` identity, the exact code and
data identity and every earlier negative control.

Scope: the name `close` only. Model machine only.

## 1. Commands and actual exits

`python3 -I -B run_case.py <case> <source> <deps…>` through `go.sh`, `go-imp.sh` (CakeML context).
Exact argument vectors: `records/signed/<case>/command.json`. Full list: `records/exits.json`.

| Case | Exit | Kind |
| --- | --- | --- |
| `signed-0001`–`0004` | 1 each | authoring (instantiation of one lemma) |
| `signed-0005` | 0 | signed call-site theorem checked; superseded |
| `signed-0006` | 0 | final theory `forge_refundSignedLen`, 83 s |
| `import-0001` | 1 | authoring (form of one expected term) |
| `import-0002` | 0 | 143 statements (141 exact, 2 identical to published), structural checks, 527 closure nodes |
| `signed-repeat` | 0 | every exported file byte-identical |
| `grep`/`sed` on the pinned sources (`reachability-evidence.txt`) | 0 | text inspection |

Tool failures: none. Memory failures: none. Logical failures: none.

## 2. Signed-length verdict

**The bound is not derivable from the established invariants.**

- `heap_premises_admit_huge_heap`: `∃h e. aligned 3 h ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧ refund_heap_clear h e ∧ 0x8000000000000000w ≤₊ e − h`.
  The premises on the heap range permit a range of 2^63 bytes or more. So the program-address set of U390–U395 has no size bound,
  and "a readable array needs that many distinct program addresses" does not constrain `x3`.
- The proposed size bound therefore does not come from anything proved so far. Its true origins, none of them a Forge theorem:
  (a) the compiler's internal heap limit (`max_heap_limit` in the published data-to-word phase), which `compile_correct'` does not export;
  (b) for a real process, the size of the user address space;
  (c) for this call in the basis source, the array is the fixed I/O buffer `iobuff` (read from the source text).

**What is proved, with one NEW explicit premise.**

`addresses_below_half dm ⇔ ∀a. a ∈ dm ⇒ a <₊ 0x8000000000000000w` (every program address is below 2^63).

- `read_bytearray_below_half_bound`: a successful read of `n` bytes through a domain below 2^63 that misses one address below 2^63
  has `n < 2^63`. (A run of 2^63 or more consecutive addresses leaves the lower half or covers all of it.)
- **`close_call_site_signed_alen`:**

```
machine_reach mc ffi ms mc1 ffi1 ms1 ∧ refund_static mc dm ∧ ffi.oracle = basis_ffi_oracle ext ∧
machine_sem mc ffi ms ⊆ extend_with_resource_limit {Terminate Success io} ∧ ms1.PC = 0x100004080w ∧
addresses_below_half dm ⇒
ms1.REG 1w = 8w ∧ ms1.REG 3w ≠ 0w ∧ ¬word_msb (ms1.REG 3w) ∧ 0w < ms1.REG 3w
```

  `0w < ms1.REG 3w` is the signed comparison: `alen ≥ 1` as a signed 64-bit value.
- `refund_mem_dm_below_half`: `e ≤₊ 0x8000000000000000w ⇒ addresses_below_half (refund_mem_dm h e)`.
- `close_call_site_signed_alen_model`: the instance at the model record, with the extra premise `e ≤₊ 0x8000000000000000w`.

The premise "heap end at or below 2^63" is new and unproved. It replaces a premise on each call state by one static premise on the
machine record. It is not an established invariant, and I do not count the sign condition as independently discharged.

## 3. Reachability verdict

**No reachable `close` call state is established. The sources indicate that the refund program never issues the `close` FFI call.**

Text inspection (`reachability-evidence.txt`, with commands and file hashes; NOT a proof):

- In the basis, `#(close)` occurs only in `raw_closeIn` and `closeOut`.
- `refund_main` is `case TextIO.inputAllFrom None of None => raise Fail … | Some wire => TextIO.print (refund_dispatch wire)`.
- `inputAllFrom None` uses `open_option None`, whose close action for standard input is `consume_rest` (reads to end of input); it does
  not call `closeIn`. `print` writes through `#(write)`.
- No refund program source calls `closeIn`, `closeOut` or `raw_closeIn`. (One match is an SML build-script call on a host file, not program code.)

Consequences:

- I prove no reachable witness, because the evidence says none exists. A constructed state that satisfies the premises
  (`fficlose_call_pre_witness`, U394) is only satisfiable; no theorem relates it to `machine_reach` (`import-0002` checks this).
- The theorems of U394–U396 about `close` call states are then true for every execution of the refund program for the trivial reason
  that there is no such state. They are still correct statements about the linked code, and their method carries over to `read` and `write`.
- A formal proof of unreachability is NOT RUN. It cannot be read off the file-system-level specification: a failed `close` leaves the
  file-system model unchanged, so the proved output theorem does not exclude it. It needs an event-level or call-graph argument.

## 4. Strongest theorem and composition

**`cake_fficlose_path_at_reachable_call_signed`:** under the premises of `refund_behavior_abstract_env` and `e ≤₊ 0x8000000000000000w`,
for the state `ms` after the 27 start-up steps, every reachable configuration of the model record with
`fficlose_call_pre_no_len_sign dm ms1 b c g` (13 conjuncts) satisfies the conclusion of `cake_fficlose_path`
(15 steps to the branch into `libSystem`; for every `s2` with `close_call_rel dm s1 s2`, 6 steps back to `ms1.REG 30w` with the
registers, stack pointer and protected domain as stated in U394).

The 16 call-state premises of U394:

| Premise | State |
| --- | --- |
| `s.REG 1w = 8w` | DISCHARGED for reachable model call states (U395) |
| `s.REG 3w ≠ 0w` | DISCHARGED for reachable model call states (U395) |
| `¬word_msb (s.REG 3w)` | REPLACED by the new static premise `e ≤₊ 2^63`; not independently discharged |
| `arm8_user s`; `s.PC = 0x100004080w`; `refund_image_mem 0w s.MEM` | KEPT (3) |
| `s.SP_EL0 = b + 32w`; `aligned 3 b`; `s.REG 0w = c`; `aligned 2 c` | KEPT (4) |
| `mem_dword s.MEM 0x100028020w = g` | KEPT (a parameter; dynamic binding open) |
| frame outside the image range; frame outside the configuration bytes; frame outside `dm`; result address outside the frame; result address outside the image range | KEPT (5) |

Of the fourteen premises that remained after U395, none is independently discharged in U396. One is traded for a static premise.
`close_call_rel` stays an explicit, unproved assumption about the external call.

## 5. Negative controls

Stored theorems (`signed-0006`):

1. Signed-negative values: `negative_alen_not_covered` (`word_msb (s.REG 3w) ⇒ ¬fficlose_call_pre_no_len dm s b c g`).
2. The bound needs its premise: `universe_not_below_half`; `high_heap_end_not_below_half` (a heap that starts at or below 2^63 and ends
   above it breaks the premise); `heap_premises_admit_huge_heap` (the earlier premises do not give it).
3. Unreachable-state assumptions: `arbitrary_state_can_violate_arguments`: `∃ms1. ms1.PC = 0x100004080w ∧ ms1.REG 1w ≠ 8w ∧ word_msb (ms1.REG 3w)`.
   The conclusions are false for an arbitrary state; the reachability premise does the work.
4. Invalid lengths: U395 `ffi_close_rejects_invalid_lengths`, `invalid_clen_call_halts_in_model` and U394
   `invalid_clen_reaches_assert_block`, `zero_alen_reaches_assert_block` re-checked.
5. Vacuous implications: `import-0002` checks that no stored theorem asserts a reachable `close` call state (`machine_reach` occurs only
   as a premise and in the reflexivity lemma) and that the U394 witness is a constructed state. This report states the consequence
   in section 3 instead of hiding it.

Other scope controls in `import-0002`: both theorems that conclude the signed bound carry the low-half premise; no U396 theorem states
`ffi_interfer_ok` or `refund_ffi_contract`; every U396 theorem is at slide 0; the composed theorem keeps `close_call_rel`.

## 6. Assumption ledger for the strongest theorem

| Assumption | Class |
| --- | --- |
| Premises of `refund_behavior_abstract_env` (entry pre-state at slide 0, conditions on `e`, `refund_heap_clear`, program-address equation, input premises, oracle `basis_ffi`) | ASSUMED |
| `e ≤₊ 0x8000000000000000w` | NEW, ASSUMED, explicit |
| Model record: identity `next_interfer`, `refund_abs_ffi` | MODEL ASSUMPTION |
| `fficlose_call_pre_no_len_sign` at the call state (13 conjuncts) | ASSUMED |
| `close_call_rel` | ASSUMED, unproved external implementation assumption |
| Real macOS execution, dynamic binding, loader, PIE slide, oracle conformance | OUTSIDE the proved scope; open |

Dependency closure (`import-0002`): 527 theory nodes; axioms only `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`,
`bool.BOOL_CASES_AX`; every stored theorem and definition of `forge_refundSignedLen` (12 theorems, 2 definitions) has tag `DISK_THM`
only and no hypothesis.

## 7. Counterexamples and blockers

No counterexample to a stored theorem. `heap_premises_admit_huge_heap` is a formal obstacle to the unconditional bound.
No logical blocker.

## 8. Next minimal obligation

Move to an FFI name that the program does use. `write` is issued by `TextIO.print` on every successful run, and its entry stub is
`cake_ffiwrite` at `0x100004090`. The smallest step is the U393 treatment for that stub and `ffiwrite` (exact words, steps to the
`libSystem` branch). This needs your decision, because U394–U396 were restricted to `close`.
Alternative that stays on `close`: a formal unreachability proof (event-level statement that no `close` event occurs), which would
turn section 3 from inspection into a theorem.

M1 open. Integration EXIT NOT_ESTABLISHED. end_to_end=false.
