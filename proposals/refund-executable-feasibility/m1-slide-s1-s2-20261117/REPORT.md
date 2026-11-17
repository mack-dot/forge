# M1 — relocation correctness, steps S1 and S2 (U405)

Date: 2026-11-17. Local runs, same machine, same agent, cached parent
theories. No clean replay. No independent replay. No native execution.
CURRENT none. M1 open. Profile A NOT approved. Stage 12 unauthorized.
`end_to_end=false`. Continues U404.

Run directory: `results/refund-slide-local-20261117/attempt-0001`.
Theories: `forge_refundCmlMainSlide` (`s1-0001`, ARMv8 context, exit 0);
`forge_refundSlideEntry` (`s2-0003`, CakeML context, exit 0, 18
theorems, 6 definitions). One run each.

## 0. What S1 and S2 mean

The U404 plan and the U405 mission text use the labels differently. I
did not relabel silently.

| Label | U404 plan | U405 mission text | Done here |
| --- | --- | --- | --- |
| S1 | 27 start-up steps at a slide | linked instruction bytes at relocated addresses | Both: `cml_main_run_sl` and `refund_entry_pre_sl_IMP_cml_main_pre_sl` |
| S2 | shifted domains, no-wrap lemmas | address calculations preserved, including `ADRP` | Both: the domain lemmas; the `ADRP` arithmetic is inside S1 and stated alone in `page_of_relocated_address` |

## 1. Verdicts

- **S1: PROVED** (model; one run). From the entry state at a
  page-aligned, non-wrapping slide `sl`, 27 L3 steps reach
  `sl + 0x1000040D0w`; registers and the five header words are the
  slide-0 values plus `sl`.
- **S2: PROVED** (one run). Shifted domains, range forms under
  `slide_ok`, disjointness, slide-0 regression.

Neither says anything about a loader or a real process.

## 2. Definitions and assumptions

    slide_ok sl ⇔ aligned 12 sl ∧ sl ≤₊ 0xFFFFFFFEFFFCF0CFw
    slide_ok_no_wrap: slide_ok sl ⇒ w2n sl + 0x100030F30 < 2 ** 64

    refund_entry_pre_sl sl s h stk e ⇔
      ¬E0E ∧ ¬SA0 ∧ ¬TBI0 ∧ ¬TBI1 ∧ EL = 0w ∧ no exception ∧
      s.PC = sl + 0x100004000w ∧
      mem_dword s.MEM (sl + 0x10002C000w) = h ∧ (… + 8) = stk ∧ (… + 16) = e ∧
      aligned 3 h ∧
      (∀i j. i < 40 ∧ j < 200496 ⇒ h + n2w i ≠ 0x100000000w + sl + n2w j) ∧
      refund_image_mem sl s.MEM ∧ slide_ok sl

    refund_code_dm_sl sl    = {a | a − sl ∈ refund_code_dm}
    refund_bitmaps_dm_sl sl = {a | a − sl ∈ refund_bitmaps_dm}
    refund_mem_dm_sl sl h e = code ∪ {w | h ≤₊ w ∧ w <₊ e} ∪ bitmaps
    refund_heap_clear_sl sl h e ⇔ ∀a. h ≤₊ a ∧ a <₊ e ⇒
        ¬(0x100000000w ≤₊ a − sl ∧ a − sl <₊ 0x100030F30w)

The separation clause is in offset form, so it has no wrap-around case.
`refund_image_mem sl m` is the U389 predicate (file bytes at
`0x100000000w + sl` and bitmaps at `0x10002C018w + sl`). The file is the
one with SHA256 `b8ed5ec2…7bb8`; it was not touched and not executed.

All of `refund_entry_pre_sl` is ASSUMED. The loader, dyld, the C
run-time and macOS conformance are not modelled and not proved.

## 3. Theorem statements (stored; read after exit 0)

S1, ARMv8 context:

    cml_main_run_sl:
      cml_main_pre_sl sl s h stk e ⇒
      ∃s1. arm8_run 27 s = SOME s1 ∧ s1.PC = sl + 0x1000040D0w ∧
           s1.REG 0w = sl + 0x1000040D0w ∧ s1.REG 1w = h ∧
           s1.REG 2w = stk ∧ s1.REG 3w = e ∧
           mem_dword s1.MEM h        = sl + 0x10002C018w ∧
           mem_dword s1.MEM (h + 8w)  = sl + 0x100030F30w ∧
           mem_dword s1.MEM (h + 16w) = sl + 0x100030F30w ∧
           mem_dword s1.MEM (h + 24w) = sl + 0x100023E54w ∧
           mem_dword s1.MEM (h + 32w) = sl + 0x100024000w

    page_of_relocated_address:
      aligned 12 sl ⇒
      (a + sl) && 0xFFFFFFFFFFFFF000w = (a && 0xFFFFFFFFFFFFF000w) + sl

`cml_main_pre_sl` lists the 108 code bytes at `sl + 0x100004000w + k`
and has `aligned 12 sl`. Nine `ADRP` results were normalised; each
instance was bit-blasted from `4095w && sl = 0w`. The fetch alignment
of each relocated PC was proved the same way.

S1, CakeML context (bytes from the file image):

    refund_entry_pre_sl_IMP_cml_main_pre_sl:
      refund_entry_pre_sl sl s h stk e ⇒ cml_main_pre_sl sl s h stk e
    refund_entry_run_sl:
      refund_entry_pre_sl sl s h stk e ⇒ (conclusion of cml_main_run_sl)
    refund_image_code_at_slide:
      refund_image_mem sl m ⇒ bytes_in_memory (0x1000040D0w + sl) code m 𝕌
    slide_zero_entry_is_the_old_entry:
      refund_entry_pre s h stk e ⇒ refund_entry_pre_sl 0w s h stk e
    arm8_run_constants_agree (the two run functions are equal)

S2:

    refund_code_dm_sl_range:
      slide_ok sl ⇒ ∀a. a ∈ refund_code_dm_sl sl ⇔
        0x1000040D0w + sl ≤₊ a ∧ a <₊ 0x100024000w + sl
    refund_heap_clear_sl_range:
      slide_ok sl ⇒ (refund_heap_clear_sl sl h e ⇔ ∀a. h ≤₊ a ∧ a <₊ e ⇒
        ¬(0x100000000w + sl ≤₊ a ∧ a <₊ 0x100030F30w + sl))
    refund_shifted_domains_disjoint:
      DISJOINT (refund_code_dm_sl sl) (refund_bitmaps_dm_sl sl)
    shifted_domains_at_slide_zero: the four `_sl 0w` objects equal the
      U390 objects
    relocated_code_addresses_in_shifted_domain:
      ∀i. i < LENGTH code ⇒ 0x1000040D0w + sl + n2w i ∈ refund_code_dm_sl sl
    shifted_heap_clear_keeps_heap_outside_code_and_bitmaps

## 4. Nonzero slides

- `cml_main_run_sl_at_0x4000`: end PC `0x1000080D0w`; header words
  `0x100030018w`, `0x100034F30w`, `0x100034F30w`, `0x100027E54w`,
  `0x100028000w`. Also at `0x2F8C000w` and at `0w`.
- `slide_ok_examples`: `0w`, `0x4000w`, `0x2F8C000w` are accepted.
- `nonzero_slide_moves_the_code_domain`: `0x1000080D0w` is in the code
  domain at slide `0x4000w`; `0x1000040D0w` is not.

Limit: no constructed state satisfies `refund_entry_pre_sl` at a
nonzero slide. Satisfiability is shown at slide 0 only (U389 witness
through `slide_zero_entry_is_the_old_entry`). NOT RUN.

## 5. Negative controls

| Control | Result |
| --- | --- |
| Misaligned slide: `page_of_misaligned_slide_differs` (`sl = 0x800w`) | proved: the page identity is false |
| Page identity without the alignment premise | bit-blasting refuses it (`CONTROL_OK`) |
| `misaligned_slide_not_covered`; `misaligned_or_wrapping_slide_not_covered` | proved: such slides do not satisfy the pre-states |
| Wrapping slide: `wrapping_slide_breaks_the_range_form` (`sl = 0xFFFFFFFEFFFF0000w`, page-aligned) | proved: the range form is false without no-wrap |
| `¬slide_ok 0x800w`, `¬slide_ok 4w`, `¬slide_ok 0xFFFFFFFEFFFF0000w` | proved |
| Unrelocated target at a nonzero slide: `cml_main_sl_unrelocated_target_refuted` | proved |
| Changed instruction word (`f9000023`) | rejected by the fetch hypotheses |
| Byte fact at the unrelocated address | does not discharge the fetch at the relocated PC (script check, weak) |
| `entry_fixes_image_and_pc_to_one_slide` | image and PC use the same `sl` |
| U389 slide-0 entry theorem | loaded unchanged (`CONTROL_OK`) |

Preserved: the U404 theorems and `compile_correct'` were not restated;
`forge_compileCorrectControl` is in the closure (536 nodes; axioms only
the four of `bool`).

## 6. Remaining relocation obligations

- **S3.** `refund_end_state_sl`; the 23 installed-state clauses of U390
  and the 5 of U391 at `refund_mc (0x1000040D0w + sl) envmc` with
  `refund_mem_dm_sl`. Also the frame lemma (memory outside the 40
  header bytes unchanged) at a slide: `cml_main_run_frame` exists at
  slide 0 only.
- **S4.** `ffi_interfer_ok_iff_contract` at the shifted base;
  `refund_env_ok` with `sl` as a parameter.
- **S5.** `refund_installed_from_entry_reduced_sl`; then the U404
  composition for every `slide_ok sl`.
- **S6.** Regression to `refund_profile_a_slide0` at `sl = 0w`.
- Also open: a satisfiability witness at a nonzero slide.

## 7. Reachable-call FFI contract: analysis and proposal (not implemented)

Problem. `compile_correct'` needs `installed`, which contains
`ffi_interfer_ok`, equivalent to `refund_ffi_contract` (U392). The
contract quantifies over every state `ms2`. The real C functions do not
meet it at states with invalid arguments (`assert` paths; U393
analysis). So `refund_env_ok` is probably false for an exact model of
the real code.

Proposal: a supplemental refinement lemma. The published theorem stays
unchanged.

1. For a real FFI effect `f` and a predicate `V index ms` (valid call
   state), define the totalised effect
   `f_tot k (i, bytes, ms) = if V i ms then f k (i, bytes, ms)
                             else refund_abs_ffi k (i, bytes, ms)`.
2. **L1 (contract on V suffices).** If `f` meets the contract clauses
   at every state with `V`, then `refund_ffi_contract dm f_tot`. So
   `refund_env_ok (envmc with ffi_interfer := f_tot)` and the U404
   theorem applies to the totalised machine.
3. **L2 (agreement).** If every FFI call state reachable in the
   totalised machine satisfies `V`, then for every clock
   `evaluate` of the real-effect machine equals `evaluate` of the
   totalised machine; hence equal `machine_sem`. Proof: induction on
   the clock over `machine_step` (the method of U399).
4. **L3 (V at reachable calls).** Per FFI name, from the totalised
   machine's behaviour theorem. Available: `close` arguments (U395);
   `write` arguments for successful events only (U400, U401).

Smallest statement to prove first: L2. It is generic and uses no refund
fact. L1 is a case split. L3 is where the open facts are: the
`write`-event invariant, the 12 residual `write` conjuncts, `read`,
`open_in`, and `f` meeting the contract on `V` (needs the C-path
theorems and the assumed `*_call_rel`).

Soundness note. L2 must take reachability in the totalised machine
(where theorems exist) and derive agreement step by step. Taking it in
the real-effect machine would be circular.

## 8. Current M1 acceptance blockers

1. Profile A is not approved (U403 R1–R5 open).
2. Contract link A8: 18 rows NOT REVIEWED.
3. Slide: S3–S6 not run. The composed theorem is at slide 0 only.
4. `refund_env_ok` for the real environment: assumed; probably false in
   its literal form (section 7).
5. Joint satisfiability of the composed premises: not shown.
6. Clean replay and independent replay: NOT RUN.

## 9. Actual exits

| Case | Exit | Note |
| --- | --- | --- |
| `s1-0001` | 0 | `forge_refundCmlMainSlide`; first run |
| `s2-0000-empty-aborted` | 1 | runner stopped before HOL: source file missing (my shell error) |
| `s2-0001` | 1 | authoring: three tactics; no statement change |
| `s2-0002` | −24 | CPU limit: a `metis` call did not terminate |
| `s2-0003` | 0 | `forge_refundSlideEntry` |
| Repeats; import script; nonzero-slide witness; S3–S6; L1–L3 | NOT RUN | |

Failures: authoring and one CPU limit as listed. Tool: none. Memory:
none. Logical: none found in stored statements.

## 10. Next step

S3 (frame lemma at a slide, then the installed-state clauses).
