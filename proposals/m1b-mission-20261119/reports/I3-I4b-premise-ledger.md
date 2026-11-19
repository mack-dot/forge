# Steps I.3 and I.4b: premise ledger of the final theorem and compiler obligations (W3, Opus, read-only)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

W3 (premise-ledger), steps I.3 and I.4b. I worked read-only and changed no repository file. My notes are in <session scratch folder>/m1b/W3/notes.md.

Root path for the records below: R = proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/

## A. Final statements (quoted exactly from the stored logs)

The `.sig` files list theorem NAMES only. The statements come from the stdout logs.

**Correction to the brief:** the name `refund_profile_a_sl_all_premises_satisfiable_at_0x4000` is in theory `forge_refundInputSat` (R/final-cases/fs-r4-0001). It is not in `forge_refundSlideProfileA`. The `forge_refundSlideProfileA` theory has `refund_profile_a_sl_machine_premises_satisfiable_at_0x4000` instead.

**refund_profile_a_sl** (R/final-cases/e4-0001/stdout.log, lines 240–265):
```
⊢ refund_entry_pre_sl sl s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ∧
  refund_heap_clear_sl sl h e ∧
  envmc.prog_addresses = refund_mem_dm_sl sl h e ∧
  refund_env_ok_sl sl envmc ∧
  stdin_content fs =
  SOME
    (explode
       (sexp_to_string
          (refund_request charge request original remaining enabled opened
             candidate amount reason))) ∧ wfcl cl ∧ wfFS fs ∧ STD_streams fs ⇒
  ∃ms.
    (arm8_run 27 s = SOME ms ∧ ms.PC = sl + 0x1000040D0w) ∧
    (∀j ms' ffi'.
       evaluate (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi ext cl fs) j
         ms = (TimeOut,ms',ffi') ⇒
       (refund_mc (sl + 0x1000040D0w) envmc).target.get_pc ms' ≠
       (refund_mc (sl + 0x1000040D0w) envmc).install_pc) ∧
    ∃io_events.
      machine_sem (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi ext cl fs)
        ms ⊆ extend_with_resource_limit {Terminate Success io_events} ∧
      extract_fs ext (cl,fs) io_events =
      SOME
        (add_stdout (fastForwardFD fs 0)
           (refund_render_fields
              (refund_fields charge request original remaining enabled opened
                 candidate amount reason)))
```

**refund_profile_a_sl_every_machine_run** (same log, lines 298–331). The premises are identical to the theorem above. The conclusion is:
```
  ∃ms.
    (arm8_run 27 s = SOME ms ∧ ms.PC = sl + 0x1000040D0w) ∧
    (∀b. machine_sem (refund_mc (sl + 0x1000040D0w) envmc)
           (basis_ffi ext cl fs) ms b ⇒
         (∃io.
            b = Terminate Success io ∧
            extract_fs ext (cl,fs) io =
            SOME
              (add_stdout (fastForwardFD fs 0)
                 (refund_render_fields
                    (refund_fields charge request original remaining enabled
                       opened candidate amount reason)))) ∨
         ∃io io'.
           b = Terminate Resource_limit_hit io' ∧ io' ≼ io ∧
           extract_fs ext (cl,fs) io =
           SOME
             (add_stdout (fastForwardFD fs 0)
                (refund_render_fields
                   (refund_fields charge request original remaining enabled
                      opened candidate amount reason)))) ∧
    (∃b. machine_sem (refund_mc (sl + 0x1000040D0w) envmc)
           (basis_ffi ext cl fs) ms b) ∧
    ¬machine_sem (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi ext cl fs)
      ms Fail
```

**refund_profile_a_sl_all_premises_satisfiable_at_0x4000** (R/final-cases/fs-r4-0001/stdout.log):
```
⊢ ∃s h stk e envmc fs cl.
    refund_entry_pre_sl 16384w s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧
    8192w ≤₊ e − h ∧ refund_heap_clear_sl 16384w h e ∧
    envmc.prog_addresses = refund_mem_dm_sl 16384w h e ∧
    refund_env_ok_sl 16384w envmc ∧
    stdin_content fs =
    SOME
      (explode
         (sexp_to_string
            (refund_request charge request original remaining enabled opened
               candidate amount reason))) ∧ wfcl cl ∧ wfFS fs ∧
    STD_streams fs
```

The same log has a companion theorem, `refund_profile_a_sl_conclusion_holds_for_a_constructed_model_state_at_0x4000`. Its witness values are:
- `s` with `MEM := sat_mem_sl` and `PC := 0x100008000w`
- `envmc = refund_abs_env <|prog_addresses := refund_mem_dm_sl 16384w 0x200000000w 0x200020000w|>`
- `cl = [«refund»]`
- `fs = sat_fs (…)` with `numchars := LREPEAT [1]`

Definitions behind the premises:
- **`slide_ok`** (R/logs/C65-s2-0003.stdout.log line 20): `slide_ok sl ⇔ aligned 12 sl ∧ sl ≤₊ 0xFFFFFFFEFFFCF0CFw`.
- **`refund_entry_pre_sl`** (C65, lines 29–37): EL0, no exception, `¬E0E`, `¬SA0`, `¬TBI0`, `¬TBI1`, `s.PC = sl + 0x100004000w` (cml_main), the three data slots hold h / stk / e, `aligned 3 h`, the 40-byte header separation, `refund_image_mem sl s.MEM` and `slide_ok sl`.
- **`refund_image_mem`** (C42, after line 60): it uses only `TAKE 163840 refund_file` and `TAKE 20248 (DROP 180248 refund_file)`.
- **`refund_file`**: defined from bytes read with BinIO (`results/refund-loader-memory-local-20261115/attempt-0001/image-0001/proof.sml` lines 36 and 44). The SHA-256 round trip is done by the runner wrapper, outside HOL.
- **`refund_env_ok_sl`** (e4 log, lines 151–156): `interference_ok envmc.next_interfer (arm8_target.proj envmc.prog_addresses) ∧ refund_ffi_contract_at (sl + 0x1000040D0w) envmc.prog_addresses envmc.ffi_interfer`.

## B. Premise ledger: the 11 conjuncts of refund_profile_a_sl

The import check confirms the count (CHK log: `PREMISE_CONJUNCTS 11`).

Class key: (1) discharged by a stored theorem; (2) an approved Profile A assumption; (3) covered by no owner decision; (4) shown to hold only for one constructed state. Every premise is also class (4) through the joint witness at slide 0x4000.

| # | Exact text | Plain meaning | Class |
|---|---|---|---|
| P1 | `refund_entry_pre_sl sl s h stk e` | The L3 state at cml_main: EL0 flags, PC at sl+0x100004000, heap/stack/end slots, image bytes mapped at slide sl, `slide_ok sl` | (2) Q3a, the entry state. The image part depends on `refund_file`, which is Q3c (conditional, see E). Also (4) |
| P2 | `aligned 3 e` | the heap end is 8-byte aligned | (2) Q3a. (4) |
| P3 | `h ≤₊ e` | the heap start is at or below the heap end | (2) Q3a. (4) |
| P4 | `8192w ≤₊ e − h` | the heap plus stack is at least 8 KiB | (2) Q3a. (4). See F3 |
| P5 | `refund_heap_clear_sl sl h e` | the heap does not overlap the image range 0x100000000..0x100030F30 shifted by sl | (2) Q3a. (4) |
| P6 | `envmc.prog_addresses = refund_mem_dm_sl sl h e` | the model memory domain is code ∪ heap ∪ bitmaps. This is a choice of model record, not a fact about the world | (2) A2 text under Q3a. (4) |
| P7 | `refund_env_ok_sl sl envmc` | conjunct 1, `interference_ok`: nothing changes the projected state between steps. Conjunct 2, `refund_ffi_contract_at`: each FFI call returns to x30, writes only the output buffer, and keeps x19–x25, x27, x28 | Conjunct 2: (2) Q3b, in formal form. Conjunct 1: (2), but only through Q1 approving Profile A row 9. Q3b does not cover it. **Flag:** the premise bundles two assumptions, and Q3b speaks of "ONE" assumption. U393/U409 record that it is "probably false for the real C code" (an analysis, not a theorem). The HOL text has no statement that links the real process to this model. Also (4): the only witness is `refund_abs_env` |
| P8 | `stdin_content fs = SOME (explode (sexp_to_string (refund_request …)))` | stdin is present, at offset 0, and holds exactly the canonical nine-field text | (2) Q1 (row 5) and Q5. Absent stdin and other spellings are outside the theorem. (4) via `sat_fs` |
| P9 | `wfcl cl` | the command line is well formed | (2) Q1 row 4. Proved for `[«refund»]` (`sat_cl_wfcl`) |
| P10 | `wfFS fs` | the file-system model is well formed. `numchars` must be live: `sat_fs_wfFS` needed `live_numchars_LREPEAT_one` | (2) Q1 row 4. (4) |
| P11 | `STD_streams fs` | fds 0, 1 and 2 are the standard streams | (2) Q1 row 4. (4) |

Items the brief asked about that are NOT premises of the final theorem:

| Item | Where it went | Class |
|---|---|---|
| `backend_config_ok`, `mc_conf_ok`, `mc_init_ok`, `opt_eval_config_wf` | discharged inside scripts (see D) | (1) |
| `installed` / `good_init_state` | derived. `installed_modulo_install_handler` (C31) replaces `install_interfer_ok` by `T` (`REMOVED_CLAUSES 1`). It is discharged constructively by `arm8_install_handler_ok` and `install_exclusion_suffices`, in theory `forge_refundInstallHandler` | (1) |
| `start_pc_ok` | derived: CLAUSE2_PROVED 1 in C68 (forge_refundSlideInstalled) | (1) |
| The 23 + 5 other installed-state clauses | derived in C68 | (1) |
| `interference_ok`, `ffi_interfer_ok` | become P7, by `refund_env_ok_sl_iff_installed_residual` and `ffi_interfer_ok_iff_contract_sl` (e4) | see P7 |
| `is_arm8_machine_config` | `refund_mc_is_arm8` (C39) | (1) |
| `refund_image_mem` | inside P1 | |
| `slide_ok` | inside P1 | |
| `extend_with_resource_limit` | appears in the conclusion, not as a premise. A resource bound is not assumed | |
| `SCTLR_EL1.A` clear (U398) | not in the closure of the final theorem | |

## C. Conclusion check

1. The output equation is in the slide-generic theorems themselves: `refund_profile_a_sl` and `_every_machine_run`, with general `sl` and `envmc`. It is not only in a slide-0 theorem. The e4 log records `CONTROL_OK the output term of the slide theorem is syntactically the U387 output term`.
2. **Prefix output:** yes, a prefix is allowed. `every_machine_run` allows `b = Terminate Resource_limit_hit io' ∧ io' ≼ io`. Here `io'` can be any prefix of the event list, including the empty list. The equation fixes the full final file system: stdin fast-forwarded and stdout appended. So on Success it also says that nothing is written to stderr or to other files.
3. **Exit code:** no term names the process exit status. `Terminate Success` is the outcome of the model machine at `halt_pc` (sl+0x1000040C0). The real exit path through the C run-time is not modelled.
4. **Non-canonical input:** the theorem says nothing about it. P8 fixes the exact canonical text, so any other input is outside the theorem. U388 has theorems for malformed text (source non-Fail for every text), but they are not composed into the final theorem.
5. **Two conclusions hold for every slide and every environment that meets the premises:** installer exclusion (`get_pc ms' ≠ install_pc` for every TimeOut prefix), and the 27-step `arm8_run` from cml_main to the CakeML entry.

## D. Compiler configuration, initialization and slide obligations

**U402's line claims are verified.** The script files are byte-identical on `origin/backup/forge-local-2026-11-11:proposals/refund-executable-feasibility/m1-compile-correct-20261114/records/cc/` and in the local `results/refund-compile-correct-local-20261114/attempt-0001/`.
- `real-0004.sml`:
  - line 89 `mc_conf_ok mc2` by `arm8_machine_config_ok`
  - line 90 `mc_init_ok arm8_config ^cfg mc2` by `arm8_init_ok`
  - line 91 `backend_config_ok arm8_config ^cfg` by `arm8_backend_config_ok`
  - line 67 fetches `backendProof.compile_correct`
- `source-0006.sml`:
  - line 57 `mc_conf_ok`
  - line 58 `mc_init_ok`
  - line 59 `backend_config_ok`
  - lines 60–61 `lab_facts` via `fs [add_eval_state_def, opt_eval_config_wf_def]`, with `ev` instantiated to `NONE` at line 33
- The task's "58–61" range is right. U402 omits `mc_conf_ok` (lines 57 and 89).
- Both scripts run a `tags` check (lines 8–10): no hypotheses, no axioms, oracles only `DISK_THM`.

**Replay of 2026-11-18:** the discharge was re-run in phase 1.
- `R/summary.json`: C32-source-0006 (forge_refundExclusionSource) REPLAYED, actual_exit 0. C34-real-0004 (forge_refundExclusionReal) REPLAYED, actual_exit 0.
- `R/comparison.json`: sig, sml and dat of both are "equal".
- This was the same machine with rebuilt pinned tools. It was not a clean replay and not an independent one.
- **Inconsistency:** REVIEW_PACKET.md section 4 says "Not run again since" for these premises. That contradicts the M1R-1 records, unless it means "not in a clean replay".

**Initialization and installed state:**
- `good_init_state` and the `installed` clauses are derived in C68 (23 + 5 clauses), C31 (install handler) and C34.
- Only P7 is left as a residual.
- All of these theories were replayed with exit 0 and are equal: C31, C39, C42, C65, C68, C70, C71, C72 import check, FS, CHK.

**Slide:** S1–S6 are proved for every `sl` with `slide_ok sl`, in the model.

**Still open:**
- joint satisfiability at any slide other than 0x4000
- whether a real macOS slide meets `slide_ok` (an assumption; U404 used only static otool)
- the 158 recorded controls, repeats and import checks (not run per M1R-2)
- a clean replay
- an independent replay

## E. Owner decisions mapped to the ledger

| Decision | Premise or ledger line | State |
|---|---|---|
| Q1 Profile A | P8–P11 (rows 4–5); P7 conjunct 1 (row 9); model choices `basis_ffi` (row 1), L3 (row 10), trusted base (row 13) | rows 1, 3, 10 and 13 are not premises. They need ledger lines |
| Q2 read errors | not a premise. It holds implicitly through the `basis_ffi` model (U403 A1 cites `stdin_ffi_read_status_zero`, U327) | **no ledger line in the theorem.** The fail-closed rule is a caller requirement, not a theorem |
| Q3a entry state | P1–P6 | covered. It assumes everything before cml_main (dyld, `_main`, C run-time) and that the real slide meets `slide_ok` |
| Q3b C/FFI simulation | P7 conjunct 2 is the formal part | **The bridge "the real process refines `refund_mc … envmc` for some envmc with `refund_env_ok_sl`" exists only informally** (U403 A3; TCB item 4). It is not named or written in HOL. The halt/exit path through C is also unstated |
| Q3c file reader and offset tool | not a premise. Hidden inside P1 through the constant `refund_file` (BinIO read; SHA round trip outside HOL; Python offsets) | **Not a premise and no ledger line.** The second, independent extraction is NOT DONE. This is an unvalidated dependency that Q3c requires us to report |
| Q4 Dafny ↔ HOL link | none. The conclusion speaks of `refund_fields` / `refund_render_fields`, not R1–R5 | open. Blocks M1-B. The 18 rows are NOT REVIEWED |
| Q5 absent stdin | already excluded by P8 (`= SOME …`) | the fail-closed rule at the operational boundary is a caller requirement, not a theorem. No ledger line |
| Q6 replays | — | the 158 cases were started per U471. Result not determined by me |

## F. Ways the theorem may be vacuous or weaker than it reads

1. **P7 may be false for real runs.** U404, U409 and REVIEW_PACKET.md section 4 say `refund_env_ok_sl` is "probably false for the real C code at every state". The only witness is `refund_abs_env` (fs-r4 log), so the theorem may say nothing about the real process without the unwritten Q3b bridge.
2. **The joint witness covers one constructed state at one slide (0x4000)** (`…all_premises_satisfiable_at_0x4000`; M1R-1: "not every permitted slide"). For other slides the premises are not shown satisfiable. The state is constructed (`sat_mem_sl`, `sat_fs` with `numchars LREPEAT [1]`), not observed.
3. **Success is never guaranteed.** The `every_machine_run` disjunction allows `Terminate Resource_limit_hit io'` with `io' ≼ io`, including empty output. P4 requires only 8 KiB of heap, and no theorem shows the heap is large enough to reach Success. "Never Fail, some behaviour exists" is proved; termination with full output is not.
4. **`refund_profile_a_sl` alone cannot rule out an empty behaviour set**, because its conclusion is an inclusion `⊆`. Only `_every_machine_run` adds `∃b. machine_sem … b`.
5. **The input domain is canonical text only (P8).** Wave Gate 1 showed that the real reader accepts `040`, `+40` and `"40"` (REVIEW_PACKET row 5 / row 18). Those runs are outside the theorem.
6. **The binary identity of the image is outside HOL.** `refund_image_mem` binds only two slices of `refund_file`, and the file-to-SHA link is checked outside HOL (Q3c).
7. **The conclusion is about the output of `refund_fields`, not the approved R1–R5 contract (Q4).** Exit status is not covered (C3).
8. **Free `ext` and the nine field variables are implicitly universal.** That makes the statement stronger, not vacuous. `NONVACUITY_FREE_VARS` in the fs-r4 log lists them.

## Not found / not determined

- **The name `refund_profile_a_sl_all_premises_satisfiable_at_0x4000` in forge_refundSlideProfileA:** not found there. It exists in forge_refundInputSat.
- **A document that names P7 (or a bridge statement) as "the" Q3b assumption:** not found.
- **A trust-boundary ledger after the owner's decisions** that lists Q2, the Q3b bridge, Q3c, L3, `basis_ffi`, the exit path and the fail-closed caller rules: not found. The closest are U401 `M1_TRUSTED_COMPUTING_BASE.md` and U403 A1–A10, both written before the decisions.
- **Whether a real macOS slide always meets `slide_ok`:** not determined.
- **The exact premise list of `backendProof.compile_correct` in the pinned CakeML** (for example, whether `opt_eval_config_wf` is in it or only in `compile_correct_lab_facts`): not determined. I did not read the upstream source.
- **The result of the 158-case replay started per U471:** not determined.
- **The full text of `wfFS`:** not read. I inferred the live-numchars requirement from `sat_fs_wfFS` needing `live_numchars_LREPEAT_one`.

## Tracker

| step | status | evidence or blocker |
|---|---|---|
| I.3 (final statements and premise ledger) | REPORTED | R/final-cases/e4-0001/stdout.log lines 240–331; R/final-cases/fs-r4-0001/stdout.log; R/logs/C65, C42, C34, C39, C31, C68, C35 stdout logs; 11 premises tabled |
| I.4b (compiler/init/slide discharge, decision map, vacuity) | REPORTED | real-0004.sml lines 89–91 and source-0006.sml lines 57–61 (backup branch, m1-compile-correct-20261114/records/cc); R/summary.json C32 and C34 exit 0, comparison equal; gaps: Q2, Q3b bridge, Q3c and the fail-closed rules have no ledger line; P7 conjunct 1 is covered only via Q1 |

