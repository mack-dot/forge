# U385: exact compiler facts proved; 16 premises reduced to `installed`, the machine configuration and two semantic premises

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted and not used. Nothing committed.
Local results: same machine, same agent, cached parents. No clean replay.

`L` is `SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))`.
`labc` is `(FST (SND (to_lab …))).lab_conf`. `code` and `data` are the stored constants of `forge_refundArm8Compile`.

## 1. Premise matrix for `refund_compile_install_exclusion`

| # | Premise | Status | By |
| --- | --- | --- | --- |
| 1 | `mc_conf_ok mc_conf` | DISCHARGED | published `arm8_machine_config_ok` from `is_arm8_machine_config mc_conf` |
| 2 | `no_share_mem_inst L ⇒ compiler_oracle_ok coracle c'.labels (LENGTH bytes) asm_conf mc_conf.ffi_names` | OPEN (guard true, U384) | `compiler_oracle_ok` is a property of the run-time compile oracle |
| 3 | `good_code mc_conf.target.config LN L` | DISCHARGED | `refund_lab_good_code` (in-logic evaluation) |
| 4 | `asm_conf = mc_conf.target.config` | DISCHARGED | `asm_conf := arm8_config`; `is_arm8_machine_config` |
| 5 | `c.labels = LN` | DISCHARGED | `refund_lab_conf_facts` |
| 6 | `c.pos = 0` | DISCHARGED | `refund_lab_conf_facts` |
| 7 | `compile asm_conf c L = SOME (bytes,c')` | DISCHARGED | `refund_lab_compile`: `bytes := code`, `c' := refund_lab_conf2` |
| 8 | `c'.ffi_names = SOME mc_conf.ffi_names` | From published `installed` | clause of `installed` |
| 9 | `good_init_state mc_conf ms bytes cbspace t m dm sdm` | From published `installed` | clause of `installed` |
| 10 | shared-memory entry table equation | From published `installed` | clause of `installed` |
| 11 | `mc_conf.mmio_info` equation | From published `installed` | clause of `installed` |
| 12 | `no_install_or_no_share_mem L mc_conf.ffi_names` | DISCHARGED | `refund_lab_no_share_mem`, `refund_lab_ffi_names`, published `mmio_pcs_min_index_is_SOME` |
| 13 | `mmio_pcs_min_index mc_conf.ffi_names = SOME i` | DISCHARGED | `i := LENGTH mc_conf.ffi_names`; `refund_lab_ffi_names` |
| 14 | `cbspace + LENGTH bytes + ffi_offset * (i + 3) < dimword (:64)` | From published `installed` | clause of `installed` |
| 15 | `∀ffis. c.ffi_names = SOME ffis ⇒ …` | DISCHARGED | `labc.ffi_names = NONE` |
| 16 | lab `semantics (make_init …) ≠ Fail` | OPEN | needs the published backend semantics chain for this oracle |

Count: 9 discharged, 5 supplied by the published `installed` predicate, 2 open
(premise 2 in part). `installed` is a physical/installed-state premise; it is
NOT proved here.

## 2. `good_code` and configuration

- `refund_lab_good_code`: `⊢ good_code arm8_config LN L`. Method: an executable
  check `gc_check` (section ends, label ownership, distinct sections and
  labels, every referenced label defined, encoder pre-checks), a soundness
  theorem `gc_check_good_code`, and in-logic evaluation on the exact program.
  The encoder pre-check uses the published `asm_ok_arm8`; `asm_ok_arm8_link`
  proves `asm_ok_arm8 a ⇔ asm_ok a arm8_config`.
- `refund_lab_conf_facts`: `labc.labels = LN ∧ labc.pos = 0 ∧ labc.ffi_names = NONE`
  (`to_lab_lab_conf` with the published `to_word_lab_conf`).

## 3. Exact compilation for `refund_alloc_oracle`

- `refund_lab_compile`: `⊢ lab_to_target$compile arm8_config labc L = SOME (code, refund_lab_conf2)`,
  with `refund_lab_conf2` defined as the second component of that result.
- `refund_lab_bitmaps`: `⊢ FST (to_lab …) = data`.
- `refund_lab_ffi_names`: `⊢ ∃ffi_names. refund_lab_conf2.ffi_names = SOME ffi_names ∧
  mmio_pcs_min_index ffi_names = SOME (LENGTH ffi_names)`.
- These come from U368 `refund_alloc_target` (recomputed oracle, same stored
  `code` and `data`) and the published `attach_bitmaps_SOME` and
  `compile_lab_no_share_mem_IMP_mmio_pcs_min_index`. No lemma about the old
  unspecified oracle is used.

## 4. `mc_conf_ok`

DISCHARGED from `is_arm8_machine_config mc_conf` by the published
`arm8_machine_config_ok`. `is_arm8_machine_config` is a premise about the
machine record (installed-state obligation 1).

## 5. Initialization and non-Fail semantics

- `good_init_state`: taken from the published `installed` predicate
  (`refund_install_exclusion_installed`). NOT derived from physical evidence.
- Lab semantics not `Fail`, and `compiler_oracle_ok`: OPEN. In the published
  proof both come out of `backendProof$compile_correct'`: the oracle condition
  in its `lab_target` step, the non-Fail fact only after its `stack_init` and
  `limits` steps. That proof is goal-directed on a different conclusion; a
  replay with the exclusion conclusion is the next obligation. NOT_RUN.

## 6. Exact target-level results (theory `forge_refundExclusionArm8`)

```
refund_install_exclusion_installed
⊢ is_arm8_machine_config mc_conf ∧
  installed code cbspace bitmaps data_sp refund_lab_conf2.ffi_names (r1,r2) mc_conf refund_lab_conf2.shmem_extra ms ∧
  (∀t m dm sdm. good_init_state mc_conf ms code cbspace t m dm sdm ⇒
     compiler_oracle_ok coracle refund_lab_conf2.labels (LENGTH code) arm8_config mc_conf.ffi_names ∧
     semantics (make_init mc_conf ffi t m dm sdm ms L (compile arm8_config)
                  (mc_conf.target.get_pc ms + n2w (LENGTH code)) cbspace coracle) ≠ Fail) ⇒
  ∀n. no_install_prefix mc_conf ffi n ms

refund_u298_exclusion_any_handler
⊢ same_but_install mc0 mc_conf ∧ (the three premises above) ⇒
  (∀j ms' ffi'. evaluate mc0 ffi j ms = (TimeOut,ms',ffi') ⇒ mc0.target.get_pc ms' ≠ mc0.install_pc) ∧
  ∀k. evaluate mc0 ffi k ms = evaluate mc_conf ffi k ms
```

`refund_install_exclusion_arm8` is the explicit eight-premise form.
Status: PROVED, CONDITIONAL. The exact U298 exclusion is NOT ESTABLISHED
without premises. `install_exclusion_suffices` was not applied: its exclusion
premise is available only under the semantic premise.

## 7. Installed-state obligations

| # | Obligation | Status |
| --- | --- | --- |
| 1 | Machine record and abstract state | OPEN (`is_arm8_machine_config`, `installed` are premises) |
| 2 | Start-up code | OPEN |
| 3 | FFI code (`ffi_interfer_ok`) | OPEN |
| 4 | Installer | OPEN. No handler correctness is needed for the real machine `mc0`; the exclusion still depends on the two semantic premises |
| 5 | Loader | OPEN |
| 6 | Processor and OS | OPEN |

## 8. Verification

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `go.sh gc-explore-0001`, `0003`, `0005` | 0 each | staged explorations |
| `go.sh gc-explore-0002` | 1 | my definition names; `gc-explore-0004` did not start (my script error) |
| `go.sh facts-0001` | 1 | a published definition has a translation precondition; replaced by an equivalent executable check with proof |
| `go.sh facts-0002`, `facts-0003` | 1, 1 | my tactic; my control term |
| `go.sh facts-0004` | 0 | `forge_refundCompileFacts` |
| `go-arm8.sh arm8-0001`, `arm8-0002` | 1, 1 | missing parent load; machine type |
| `go-arm8.sh arm8-0003` | 1 | PolyML ran out of store after 17 s while loading; not a proof result |
| `go-arm8.sh arm8-0004` | 1 | first theorem proved; my tactic for the installed form |
| `go-arm8.sh arm8-0005` | 0 | `forge_refundExclusionArm8`, 3 theorems |
| `go-imp.sh facts-import` | 1 | my expected terms typed a variable twice; not counted |
| `go-imp.sh facts-import-0002` | 0 | 9 exact statements, all tags, 499 closure nodes, 7 negative controls re-read, 2 statement controls |
| `go.sh facts-repeat`, `go-arm8.sh arm8-repeat` | 0, 0 | exports byte-identical (no source path recorded) |

Hashes: `facts-0004.sml` `02d7e66d45363125e03595f649d181e2d5f0907feb5cbc4d374cf21b5421fa1f`;
`arm8-0003.sml` `4cb2d393f6d2b993e372f00bc8c4161b68e88926262e72d4f8f74eb0408922ff`;
theory data `38ed5524…38339` and `09234f42…c36c5` (full values in `MANIFEST.json`).
Replay nondeterminism: none new. The only known difference stays the source
path recorded by the `Theorem` syntax (U384). Clean replay and independent
replay: NOT_RUN.

New negative control: `gc_check_rejects_undefined_label`. Kept: invariant,
ShareMem, region, handler, target-PC and wraparound controls.

## 9. Next smallest obligation

Replay the published `backendProof$compile_correct'` for this oracle with the
exclusion conclusion, to derive `compiler_oracle_ok` (its `lab_target` step)
and lab `semantics ≠ Fail` (after its `stack_init` and `limits` steps) from
`backend_config_ok`, `mc_init_ok`, `installed` and the source-level non-Fail
premise. First step: extract its local lemmas and replay the unchanged proof
as a control in this heap.
