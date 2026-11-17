# U388: source non-Fail for every present standard input; concrete ARMv8 machine record; 27 machine steps of `cml_main` proved from an explicit pre-state

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted. Nothing committed.
Local results: same machine, same agent, cached parents. No clean replay. No independent replay.

Run directories: `results/refund-reject-nonfail-local-20261115/attempt-0001` (CakeML context),
`results/refund-startup-step-local-20261115/attempt-0001` (ARMv8 step context of U316).
All U386 and U387 theories are imported unchanged. The published `compile_correct'` control is re-checked in `import-0001`.

## 1. Commands and actual exits

CakeML context: `python3 -I -B run_case.py <case> <source> <deps…>` through `go.sh`, `go-mc.sh`, `go-imp.sh`.
ARMv8 context: `python3 -I -B run_arm8_case.py <case> <source> [<theory-case> <theory>]`.
Exact argument vectors: `<case>/command.json`. Full list: `records/exits.json`.

| Case | Exit | Kind |
| --- | --- | --- |
| `make_rej.py`, first call | 1 | tool: my line check failed; no HOL run |
| `reject-0001` | 1 | TOOL: libraries not loaded in the heap; no proof step ran |
| `reject-0002`, `0003`, `0005`–`0008` | 1 | authoring (names, opens, ML) |
| `reject-0004` | 0 | exploration: three lifting lemmas |
| `reject-0009` | 0 | reject path, all present input, compositions, 98 s |
| `steps-0001`, `dbg-0001` | 0 | step-theorem shapes; diagnostic |
| `cml-0001`–`0009`, `cml-0011` | 1 | authoring (ML and conversion errors; see `exits.json`) |
| `cml-0010` | 0 | first full composition of 27 steps |
| `cml-0012` | 0 | final step theory, 13 s |
| `sat-0001` | 0 | non-vacuity of the pre-state |
| `mc-0001` | 0 | machine record, absent input, bridge |
| `import-0001` | 0 | 29 exact statements, 511 closure nodes, controls |
| `reject-repeat`, `mc-repeat`, `cml-repeat`, `sat-repeat` | 0 each | repeats |

Tool failures: `reject-0001` and the generator check. Memory failures: none. Logical failures: none.
Repeats: `forge_refundStartupBridge`, `forge_refundCmlMainStep`, `forge_refundCmlMainSat` exports are byte-identical.
`forge_refundRejectNonFail`: `.sig` identical; `.dat` identical after the case directory name is replaced and white space is normalized;
`.sml` differs only in the recorded hash of that `.dat` (`Theorem` syntax records the source path, U384).

## 2. Source non-Fail: input coverage

`forge_refundRejectNonFail` (`reject-0009`; tag `DISK_THM` only; no hypotheses). `bffi` is `basis_ffi ext cl fs`.

New general lemmas (the published library covers normal return only):

- `call_main_exn1`, `call_main_exn2`: `Decls env1 st1 prog env2 st2`, `lookup_var fname env2 = SOME mainv`,
  `app (proj1,proj2) mainv [Conv NONE []] P (POSTe exn. Q exn)`, a heap split with `P` ⇒
  `sem_satisfies (semantics_dec_list st1 env1 (SNOC <main call> prog)) (λb. ∃io. b = Terminate Success io)`.
  For every pointer-equality oracle. Adapted from published `call_main_thm1`, `call_main_thm2`.
- `exn_spec_IMP`: the shape of published `whole_prog_spec_IMP`, for an exception post-condition.
- Published local lemmas replayed unchanged, with line and hash checks in `make_rej.py`:
  `cfMainScript.sml` lines 213–258 (SHA256 prefix `504c7b47`), `basis_ffiScript.sml` lines 861–961 (`74862cf9`).

Program link: the pipeline of published `prove_sem_thm` is re-run with the stored `refund_prog_def` in place of a new definition.
The run checks that the declaration list is the stored `refund_prog` (`CODE_IDENTICAL_TO_refund_prog true`, twice).

| Theorem | Premises | Conclusion |
| --- | --- | --- |
| `refund_reject_semantics` | `stdin_content fs = SOME text`, `refund_run_wire (implode text) = INL err`, `wfcl cl`, `wfFS fs`, `STD_streams fs` | `sem_satisfies (semantics_dec_list (init_state bffi) init_env refund_prog) (λb. ∃io. b = Terminate Success io)` |
| `refund_source_nonfail_reject` | same | `¬semantics_prog (FST (THE (prim_sem_env bffi))) (SND (THE (prim_sem_env bffi))) refund_prog Fail` |
| `refund_accept_semantics` | same with `= INR output` | as the first row (from stored `refund_whole_prog_spec` and published `whole_prog_spec_IMP`) |
| `refund_source_nonfail_stdin` | `stdin_content fs = SOME text`, `wfcl cl`, `wfFS fs`, `STD_streams fs` | source non-Fail, U386 premise form (`PREMISE_FORM_IDENTICAL true`) |

Stored basis: `forge_refundStdioProg.refund_main_error` (exception post-condition `Fail_exn err`), `refund_whole_prog_spec`,
`prog_syntax_ok refund_prog`. No compilation or execution fact is used.

Coverage classes:

| Input class | Class | Evidence |
| --- | --- | --- |
| Valid request | PROVED (U387; again here) | `refund_source_nonfail`, `refund_accept_semantics` |
| Rejected request (`INL err`) | PROVED | `refund_source_nonfail_reject` |
| Any text at standard-input offset 0 | PROVED | `refund_source_nonfail_stdin` (case split on `refund_run_wire`) |
| Absent input (`stdin_content fs = NONE`) with `STD_streams fs` | OPEN, characterised | `stdin_absent_characterised`: it is exactly a non-zero standard-input offset. No specification of `refund_main` exists there |
| File system not `wfFS` or not `STD_streams`; `wfcl` false | OPEN | no stored specification |
| General `ffi` (not `basis_ffi`) | OPEN | type-soundness route not attempted |

The premises `wfcl`, `wfFS`, `STD_streams`, the offset-0 condition and the FFI model `basis_ffi` are ASSUMED.
No counterexample was found or constructed for an open class. None is shown absent.
The proved class is not extended beyond the table.

## 3. Concrete machine record

`forge_refundStartupBridge` (`mc-0001`):

- `refund_mc base0 envmc = arm8_fix (envmc with <| ffi_names := THE refund_lab_conf2.ffi_names; ffi_entry_pcs := GENLIST (λi. base0 − n2w ((3 + i) * ffi_offset)) (LENGTH …); halt_pc := base0 − n2w ffi_offset; install_pc := base0 − n2w (2 * ffi_offset); mmio_info := []; shared_addresses := ∅ |>)`.
- `refund_mc_is_arm8`: `is_arm8_machine_config (refund_mc base0 envmc)`. FACT, no premise. The six field equations hold by construction.
- `refund_mc_fields`: `refund_lab_conf2.ffi_names = SOME (refund_mc base0 envmc).ffi_names`; target, halt and install addresses,
  `mmio_info = []`, `shared_addresses = ∅`; `mmio_pcs_min_index` of its names is their length; program addresses and the three
  interference functions are those of `envmc`.
- `refund_mc_u298_exclusion_stdin`, `refund_mc_behavior_stdin_no_handler`: the final theorems at this record.
  Premises: `refund_installed_no_handler (refund_mc base0 envmc) ms cbspace data_sp` and the four input premises.
  `is_arm8_machine_config` is no longer a premise.

Limits. `base0` and `envmc` are parameters: program addresses and the interference functions are physical and stay unspecified.
The layout of the entry stubs (16-byte blocks below `cake_main`) agrees with `refund.S` by text inspection only.
The installer handler is not fixed: the exclusion holds for every handler.

## 4. `cml_main`: machine steps

Artifact: linked executable `results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund`
(SHA256 `b8ed5ec2…39007bb8`), built from `refund.S` (SHA256 `4c750e4f…5c3a1757`). Never executed (`native_execution: NOT_RUN`).
The 27 instruction words at `0x100004000` were read from the file and compared with the script by program (`WORDS_MATCH_BINARY True`).
Link addresses (symbol table): `cake_main` `0x1000040D0`; `cake_codebuffer_begin` `0x100023E54` = `cake_main` + 130436;
`cake_codebuffer_end` `0x100024000`, so `cbspace` = 428; `cake_bitmaps` `0x10002C018`;
`cake_bitmaps_buffer_begin` = `_end` = `0x100030F30` = `cake_bitmaps` + 20248, so `data_sp` = 0.

`forge_refundCmlMainStep` (`cml-0012`; model: published L3 ARMv8 `NextStateARM8`, step theorems from `arm8_stepLib` for each exact word):

- `arm8_run n s`: `n` applications of `NextStateARM8`.
- `cml_main_pre s h stk e`: user mode, no pending exception, the four control bits of the step theorems,
  `s.PC = 0x100004000w`, the 108 code bytes, `mem_dword s.MEM 0x10002C000w = h` (`cml_heap`), `… 0x10002C008w = stk`,
  `… 0x10002C010w = e` (`cml_stackend`), `aligned 3 h`, and: the 40 bytes at `h` do not meet `[0x100004000, 0x10002C018)`.
- `cml_main_run`: `cml_main_pre s h stk e ⇒ ∃s1. arm8_run 27 s = SOME s1 ∧ s1.PC = 0x1000040D0w ∧ s1.REG 0w = 0x1000040D0w ∧ s1.REG 1w = h ∧ s1.REG 2w = stk ∧ s1.REG 3w = e ∧ mem_dword s1.MEM h = 0x10002C018w ∧ mem_dword s1.MEM (h + 8w) = 0x100030F30w ∧ mem_dword s1.MEM (h + 16w) = 0x100030F30w ∧ mem_dword s1.MEM (h + 24w) = 0x100023E54w ∧ mem_dword s1.MEM (h + 32w) = 0x100024000w`.
- `cml_main_startup_conditions`: with `aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h`, the end state satisfies `cml_main_post`:
  the ten conditions of U387 in ARMv8-state form.
- Controls: `cml_main_wrong_target_refuted`; a changed instruction word is rejected by the fetch hypotheses;
  `cml_main_pre_satisfiable` (`sat-0001`): one explicit state satisfies the pre-state and the three conditions on `e`.

Bridge (`mc-0001`):

- `refund_startup_from_cml_main`: `is_arm8_machine_config mc0 ∧ target_state_rel mc0.target t ms ∧ target_configured t mc0 ∧ cml_main_post ms ⇒ refund_startup_clause mc0 ms t (λa. Word (mem_dword ms.MEM a)) 0x10002C018w 428 0`.
- `refund_startup_established`: `cml_main_pre s h stk e ∧ aligned 3 e ∧ h ≤₊ e ∧ 8192w ≤₊ e − h ⇒ ∃ms. arm8_run 27 s = SOME ms ∧ ms.PC = 0x1000040D0w ∧ ∀mc0 t. is_arm8_machine_config mc0 ∧ target_state_rel mc0.target t ms ∧ target_configured t mc0 ⇒ refund_startup_clause mc0 ms t (λa. Word (mem_dword ms.MEM a)) 0x10002C018w 428 0`.

Start-up conditions, by class:

| # | Condition | Class |
| --- | --- | --- |
| 1 | pc aligned | PROVED from the pre-state (end pc is `0x1000040D0`) |
| 6–10 | five header words | PROVED from the pre-state: written by the 27 steps |
| 2 | register 1 aligned | from `aligned 3 h`, a pre-state premise (value at `cml_heap`) |
| 3, 4, 5 | register 3 aligned; order; distance | ASSUMED about `e` and `h` (values the C run-time stored) |

What this is not:

- The pre-state is ASSUMED. Nothing proves that the loader and the C run-time (`main` in `basis_ffi.c`) reach it.
- Addresses are the unslid link addresses. A load slide is not modelled. The instructions are pc-relative, so a slide proof is plausible but NOT RUN.
- The clause is established for the word memory `λa. Word (mem_dword ms.MEM a)`. That this memory satisfies the loader clause is obligation 5.
- The start-up theorem does not give the installed-state predicate. `import-0001` checks that it names neither `installed` nor `refund_installed_no_handler`.
- Symbol addresses were read from the symbol table by tool; only the 27 words were compared with the file bytes.

## 5. Assumption ledger: strongest stored theorems

`refund_mc_behavior_stdin_no_handler`, `refund_mc_u298_exclusion_stdin`:

| Premise | Class |
| --- | --- |
| Source non-Fail | PROVED for every text at standard-input offset 0 |
| `is_arm8_machine_config` | PROVED for `refund_mc base0 envmc` |
| `stdin_content fs = SOME text`, `wfcl`, `wfFS`, `STD_streams`; FFI model `basis_ffi` | ASSUMED |
| `refund_installed_no_handler (refund_mc base0 envmc) ms cbspace data_sp` | ASSUMED |

## 6. Installed-state obligations (re-evaluated; all still OPEN as a whole)

| # | Obligation | State after U388 |
| --- | --- | --- |
| 1 | Machine record | `is_arm8_machine_config`, `ffi_names`, `mmio_info`, halt and install address equations: PROVED for `refund_mc` (the address equations need `get_pc ms = base0`). OPEN: `start_pc_ok` address-set clauses, `target_configured`, the shared-memory size bound |
| 2 | Start-up code | PROVED conditionally: from `cml_main_pre` and three conditions on `e`, at unslid addresses. OPEN: the pre-state itself; load slide |
| 3 | FFI code | OPEN: `ffi_interfer_ok` |
| 4 | Installer | no clause; exclusion holds for every handler |
| 5 | Loader | OPEN: `code_loaded`, `bytes_in_mem`, bitmaps `data`, memory domains, byte/word memory relation for the chosen word memory, code-buffer clauses |
| 6 | Processor and OS | OPEN: `target_state_rel`, `interference_ok` |

Exact code and bitmap identity: the installed-state premise still names the stored `code` and `data`.
The no-handler form and the U298 exclusion for all handlers are unchanged.

## 7. Controls and closure

`import-0001` (exit 0): 29 exact statements (9 of U386, 8 of U387, 12 new), each with tag check; 511 closure nodes;
axioms only `bool.SELECT_AX`, `bool.INFINITY_AX`, `bool.ETA_AX`, `bool.BOOL_CASES_AX`. The seven negative controls of U386
and the U386 and U387 controls pass. New: every stored source non-Fail theorem has a `stdin_content` premise;
the start-up theorem assumes `cml_main_pre` and does not conclude an installed-state predicate; `refund_mc` fixes no installer handler.

## 8. Counterexamples and blockers

No counterexample. No logical blocker. Not done: clean replay; independent replay; native execution.

## 9. Next minimal proof step

1. Loader clause for the same state: from an explicit image predicate (the 130436 code bytes and 2531 bitmap words at their link addresses), prove `bytes_in_mem` for `code` and the bitmap `word_list` clause for the word memory `λa. Word (mem_dword ms.MEM a)`. This joins obligation 5 to the proved start-up state.
2. Load slide: restate `cml_main_pre` with a page-aligned slide and repeat the 27 steps.
3. Pre-state: model the path from process entry to `cml_main` (C run-time), or record it as the permanent assumption.

M1 open. Integration EXIT NOT_ESTABLISHED. end_to_end=false.
