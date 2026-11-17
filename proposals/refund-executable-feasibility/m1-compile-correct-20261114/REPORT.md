# U386: `compile_correct'` replayed; the two semantic premises reduced to source non-Fail; exclusion proved for the real machine record without an installer-handler clause

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted. It is now a conclusion under stated premises.
Nothing committed. Local results: same machine, same agent, cached parents.
No clean replay. No independent replay.

`cfg` is `set_oracle arm8_backend_config refund_alloc_oracle`.
`L` is `SND (SND (to_lab arm8_config cfg refund_prog))`.
`code` and `data` are the stored constants of `forge_refundArm8Compile`.
Run directory: `results/refund-compile-correct-local-20261114/attempt-0001`.
Published script: `backendProofScript.sml`, SHA256 prefix `380ee3fa` (read only).

## 1. Commands and actual exits

Each case is `python3 -I -B run_case.py <case> <source> <deps…>` through a
wrapper (`go.sh`, `go-src.sh`, `go-real.sh`, `go-imp.sh`, `go-imp2.sh`). The
exact argument vector of each case is in `<case>/command.json`. All cases are
listed in `records/cc/exits.json`.

| Case | Source | Exit | Kind |
| --- | --- | --- | --- |
| `control-0001` | `control-0001.sml` | 0 | control replay, 142 s |
| `explore-0001`–`0003` | variant, state print | 1 | authoring (type name; helper lemma) |
| `lemmas-0001`, `lemmas-0002` | helper lemmas | 1 | authoring |
| `lemmas-0003` | helper lemmas | 0 | pass |
| `explore-0004` | variant, state print | 1 | logical: the simplifier split a union goal (see 3) |
| `explore-0005` | variant, state print | 1 | deliberate stop at the edit site |
| `variant-0001` | `variant-0001.sml` | 0 | lab facts theory, 142 s |
| `src-explore-0001` | statement print | 0 | pass |
| `source-0001`–`0005` | composition | 1 | authoring (types, a `let`, a witness) |
| `source-0006` | `source-0006.sml` | 0 | exact source-level exclusion |
| `real-0001`, `real-0003` | real-record composition | 1 | authoring |
| `real-0002` | first real-record theorem only | 0 | superseded by `real-0004` |
| `real-0004` | `real-0004.sml` | 0 | real-record exclusion and inclusion |
| `import-0001` | import | 1 | MEMORY: PolyML "Run out of store" after 15 s, while loading |
| `import-0002` | import | 1 | authoring (control proof needs a current theory) |
| `import-0003` | `import-0003.sml` | 0 | superseded by `import-0004` |
| `import-0004` | `import-0004.sml` | 0 | 9 exact statements, 504 closure nodes, controls |
| `control-repeat` | `control-0001.sml` | 1 | MEMORY: Interrupt after 16 s, while loading a parent theory |
| `control-repeat-0002` | `control-0001.sml` | 0 | repeat |
| `variant-repeat`, `source-repeat`, `real-repeat` | same sources | 0, 0, 0 | repeats |

Memory failures: `import-0001`, `control-repeat`. No proof step ran in them.
Each passed on the next attempt with the same source. Swap was 8.3–9.1 GiB
used of 9–10 GiB.

Repeat comparison: `forge_refundExclusionSource` and `forge_refundExclusionReal`
exports are byte-identical. `forge_compileCorrectControl` and
`forge_compileCorrectLabFacts` data are identical after the case directory
name is replaced and white space is normalized (the `Theorem` syntax records
the source path, U384). A first comparison of mine reported DIFFERS for the
control when the repeat had not produced files; that line is not evidence.

## 2. Control: `compile_correct'` replayed unchanged

- Text: published lines 4007–4921 (statement, main proof, the five resumed
  parts `data_word`, `lab_target`, `stack_init`, `limits`, `read_limits`),
  byte for byte. Context copied from the published script: lines 17–19, the
  grammar ancestry, the local overloads (199–223), the ML bindings (613–619,
  822–827, 1571–1573, 1583–1592), the local lemmas (2988–3001, 3984–4005).
- Result: `forge_compileCorrectControl.compile_correct'`, exit 0. Its
  conclusion is alpha-equivalent to `backendProofTheory.compile_correct'`
  (checked in the run and again in `import-0004`). No hypotheses. Tag
  `DISK_THM` only.
- Statement and assumptions: `compile asm_conf c prog = SOME (bytes,bitmaps,c')`,
  source `¬semantics_prog s env prog Fail`, `backend_config_ok`, `mc_conf_ok`,
  `mc_init_ok`, `opt_eval_config_wf`, `installed …` ⇒ `∃po. machine_sem mc ffi ms ⊆ extend_with_resource_limit' … (semantics_determ …)`.
- Dependency closure: 500 theory nodes; axioms only `bool.SELECT_AX`,
  `bool.INFINITY_AX`, `bool.ETA_AX`, `bool.BOOL_CASES_AX`.
- Limit: the replay ran in the Forge heap, which has more theories loaded than
  the published build. It is a replay of the proof text, not a clean rebuild.

## 3. Exclusion-specific replay

`forge_compileCorrectLabFacts` (`variant-0001`). The published proof text is
used with three recorded edits (`make_cc.py` checks each site):

1. Conclusion: `machine_sem mc ffi ms` becomes
   `lab_guard (machine_sem mc ffi ms) (lab_facts asm_conf c prog bytes c' mc ffi ms cbspace)`.
   `lab_guard x Q = if Q then x else x ∪ {Fail}`. No premise is changed.
2. One marker `lab_keep_word` is added before line 4197. It keeps the fact
   `SND (to_word …) = p5`, which the published proof proves and then discards.
3. Lines 4817–4822 (the last step) are replaced by `tail-0001.sml`: it proves
   `lab_facts`, then finishes as the published text does.

Finding (`explore-0004`): a first form `machine_sem … ∪ guard` failed because
the simplifier rewrote the union subset goal to a conjunction. The opaque
constant `lab_guard` avoids this. This is a proof-engineering result, not a
weakening.

`lab_facts asm_conf c prog bytes c' mc ffi ms cbspace` is:
`∃t m dm sdm coracle tl. tl = to_lab asm_conf c prog ∧ good_init_state mc ms bytes cbspace t m dm sdm ∧ compiler_oracle_ok coracle c'.lab_conf.labels (LENGTH bytes) asm_conf mc.ffi_names ∧ compile asm_conf (FST (SND tl)).lab_conf (SND (SND tl)) = SOME (bytes,c'.lab_conf) ∧ semantics (make_init mc ffi t m dm sdm ms (SND (SND tl)) (compile asm_conf) (mc.target.get_pc ms + n2w (LENGTH bytes)) cbspace coracle) ≠ Fail`.

Theorems (all exit 0, tag `DISK_THM` only, no hypotheses):

- `compile_correct_lab_guard`: the published premises give the guarded inclusion.
- `compile_correct_lab_facts`: the published premises of `compile_correct'`
  give `lab_facts`. This is generic in the program and the configuration.
- `compile_correct_from_guard`: the guarded theorem gives the published
  statement again (alpha-equivalent; fidelity check).
- `lab_nonfail_unaligned`: non-Fail for the byte-aligned initial lab state
  gives non-Fail for the state of premise 16 (published `implements_align_dm`,
  `implements_align_sdm`). The published proof gives the aligned form only.
- Control: `¬Q ⇒ Fail ∈ lab_guard x Q` (the guard is not vacuous).

## 4. Exact program: results

`forge_refundExclusionSource` (`source-0006`):

- `refund_install_exclusion_source`:
  `is_arm8_machine_config mc_conf ∧ ¬semantics_prog (FST (THE (prim_sem_env ffi))) (SND (THE (prim_sem_env ffi))) refund_prog Fail ∧ installed code cbspace data data_sp refund_lab_conf2.ffi_names (heap_regs cfg.stack_conf.reg_names) mc_conf refund_lab_conf2.shmem_extra ms ⇒ ∀n. no_install_prefix mc_conf ffi n ms`.
  `heap_regs cfg.stack_conf.reg_names = (1,3)`.
- `refund_u298_exclusion_source_any_handler`: the same premises and
  `same_but_install mc0 mc_conf` give the U298 form for `mc0` and equal runs.

`forge_refundExclusionReal` (`real-0004`), with the U360 theorems
`installed_modulo_install_handler` and `install_exclusion_suffices`:

- `refund_installed_no_handler mc0 ms cbspace data_sp`: the body of the
  published `installed` for `code`, `data`, `refund_lab_conf2`, registers
  (1,3), with the single `install_interfer_ok` clause replaced by `T`.
  `import-0004` checks that it names no `install_interfer_ok`, `installed` or
  `good_init_state` constant, and that it names `code` and `data`.
- `refund_u298_exclusion_real`:
  `is_arm8_machine_config mc0 ∧ ¬semantics_prog … refund_prog Fail ∧ refund_installed_no_handler mc0 ms cbspace data_sp ⇒ ∀j ms' ffi'. evaluate mc0 ffi j ms = (TimeOut,ms',ffi') ⇒ mc0.target.get_pc ms' ≠ mc0.install_pc`.
  This is the U298 exclusion for every `install_interfer` of `mc0`.
- `refund_compile_correct_no_handler`: the same premises give
  `machine_sem mc0 ffi ms ⊆ extend_with_resource_limit (semantics_prog … refund_prog)`.
  `install_exclusion_suffices` is applied here. Its exclusion premise is
  discharged by `refund_u298_exclusion_real`; it is not assumed.

## 5. Ledger for the 16 premises of `refund_compile_install_exclusion`

Classes: FACT = machine-checked with no premise about machine, state or
source behaviour. COND = machine-checked consequence of the stated premises.
ASSUMED = premise of the final theorems.

| # | Premise | Class | By |
| --- | --- | --- | --- |
| 1 | `mc_conf_ok mc_conf` | COND on `is_arm8_machine_config` | published `arm8_machine_config_ok` |
| 2 | `no_share_mem_inst L ⇒ compiler_oracle_ok …` | guard FACT (U384); consequent COND | `compile_correct_lab_facts`; holds for the oracle that the published proof builds |
| 3 | `good_code … LN L` | FACT | `refund_lab_good_code` (U385) |
| 4 | `asm_conf = mc_conf.target.config` | COND on `is_arm8_machine_config` | U385 |
| 5, 6 | `labels = LN`, `pos = 0` | FACT | `refund_lab_conf_facts` (U385) |
| 7 | exact compile equation | FACT | `refund_lab_compile` (U385); also `compile_lab_conf` |
| 8 | `c'.ffi_names = SOME mc_conf.ffi_names` | ASSUMED | clause of the installed-state predicate |
| 9 | `good_init_state …` | ASSUMED | clause of the installed-state predicate, without `install_interfer_ok` for the real record |
| 10, 11 | shared-memory table, `mmio_info` | ASSUMED | clauses of the installed-state predicate |
| 12, 13, 15 | no ShareMem, `mmio_pcs_min_index`, ffi names | FACT | U384, U385 |
| 14 | size bound | ASSUMED | clause of the installed-state predicate |
| 16 | lab `semantics … ≠ Fail` | COND | `compile_correct_lab_facts` and `lab_nonfail_unaligned`, from source non-Fail and the installed-state predicate |

Answer to "genuinely discharged": premises 2 and 16 are NOT independently
proved facts. They are conditional consequences. They no longer appear as
premises. In their place the final theorems have one source-level premise:
`¬semantics_prog s env refund_prog Fail`. The proof does not separate which
of the published premises `compiler_oracle_ok` needs.

Premises of the final theorems `refund_u298_exclusion_real` and
`refund_compile_correct_no_handler` (all ASSUMED, none proved):

1. `is_arm8_machine_config mc0`.
2. `¬semantics_prog (FST (THE (prim_sem_env ffi))) (SND (THE (prim_sem_env ffi))) refund_prog Fail`.
3. `refund_installed_no_handler mc0 ms cbspace data_sp`.

## 6. Installed-state obligations that remain (all OPEN)

`installed` is not proved. `refund_installed_no_handler` is not proved. Its
clauses, by obligation:

| # | Obligation | Clauses |
| --- | --- | --- |
| 1 | Machine record | `is_arm8_machine_config mc0`; `refund_lab_conf2.ffi_names = SOME mc0.ffi_names`; shared-memory entry table; `mc0.mmio_info`; `start_pc_ok`; `target_configured` |
| 2 | Start-up code | registers 1 and 3 byte-aligned, ordered, at least `1024w * bytes_in_word` apart; five header words at register 1 (bitmap pointer, bitmap end, data end, code end, code-buffer end); `t.pc` at the entry and aligned |
| 3 | FFI code | `ffi_interfer_ok t.pc mc0` |
| 4 | Installer | no clause. `install_interfer_ok` is removed. The exclusion holds for every handler. It depends on source non-Fail |
| 5 | Loader | `code_loaded code mc0 ms`; `bytes_in_mem` for `code`; the bitmaps `data` and `data_sp` free words at the bitmap pointer; memory-domain clauses; code-buffer clauses; size bounds |
| 6 | Processor and OS | `target_state_rel arm8_target t ms`; `interference_ok mc0.next_interfer …`; shared-address clauses |

New open obligation outside the installed state: source non-Fail for the
exact `refund_prog` (premise 2 above). No stored Forge theorem states it.

## 7. Exact code, bitmaps, handler semantics

- The installed-state premise names the stored `code` and `data`. The compile
  equation `compile arm8_config cfg refund_prog = SOME (code,data,c1)` is the
  stored `refund_alloc_compiled`; `c1.lab_conf = refund_lab_conf2` is proved
  from `compile_lab_conf` and `refund_lab_compile`.
- No lemma about the old unspecified oracle is used.
- Handler choices: `refund_u298_exclusion_source_any_handler` (all handlers
  that differ from an installed record) and `refund_u298_exclusion_real` (the
  record itself, no handler clause).
- All earlier theorems and the seven negative controls are re-read in
  `import-0004`.

## 8. Counterexamples and blockers

- No counterexample to a target statement was found.
- No logical blocker. Host memory is a practical limit (two memory failures).
- Not done: clean replay, independent replay, any proof of the three premises.

## 9. Next minimal proof obligation

Prove `¬semantics_prog (FST (THE (prim_sem_env ffi))) (SND (THE (prim_sem_env ffi))) refund_prog Fail`
for the exact `refund_prog`, or record why it must stay a premise. First
check: which stored theorems of the refund source theories give an evaluation
or type-soundness result for `refund_prog`. After that: obligation 2
(start-up code) of the installed-state predicate.

M1 open. Integration EXIT NOT_ESTABLISHED. end_to_end=false.
