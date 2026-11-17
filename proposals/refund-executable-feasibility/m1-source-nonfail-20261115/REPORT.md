# U387: source non-Fail proved for valid-request input; start-up clause isolated and reduced, not proved

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted. Nothing committed.
Local results: same machine, same agent, cached parents. No clean replay. No independent replay.

Run directory: `results/refund-source-nonfail-local-20261115/attempt-0001`.
Input: the U386 theories, imported unchanged (`deps.txt`). The published
`compile_correct'` control and all earlier theorems are re-read in `import-0001`.

## 1. Commands and actual exits

Each case is `python3 -I -B run_case.py <case> <source> <deps…>` through
`go.sh` (proofs) or `go-imp.sh` (import). The exact argument vector is in
`<case>/command.json`. All cases are in `records/nf/exits.json`.

| Case | Source | Exit | Kind |
| --- | --- | --- | --- |
| `nonfail-0001` | `nonfail-0001.sml` | 1 | authoring (my tactic) |
| `nonfail-0002` | `nonfail-0002.sml` | 1 | authoring (a variable was not instantiated); first three theorems checked |
| `nonfail-0003` | `nonfail-0003.sml` | 0 | source non-Fail and two compositions, 72 s |
| `startup-0001` | `startup-0001.sml` | 1 | authoring (type annotation); first three theorems checked |
| `startup-0002` | `startup-0002.sml` | 0 | start-up clause and machine-record theorems, 54 s |
| `import-0001` | `import-0001.sml` | 0 | 17 exact statements, 507 closure nodes, controls |
| `nonfail-repeat`, `startup-repeat` | same sources | 0, 0 | exports byte-identical (`.sig`, `.sml`, `.dat`) |

Memory failures in this run: none. Swap was 8.3–9.2 GiB used of 9–10 GiB.

## 2. The source non-Fail premise, expanded

Premise of U386: `¬semantics_prog (FST (THE (prim_sem_env ffi))) (SND (THE (prim_sem_env ffi))) refund_prog Fail`.

- Semantics: published `semanticsTheory.semantics_prog`. Checked here as
  `semantics_prog_Fail_expanded`:
  `semantics_prog st env prog Fail ⇔ ∃po k. SND (evaluate_prog_with_clock (st with ptr_eq_oracle := po) env k prog) = Rerr (Rabort Rtype_error)`.
  Fail means: for some pointer-equality oracle and some clock, evaluation
  ends with a run-time type error. An uncaught exception is not Fail.
- Environment: `THE (prim_sem_env ffi) = (init_state ffi, init_env)`
  (published `ml_progTheory.init_state_env_thm`).
- Program: the stored constant `refund_prog` (the full declaration list,
  basis included). `prog_syntax_ok refund_prog` is a stored conjunct of
  `refund_arm8_compiled`.
- Quantification in U386: `ffi` is a free variable of type `'ffi ffi_state`.
  The premise is stated for one FFI state. It was not proved for any.

## 3. Source non-Fail: verdict

PROVED for valid-request input. NOT ESTABLISHED for other input or for a general `ffi`.

`forge_refundSourceNonFail` (`nonfail-0003`, exit 0; tag `DISK_THM` only; no hypotheses):

- `refund_source_nonfail`:
  `stdin_content fs = SOME (explode (sexp_to_string (refund_request charge request original remaining enabled opened candidate amount reason))) ∧ wfcl cl ∧ wfFS fs ∧ STD_streams fs ⇒ ¬semantics_prog (FST (THE (prim_sem_env (basis_ffi ext cl fs)))) (SND (THE (prim_sem_env (basis_ffi ext cl fs)))) refund_prog Fail`.
  The conclusion is the U386 premise at `ffi = basis_ffi ext cl fs` (checked
  in the run: `PREMISE_FORM_IDENTICAL true`).
- Dependency chain: stored `forge_refundWholeProg.refund_semantics`
  (characteristic-formula proof of `refund_main`, 2026-11-04; `sem_satisfies`
  for every pointer-equality oracle) → published
  `ml_progTheory.sem_satisfies_IMP_Terminate` → stored
  `prog_syntax_ok refund_prog` → published `init_state_env_thm`.
- The proof does not use compilation success, execution samples, or any
  machine premise.

Composition with the U386 theorems (no premise added to them):

- `refund_u298_exclusion_valid_request`:
  `is_arm8_machine_config mc0 ∧ refund_installed_no_handler mc0 ms cbspace data_sp ∧ <input premises> ⇒ ∀j ms' ffi'. evaluate mc0 (basis_ffi ext cl fs) j ms = (TimeOut,ms',ffi') ⇒ mc0.target.get_pc ms' ≠ mc0.install_pc`.
- `refund_behavior_valid_request_no_handler`: the same premises give
  `∃io_events. machine_sem mc0 (basis_ffi ext cl fs) ms ⊆ extend_with_resource_limit {Terminate Success io_events} ∧ extract_fs ext (cl,fs) io_events = SOME (add_stdout (fastForwardFD fs 0) (refund_render_fields (refund_fields …)))`.
  This is the U386 form of the older `refund_compiled_behavior`, now without
  the installer-handler clause.

What stays open for source non-Fail:

| Case | State | Smallest additional work |
| --- | --- | --- |
| Valid request on standard input, well-formed file system | PROVED | none |
| Input that `refund_run_wire` rejects (`INL err`) | OPEN | stored `refund_main_error` gives an exception post-condition. The lift to `semantics_prog` (an uncaught exception is not Fail) is not proved. `forge_refundRejectProof` has a lemma but no built theory |
| `stdin_content fs = NONE`, or `wfFS`/`STD_streams` false | OPEN | no stored specification |
| General `ffi` (not `basis_ffi`) | OPEN | published `semantics_type_sound` needs `type_ds` for the full `refund_prog`; not attempted |

Input premises `wfcl cl`, `wfFS fs`, `STD_streams fs` and the standard-input
equation are ASSUMED. Their joint satisfiability was not checked in this run.
No counterexample to non-Fail was found or constructed. None is claimed absent.

## 4. Start-up code clause: verdict

NOT PROVED for any machine state. ISOLATED and REDUCED (machine-checked).

`forge_refundStartupClause` (`startup-0002`, exit 0; tag `DISK_THM` only; no hypotheses):

- `refund_startup_clause mc0 ms t m bitmap_ptr cbspace data_sp`: the eleven
  start-up conjuncts of `refund_installed_no_handler`, selected from the
  stored definition by program (pc equation, pc alignment, two alignment
  clauses, order, distance, five header words).
- `refund_installed_startup` (fidelity):
  `refund_installed_no_handler mc0 ms cbspace data_sp ⇒ ∃t m bitmap_ptr. refund_startup_clause mc0 ms t m bitmap_ptr cbspace data_sp`.
- `arm8_startup_fields`:
  `is_arm8_machine_config mc0 ∧ target_state_rel mc0.target t ms ∧ target_configured t mc0 ⇒ t.regs 1 = ms.REG 1w ∧ t.regs 3 = ms.REG 3w ∧ t.pc = ms.PC ∧ t.align = 2 ∧ mc0.target.get_pc ms = ms.PC`.
- `refund_startup_clause_arm8`: under the same three premises,
  `refund_startup_clause mc0 ms t m bitmap_ptr cbspace data_sp ⇔`
  `3w && ms.PC = 0w ∧ 7w && ms.REG 1w = 0w ∧ 7w && ms.REG 3w = 0w ∧`
  `ms.REG 1w ≤₊ ms.REG 3w ∧ 8192w ≤₊ -1w * ms.REG 1w + ms.REG 3w ∧`
  `m (ms.REG 1w) = Word bitmap_ptr ∧`
  `m (ms.REG 1w + 8w) = Word (bitmap_ptr + 20248w) ∧`
  `m (ms.REG 1w + 16w) = Word (bitmap_ptr + n2w (8 * data_sp) + 20248w) ∧`
  `m (ms.REG 1w + 24w) = Word (ms.PC + 0x1FD84w) ∧`
  `m (ms.REG 1w + 32w) = Word (n2w cbspace + ms.PC + 0x1FD84w)`.
  Uses stored `LENGTH code = 130436` (0x1FD84) and `LENGTH data = 2531` (8 × 2531 = 20248).

Classes: the equivalence is an independently proved FACT under two
installed-state clauses and the machine-record premise. The ten conditions on
`ms` and `m` are ASSUMED. `m` is the word memory of the installed-state
predicate; its relation to `ms.MEM` is a loader clause (obligation 5).

Text inspection of the exported `refund.S` (SHA256 `4c750e4f…5c3a1757`). This is NOT a proof:

- `cml_main` loads x1 from `cml_heap` and x3 from `cml_stackend`, stores five
  words at `[x1]`, `[x1,#8]` … `[x1,#32]`, and branches to `cake_main`. The
  five stored symbols are `cake_bitmaps`, `cake_bitmaps_buffer_begin`,
  `cake_bitmaps_buffer_end`, `cake_codebuffer_begin`, `cake_codebuffer_end`.
  The order agrees with the five header words.
- The file has 2531 `.quad` values after `cake_bitmaps` and 130436 `.byte`
  values after `cake_main`. Counts agree with the stored lengths. Content
  equality with the stored `data` and `code` was not checked in this run.
- Without `EVAL` defined the bitmap buffer is empty: `data_sp = 0`.
- `cake_codebuffer_end` follows a `.p2align 16`. So `cbspace` is the padding
  to the next 64 KiB boundary. It is fixed at link time and is not 0 in general.
- `cml_heap` and `cml_stackend` are set by the C run-time. Alignment, order
  and the 8192-byte distance depend on that code. Not examined.
- No ARMv8 model of `cml_main`, of the assembler, of the linker or of the
  C run-time is used. The start-up clause therefore stays ASSUMED.

## 5. `is_arm8_machine_config mc0`

Dischargeable by construction of the model record. It carries no physical content.

- `arm8_fix mc0` sets `target := arm8_target`, `len_reg := 1`, `ptr_reg := 0`,
  `len2_reg := 3`, `ptr2_reg := 2`, `callee_saved_regs := [19..28]`.
- `arm8_fix_is_arm8`: `is_arm8_machine_config (arm8_fix mc0)` (FACT, no premise).
- `is_arm8_iff_fix`: `is_arm8_machine_config mc0 ⇔ arm8_fix mc0 = mc0` (FACT).

It is not discharged for a free `mc0`: that statement is false for other
records. The premise goes away when the final theorem names a concrete record.
The physical content then sits in the other clauses about that record
(`target_state_rel`, `interference_ok`, `ffi_interfer_ok`, `start_pc_ok`,
`code_loaded`). No concrete record is defined yet.

## 6. Ledger: premises of the strongest theorem now stored

`refund_behavior_valid_request_no_handler` and `refund_u298_exclusion_valid_request`:

| Premise | Class |
| --- | --- |
| Source non-Fail | PROVED from the input premises (was ASSUMED in U386) |
| Input: standard-input equation, `wfcl`, `wfFS`, `STD_streams` | ASSUMED |
| `is_arm8_machine_config mc0` | ASSUMED; dischargeable by a concrete record (section 5) |
| `refund_installed_no_handler mc0 ms cbspace data_sp` | ASSUMED |

Installed-state obligations (all OPEN):

| # | Obligation | Clauses | Change in U387 |
| --- | --- | --- | --- |
| 1 | Machine record | `refund_lab_conf2.ffi_names = SOME mc0.ffi_names`; shared-memory entry table; `mc0.mmio_info`; `start_pc_ok`; `target_configured` | `is_arm8_machine_config` shown to be six field equations |
| 2 | Start-up code | ten conditions on `ms` and `m` (section 4) | isolated and reduced; not proved |
| 3 | FFI code | `ffi_interfer_ok t.pc mc0` | none |
| 4 | Installer | no clause | exclusion now holds without a source premise for valid-request input |
| 5 | Loader | `code_loaded code mc0 ms`; `bytes_in_mem`; bitmaps `data` and `data_sp` free words; memory-domain clauses; byte/word memory relation; code-buffer clauses; size bounds | none |
| 6 | Processor and OS | `target_state_rel arm8_target t ms`; `interference_ok mc0.next_interfer …`; shared-address clauses | none |

## 7. Controls, identity, imports, exports

- `import-0001` (exit 0): 17 exact statements (9 of U386, 8 new), each with
  tag check. 507 closure nodes; axioms only `bool.SELECT_AX`,
  `bool.INFINITY_AX`, `bool.ETA_AX`, `bool.BOOL_CASES_AX`.
- Control replay `compile_correct'` is still alpha-equivalent to the published
  statement. The fidelity theorem is still identical.
- The seven negative controls of U386 are re-read. The U386 controls pass.
- New controls: source non-Fail is stored only for `basis_ffi ext cl fs`, and
  only with the input premises; no stored theorem states the start-up clause
  without premises; `¬sem_satisfies ∅ P` (the stored source theorem is not
  vacuous in the behaviour set).
- Artifact identity: the theorems name the stored constants `code` and `data`.
  `refund.S` counts agree (section 4). Published scripts were not edited.
- Repeats: both exports byte-identical.
- Not done: clean replay; independent replay.

## 8. Counterexamples and blockers

- No counterexample found. No logical blocker.
- The start-up clause cannot be proved from the stored theories: it is a
  statement about a machine state, and no model of the start-up code exists
  in the proof context.

## 9. Next smallest proof step

1. Reject path: prove `refund_run_wire (implode text) = INL err ⇒ ¬semantics_prog … refund_prog Fail` for `basis_ffi`, from stored `refund_main_error` and the exception lemma of `forge_refundRejectProof`. This closes source non-Fail for every well-formed standard input.
2. Define a concrete machine record with `arm8_fix` and remove `is_arm8_machine_config` as a premise.
3. Start-up code: an ARMv8 step proof for the 27 instructions of `cml_main`, from a stated pre-state (values at `cml_heap`, `cml_stackend`), giving the ten conditions.

M1 open. Integration EXIT NOT_ESTABLISHED. end_to_end=false.
