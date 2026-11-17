# M1 — relocation correctness, step S3 (U407)

Date: 2026-11-17. Local runs, same machine, same agent, cached parent
theories. No clean replay. No independent replay. No native execution.
CURRENT none. M1 open. Profile A NOT approved. Stage 12 unauthorized.
`end_to_end=false`. Nothing committed or pushed in this run. Continues
U405.

Run directory: `results/refund-slide-s3-local-20261117/attempt-0001`.
The executable is unchanged: every CakeML-context run checks SHA256
`b8ed5ec2…7bb8` before it starts. It was not executed.

## 1. Verdict

**S3: PROVED for the model, one run per theory.** For every
`slide_ok sl`, from the explicit entry premise `refund_entry_pre_sl`,
the 27 start-up steps end in a state that satisfies 28 of the 30
clauses of the installed-state predicate at the relocated record
`refund_mc (sl + 0x1000040D0w) envmc`. The other two clauses
(`interference_ok`, `ffi_interfer_ok`) are NOT proved. They stay in the
stored residual `refund_installed_rest2`, as at slide 0.

S4, S5 and S6 are NOT started. No behaviour theorem is composed at a
slide.

## 2. U405 repeats and import check (done first)

| Check | Exit | Result |
| --- | --- | --- |
| `s1-repeat` (source SHA256 equal to `s1-0001`) | 0 | 4 of 4 theory objects byte-identical |
| `s2-repeat` (source SHA256 equal to `s2-0003`) | 0 | 3 of 3 theory objects byte-identical |
| `imp-0002` | 0 | 34 stored statements equal the statements written in the check script; 0 mismatches; all 68 theorems and 11 definitions of the six theories have clean tags; 4 checker controls |

The import check covers the U405 and the U407 theories. It runs on the
same machine with the same cached parents. It is not a replay.

## 3. Theories and exact statements

### 3.1 `forge_refundCmlMainFrameSlide` (`f1-0001`, ARMv8 context)

`cml_main_run_frame_sl`:

    cml_main_pre_sl sl s h stk e ⇒
    ∃s1. arm8_run 27 s = SOME s1 ∧ s1.PC = sl + 0x1000040D0w ∧
         s1.REG 0w = sl + 0x1000040D0w ∧ s1.REG 1w = h ∧ s1.REG 2w = stk ∧
         s1.REG 3w = e ∧ mem_dword s1.MEM h = sl + 0x10002C018w ∧
         mem_dword s1.MEM (h + 8w) = sl + 0x100030F30w ∧
         mem_dword s1.MEM (h + 16w) = sl + 0x100030F30w ∧
         mem_dword s1.MEM (h + 24w) = sl + 0x100023E54w ∧
         mem_dword s1.MEM (h + 32w) = sl + 0x100024000w ∧
         (∀a. (∀i. i < 40 ⇒ a ≠ h + n2w i) ⇒ s1.MEM a = s.MEM a) ∧
         s1.PSTATE = s.PSTATE ∧ s1.SCTLR_EL1 = s.SCTLR_EL1 ∧
         s1.TCR_EL1 = s.TCR_EL1 ∧ s1.exception = s.exception

The run re-derives the 27 steps. The re-derived run statement is
term-identical to the stored `cml_main_run_sl` of U405
(`RUN_STATEMENT_IDENTICAL true`). The stored pre-state definition is
used unchanged (`PRE_DEFINITION_IDENTICAL true`).

### 3.2 `forge_refundSlideDomains` (`d3-0003`; 27 theorems, 2 definitions)

Definitions:

    refund_t_sl sl ms = <| regs := (λi. ms.REG (n2w i)); fp_regs := (λi. 0w);
       mem := ms.MEM; mem_domain := refund_mem_dm_sl sl (ms.REG 1w) (ms.REG 3w);
       pc := ms.PC; lr := 30; align := 2; be := F; failed := F |>

    refund_end_state_sl sl ms ⇔ slide_ok sl ∧
       ms.PSTATE.EL = 0w ∧ ¬ms.SCTLR_EL1.E0E ∧ ¬ms.SCTLR_EL1.SA0 ∧
       ¬ms.TCR_EL1.TBI1 ∧ ¬ms.TCR_EL1.TBI0 ∧ ms.exception = NoException ∧
       ms.PC = sl + 0x1000040D0w ∧ aligned 3 (ms.REG 1w) ∧ aligned 3 (ms.REG 3w) ∧
       ms.REG 1w ≤₊ ms.REG 3w ∧ 8192w ≤₊ ms.REG 3w − ms.REG 1w ∧
       refund_heap_clear_sl sl (ms.REG 1w) (ms.REG 3w) ∧ refund_image_mem sl ms.MEM ∧
       mem_dword ms.MEM (ms.REG 1w) = sl + 0x10002C018w ∧ … (+8: 0x100030F30,
       +16: 0x100030F30, +24: 0x100023E54, +32: 0x100024000, each plus sl)

Theorems by logical group:

| Group | Theorems |
| --- | --- |
| Slide facts | `slide_ok_alignment_facts`; `slide_ok_bitmaps_no_wrap` (`w2n (sl + 0x10002C018w) + 20248 < 2⁶⁴`); `aligned_slide_commutes_with_byte_align` |
| Memory frame | `refund_image_preserved_sl`: the image predicate at `sl` survives every write outside it, given the header separation |
| Code | `refund_image_code_sl`; `refund_code_addr_in_code_dm_sl`; `refund_code_addr_in_dm_sl`; `refund_code_addr_not_excluded_sl`; `refund_code_bytes_in_mem_sl`; `refund_code_buffer_in_dm_sl`; `refund_code_loaded_sl` |
| Bitmaps | `refund_bitmaps_dm_sl_aligned`; `refund_bitmaps_dm_sl_closed`; `refund_image_bitmap_clause_sl` |
| Heap and stack region `{w | h ≤₊ w ∧ w <₊ e}` | `refund_heap_bitmaps_subset_sl`; `refund_heap_bitmaps_closed_sl`; `refund_heap_bitmaps_disjoint_sl`; `refund_heap_clear_sl_IMP_header_separation` |
| Asm state | `refund_t_sl_target_state_rel`; `refund_t_sl_target_configured` |
| End state | `refund_end_state_sl_established` (below) |
| Slide 0 (definitions only) | `slide_zero_asm_state_is_the_old_one`; `slide_zero_end_state_is_the_old_one` |

`refund_end_state_sl_established`:

    refund_entry_pre_sl sl s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧
    refund_heap_clear_sl sl h e ⇒
    ∃ms. arm8_run 27 s = SOME ms ∧ ms.REG 1w = h ∧ ms.REG 3w = e ∧
         refund_end_state_sl sl ms

Note on "stack". The model has one region `[h, e)` for heap and stack,
as CakeML does. `stk` is a pointer in a register. No separate stack
clause exists in the installed-state predicate.

### 3.3 `forge_refundSlideInstalled` (`a3-0006`; 10 theorems)

Witnesses of the stored predicate `refund_installed_no_handler`:
`t := refund_t_sl sl ms`; `m := λa. Word (mem_dword ms.MEM a)`;
`bitmap_ptr := sl + 0x10002C018w`; `bitmaps_dm := refund_bitmaps_dm_sl
sl`; `sdm := mc0.shared_addresses`. `cbspace = 428`, `data_sp = 0`.

`refund_installed_from_end_state_sl` (23 clauses):

    is_arm8_machine_config mc0 ∧
    mc0.prog_addresses = refund_mem_dm_sl sl (ms.REG 1w) (ms.REG 3w) ∧
    refund_end_state_sl sl ms ∧ refund_installed_rest mc0 ms ⇒
    refund_installed_no_handler mc0 ms 428 0

The seven residual clauses at a slide are term-identical to the stored
slide-0 residual `refund_installed_rest` (`RESIDUAL_IDENTICAL_TO_STORED
true`). No new residual constant was defined.

`refund_installed_rest_reduced_sl` (5 more clauses):

    refund_heap_clear_sl sl h e ∧ envmc.prog_addresses = refund_mem_dm_sl sl h e ∧
    ms.PC = sl + 0x1000040D0w ∧ slide_ok sl ∧
    refund_installed_rest2 (refund_mc (sl + 0x1000040D0w) envmc) ms ⇒
    refund_installed_rest (refund_mc (sl + 0x1000040D0w) envmc) ms

`refund_installed_from_entry_reduced_sl` (S3 summary):

    refund_entry_pre_sl sl s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧
    refund_heap_clear_sl sl h e ∧ envmc.prog_addresses = refund_mem_dm_sl sl h e ⇒
    ∃ms. arm8_run 27 s = SOME ms ∧ ms.PC = sl + 0x1000040D0w ∧
         (refund_installed_rest2 (refund_mc (sl + 0x1000040D0w) envmc) ms ⇒
          refund_installed_no_handler (refund_mc (sl + 0x1000040D0w) envmc) ms 428 0)

The U404 plan listed this statement as the first half of S5. I proved
it here because it is the statement that the 28 clauses hold from the
entry premise. It has no behaviour conclusion. The composition with the
U387 behaviour theorems is S5 and is NOT run.

Clause table (numbers as in the stored definition after normalisation):

| # | Clause | Status at a slide |
| --- | --- | --- |
| 1 | `target_state_rel` | proved |
| 2 | `target_configured` | proved |
| 3 | PC equals `get_pc` | proved |
| 4 | `start_pc_ok` | proved at `refund_mc` |
| 5 | PC aligned to 4 | proved (from `aligned 12 sl`) |
| 6 | `interference_ok` | **UNPROVED** (`rest2`) |
| 7 | `ffi_interfer_ok` | **UNPROVED** (`rest2`) |
| 8 | `code_loaded` | proved |
| 9 | `bytes_in_mem` for the code, outside heap and bitmaps | proved |
| 10 | heap ∪ bitmaps ⊆ program addresses | proved |
| 11 | heap ∪ bitmaps closed under `byte_align` | proved |
| 12, 13 | shared addresses closed; disjoint from program addresses | proved at `refund_mc` (empty set) |
| 14 | byte memory agrees with word memory | proved |
| 15 | 428-byte code buffer inside the domain | proved |
| 16 | size bound | proved |
| 17–21 | alignment and order of `h`, `e`, bitmap pointer; 8192 bytes | proved |
| 22 | heap and bitmaps disjoint | proved |
| 23–27 | five header words | proved |
| 28 | bitmap word list in memory | proved |
| 29 | `ffi_names` | proved at `refund_mc` |
| 30 | MMIO list and stub-space bound | proved at `refund_mc` |

Relocated stub addresses (`refund_mc_concrete_fields_sl`): halt
`sl + 0x1000040C0w`; install `sl + 0x1000040B0w`; FFI entries
`sl + 0x1000040A0w`, `…90w`, `…80w`, `…70w`. All six are outside
`refund_mem_dm_sl sl h e` (`refund_stub_outside_domain_sl`).

## 4. Assumptions of the S3 summary theorem

1. `refund_entry_pre_sl sl s h stk e`: EL0; no exception; four control
   bits; `PC = sl + 0x100004000w`; three data slots at `sl +
   0x10002C000w…`; the 40 header bytes outside the image;
   `refund_image_mem sl s.MEM`; `slide_ok sl`. FULLY ASSUMED. No
   theorem shows that macOS, dyld or the C run-time produces it.
2. `aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧ refund_heap_clear_sl sl h e`.
   ASSUMED.
3. `envmc.prog_addresses = refund_mem_dm_sl sl h e`. ASSUMED.
4. `refund_installed_rest2 …` (the two environment clauses). A premise
   of the inner implication. UNPROVED.

No new axiom. No published theorem changed. `compile_correct'` is
loaded with a clean tag in `a3-0006`; `forge_compileCorrectControl` is
in the closure.

## 5. Concrete nonzero slide: satisfiability (`forge_refundSlideSat`, `sat-0002`)

Slide `0x4000`. Witness: a CONSTRUCTED model state. Memory `sat_mem_sl`
holds the file image at `0x100004000`, the bitmaps at `0x100030018`,
the three slots at `0x100030000`; `h = 0x200000000`, `stk =
0x200010000`, `e = 0x200020000`; `PC = 0x100008000`.

- `refund_entry_pre_sl_witness_0x4000`: the state satisfies the entry
  premise.
- `refund_entry_sl_premises_satisfiable_at_0x4000`:
  `∃s h stk e envmc.` premises 1–3 of section 4 at `sl = 0x4000w`.
- `slide_0x4000_witness_reaches_installed_state_modulo_environment`:
  for that state, `∃ms. arm8_run 27 s = SOME ms ∧ ms.PC = 0x1000080D0w
  ∧ (refund_installed_rest2 … ⇒ refund_installed_no_handler …)`.

Limits. This shows that premises 1–3 are not contradictory at a
nonzero slide. It is not a native execution witness. It is not
evidence that macOS produces this state. Premise 4 is not shown
satisfiable at a slide in this run (the slide form of `refund_env_ok`
is S4).

## 6. Negative controls (all passed)

| Control | Theorem or check |
| --- | --- |
| Heap on the relocated code | `heap_on_relocated_code_rejected` |
| Changed code byte at the relocated address | `image_at_another_slide_is_not_preserved_evidence` |
| Two slides for one end state | `end_state_fixes_one_slide` |
| Code domain of another slide | `wrong_slide_domain_does_not_hold_the_code`; `slide_zero_domain_misses_relocated_code` |
| Unrelocated machine record at a nonzero slide | `unrelocated_record_rejected_at_nonzero_slide` |
| Heap on the relocated halt stub | `heap_on_relocated_halt_stub_rejected` |
| Code start outside the domain | `code_start_outside_domain_rejected_sl` (stored for every word width; see section 8) |
| Program-address mismatch | `prog_addresses_mismatch_rejected_sl` |
| Witness is not a slide-0 entry, not a slide-`0x8000` entry | `sat_sl_witness_is_not_a_slide_zero_entry`; `sat_sl_witness_is_not_an_entry_for_slide_0x8000` |
| Heap on the relocated image | `sat_sl_heap_on_relocated_image_rejected` |
| Frame inside the header | header byte 0 is written (value `0x18` for every page-aligned slide); header byte 8 is not shown unchanged |
| Checker controls | four in `imp-0002` (wrong alignment; missing heap premise; missing `rest2` premise; missing name) |

Preserved: the U390 and U391 slide-0 theorems are loaded and compared
term for term (`CONTROL_OK` in `d3-0003`, `a3-0006`). All U405 controls
are stored theorems of unchanged theories; the repeats reproduce the
objects byte for byte.

One author error was caught by HOL: in `a3-0001` I wrote a control with
a false address claim (`0x1000080D0w ∉ refund_code_dm`). The proof
failed. I corrected the address; I did not weaken a theorem.

## 7. Closure

540 nodes at `forge_refundSlideSat`. Axioms: `bool.SELECT_AX`,
`INFINITY_AX`, `ETA_AX`, `BOOL_CASES_AX` only. All tags `DISK_THM`
only. The `mk_thm` placeholder of the lemma wrapper is used only after
a failed lemma; each such run raised `Fail` before export, and the
final runs have 0 failed lemmas.

## 8. Actual exits

| Case | Exit | Note |
| --- | --- | --- |
| `s1-repeat` | 0 | objects identical |
| `s2-repeat` | 0 | objects identical |
| `f1-0001` | 0 | frame at a slide |
| `d3-0001`, `d3-0002` | 1, 1 | authoring (tactics) |
| `d3-0003` | 0 | domains, asm state, end state |
| `a3-0001` | 1 | two controls: one tactic; one false statement of mine |
| `a3-0002`, `a3-0003` | 1, 1 | authoring (one control) |
| `a3-0004` | 1 | MEMORY: Poly/ML "Run out of store" after 18 s |
| `a3-0005` | 1 | authoring: the control goal had a general word width |
| `a3-0006` | 0 | 23 + 5 clauses; entry summary |
| `sat` (first try), `sat-0002` (first try) | 3, 3 | runner RESOURCE GUARD refused: disk 2.98 and 1.87 GiB free; no HOL process started |
| `sat-0001` | 1 | authoring (type annotation) |
| `sat-0002` | 0 | witness at `0x4000` |
| `imp-0001` | 1 | check-script defect (nested conjunction) |
| `imp-0002` | 0 | 34 imported, 0 mismatches |
| Repeats of the U407 cases; S4; S5; S6; clean replay; independent replay; native run | NOT RUN | |

Failures by class. Authoring: as listed. Tool: none. Memory: one
(`a3-0004`). Resource guard: two refusals; I did not bypass the guard.
Logical: one false control statement by the author, rejected. No stored
statement was found wrong.

Open small item: `code_start_outside_domain_rejected_sl` is stored for
`sl : α word` (every word width). It is true and more general than
intended. It is a control only.

Resource note. Free disk on the data volume moved between 1.9 and 9.3
GiB during the run; swap grew from 8 to about 13 GiB. The run directory
is 1.8 MB. The cause is outside this work. Further heavy runs need
free disk first.

## 9. Remaining obligations

- **S4.** `ffi_interfer_ok_iff_contract` and `refund_env_ok` at the
  base `sl + 0x1000040D0w`. The contract's stub addresses become the
  six relocated addresses of section 3.3. Then premise 4 can be shown
  satisfiable for the abstract environment at a slide.
- **S5.** Composition with `refund_mc_is_arm8`,
  `refund_u298_exclusion_valid_request` and
  `refund_behavior_valid_request_no_handler` (base as a parameter) to
  get the slide form of `refund_profile_a_slide0`.
- **S6.** Regression: the slide theorem at `sl = 0w` gives the U404
  theorem.
- Unchanged M1 blockers: profile approval; A8 review (18 rows NOT
  REVIEWED); `refund_env_ok` for a real environment (probably false as
  stated; U405 proposal L1–L3 needs a refinement proof, not run);
  joint satisfiability with a concrete file system; clean and
  independent replay; no theorem about the real loader.

## 10. Branch scan (read-only; no change made)

Requested as a watch item. Scan of tracked files at `HEAD`
(`7ef2801a`) of the backup branch:

- Home-directory paths: 4,301 files, 210,747 lines (3,688 files under
  `proposals/`, 608 under `results/`, 5 top-level documents). They
  contain the local user name.
- Token patterns (GitHub, Anthropic, OpenAI-style, AWS, Slack, bearer,
  private-key headers): 0 files.
- Private network addresses in `proposals/`: 0 files.
- E-mail addresses: present. Largest group: one domain in 32 files
  (28 under `proposals/refund-executable-feasibility`, 4 under
  `results/stage9`). Commit author e-mail is in the git history.

A scrub needs new commits and, for history, a rewrite and a force
push. Neither is authorized. Decision needed from the owner: scrub
scope (working tree only, or history) and the replacement text. This
packet's records also contain absolute paths; it is not committed.
