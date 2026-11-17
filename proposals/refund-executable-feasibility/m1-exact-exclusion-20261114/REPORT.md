# U384: exact-program invariant and target-level installer exclusion under the published compile-level premises

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted and not used. Nothing committed.
Local results: same machine, same agent, cached parents. No clean replay.

## 1. Exact-program ShareMem count (in-logic evaluation, `forge_refundLabFiltered`)

`L` is `SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))`.
`F` is `filter_skip L`, the program the published `lab_to_target$compile` encodes.

| Program | Lines (with labels) | ShareMem lines | Sections with ShareMem |
| --- | --- | --- | --- |
| `L` | 33749 | 0 | none |
| `F` | 33735 | 0 | none |

Proved: `refund_lab_sharemem_counts`, `refund_lab_no_share_mem`
(`no_share_mem_inst L ∧ no_share_mem_inst F`, the published predicate).
No reachable behavior is excluded: the program has no such line.

## 2. `lab_step_closed`: DISCHARGED for the exact program

- `region2_lab_step`: the U375 region invariant is closed under `lab_step`
  for any code without ShareMem lines (11 instruction kinds).
- `refund_filtered_region_hyp`: region hypothesis for `F` and sections
  `[Install_location; InstallData_location]` (walk check re-evaluated on `F`).
- `refund_lab_inv s ⇔ region_inv2 G D OK F s`; `refund_lab_step_closed`:
  `⊢ lab_step_closed refund_lab_inv`.

## 3. Invariant initialization and preservation

- Initialization: `refund_lab_inv_init`: `good_init_state mc ms bytes cbs t m dm sdm ⇒
  ∀k. refund_lab_inv (make_init mc ffi t m dm1 sdm1 ms F cmp cbpos cbspace coracle with clock := k)`.
  PROVED from the published `good_init_state` only.
- Preservation: `region2_lab_step`. PROVED.

## 4. Target installer-exclusion theorems

Generic (`forge_refundExclusionChain`): `compile_install_exclusion`: the 16
premises of the published `semantics_compile_lemma'` plus `lab_step_closed Inv`
and `Inv` at the filtered initial state for every clock imply
`∀n. no_install_prefix mc_conf ffi n ms`. `state_rel`, `oracle_tie`,
`encoder_correct`, the layout bound and the no-Error condition are derived
inside; they are no longer premises. The published `IMP_state_rel_make_init`
(local) is replayed unchanged (17 subgoals).

Exact (`refund_compile_install_exclusion`), 16 premises, no invariant premise:

```
⊢ mc_conf_ok mc_conf ∧
  (no_share_mem_inst L ⇒ compiler_oracle_ok coracle c'.labels (LENGTH bytes) asm_conf mc_conf.ffi_names) ∧
  good_code mc_conf.target.config LN L ∧ asm_conf = mc_conf.target.config ∧
  c.labels = LN ∧ c.pos = 0 ∧ compile asm_conf c L = SOME (bytes,c') ∧
  c'.ffi_names = SOME mc_conf.ffi_names ∧ good_init_state mc_conf ms bytes cbspace t m dm sdm ∧
  (two shared-memory table equations) ∧ no_install_or_no_share_mem L mc_conf.ffi_names ∧
  mmio_pcs_min_index mc_conf.ffi_names = SOME i ∧
  cbspace + LENGTH bytes + ffi_offset * (i + 3) < dimword (:64) ∧
  (∀ffis. c.ffi_names = SOME ffis ⇒ EVERY (λx. ∃s. x = ExtCall s) ffis) ∧
  semantics (make_init mc_conf ffi t m dm sdm ms L (compile asm_conf) (pc + n2w (LENGTH bytes)) cbspace coracle) ≠ Fail ⇒
  ∀n. no_install_prefix mc_conf ffi n ms
```

Status: PROVED, CONDITIONAL on these 16 premises. They are the premises that
the published backend proof supplies to the published compile-level lemma.
For the exact oracle they are NOT yet proved. The theorem therefore still
has application-specific premises. The U298 exclusion is NOT ESTABLISHED
unconditionally.

## 5. `install_exclusion_suffices` applicability

Finding: the simulation needs `state_rel`, which contains a correct installer
handler. `install_exclusion_suffices` exists because that handler may be
wrong on the real machine. Direct use would be circular.

Resolved by `forge_installHandlerIrrelevant`: `no_install_prefix_same_but_install`:
if `mc2` differs from `mc` only in `install_interfer` and `mc2` never reaches
the installer entry, then `mc` never reaches it and both runs are equal at
every clock. `refund_install_exclusion_any_handler` (`forge_refundExclusionFinal`):
`same_but_install mc mc_conf ∧ (the 16 premises for mc_conf) ⇒
(∀j ms' ffi'. evaluate mc ffi j ms = (TimeOut,ms',ffi') ⇒ mc.target.get_pc ms' ≠ mc.install_pc) ∧
∀k. evaluate mc ffi k ms = evaluate mc_conf ffi k ms`.
The first conjunct is exactly the exclusion premise of
`install_exclusion_suffices`. Applicability: CONDITIONAL. The link from the
`installed`-level premises of `install_exclusion_suffices` to the 16
compile-level premises is the backend chain and is NOT_RUN.

## 6. Oracle-specific backend chain

| Link | Status |
| --- | --- |
| Published `backendProof$compile_correct` at `refund_alloc_oracle` | PROVED (U378), premises `backend_config_ok` etc. NOT_RUN |
| `backend$compile … = SOME (code,data,c1)`; `lab_to_target$compile … L` with `attach_bitmaps` | PROVED (U368) |
| `no_share_mem_inst L` | PROVED (this entry) |
| lab-to-target level: initial `state_rel`, simulation, exclusion | PROVED from the compile-level premises (this entry) |
| `good_code`, `compiler_oracle_ok`, `mc_conf_ok`, `c.labels = LN`, `c.pos = 0`, ffi-name premises for the exact program | NOT_RUN |
| `good_init_state` from `installed`; lab `semantics ≠ Fail` from the source semantics | NOT_RUN |

## 7. Installed-state obligations

| # | Obligation | Status |
| --- | --- | --- |
| 1 | Machine record and abstract state | OPEN |
| 2 | Start-up code | OPEN |
| 3 | FFI code (`ffi_interfer_ok`) | OPEN |
| 4 | Installer | OPEN. The handler need not be correct once the 16 premises hold for a handler-corrected configuration; those premises are not yet derived |
| 5 | Loader | OPEN |
| 6 | Processor and OS | OPEN |

No obligation is discharged.

## 8. Replay determinism

- Cause of the U383 difference, verified: the `Theorem … Proof … QED` syntax
  records the source file path in the theory data. `run_case.py` copies the
  source into the case directory, so the path contains the case name.
- Evidence: (a) for `forge_simReplay`, a canonical dump of every theorem and
  definition (statement with types, tags, hypotheses), parents, 296 ancestors
  and constants is byte-identical for `final-0003` and `final-repeat`
  (17222 bytes, SHA256 `3b81eea5…def59e`); (b) the `.dat` files are identical
  after replacing the case directory name, and the `.sml` files differ only in
  the embedded data hash; (c) four theories of this entry stored with
  `store_thm`/`save_thm` (no source path) repeat byte-identically
  (`forge_refundLabFiltered`, `forge_refundExactExclusion`,
  `forge_installHandlerIrrelevant`, `forge_refundExclusionFinal`); (d) the one
  theory of this entry that uses the `Theorem` syntax
  (`forge_refundExclusionChain`) shows the same path-only difference.
- Conclusion: statements, tags and dependencies are the same across repeats.
  File-level byte identity holds only when no source path is recorded.
  Deterministic replay on another machine or from clean sources: NOT_RUN.

## 9. Method notes and uncertainty

- In this heap the bare names `compile_lab` and others parse to constants of
  `backend_asm`, and `code`, `data`, `ffis`, `conf`, `info`, `name` are
  constants. The chain run removes those mappings and hides those names; an
  origin check fails closed if a stored statement uses a `backend_asm` or
  refund-compile constant. The U383 statements were checked by `aconv`
  against the published theorem and are not affected.
- Three edits in the replayed published tail of `semantics_compile_lemma'`
  (recorded in `make_chain.py`): one hypothesis selected by pattern, one
  extra rewrite with the published `no_share_mem_filter_skip`, one explicit
  close of the semantics conjunct. The published file is unchanged.
- Premise fidelity: 14 of the 15 premises of the exported published
  `semantics_compile` match premises here; the 15th (`good_code asm_conf c.labels code`)
  appears as `good_code mc_conf.target.config LN code`.
- The exact-statement check compares up to renaming of type variables.

## 10. Negative controls (all re-read in the import)

| Control | Theorem |
| --- | --- |
| Omitted invariant premise | `trivial_invariant_not_closed`: `¬lab_step_closed (λs. T)` |
| Incorrect ShareMem assumption | `sharemem_line_detected`: a one-line ShareMem program fails `sm_free` and `no_share_mem_inst`, count 1 |
| Region without section 31 | `filt_walk_single_eval`, `refund_filtered_walk_not_closed_29` |
| Invalid target-PC correspondence | `endpoint_correspondence_insufficient` (U382), 8-bit wrap example (U380) |
| Handler matters when the installer is reached | `handler_matters_when_installer_reached` |
| Statement controls | forms without the initial-state, handler-relation or compile-level premises are not the stored ones |

## 11. Executed commands

Run directory: `results/refund-exact-exclusion-local-20261113/attempt-0001`.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `go.sh filtered-0001` | 0 | counts and walk checks by evaluation (412 s) |
| `go.sh exact-0001` … `exact-0009` | 1 each | my tactic, name-clash and typing errors; not counted |
| `go.sh exact-0010` | 0 | `forge_refundExactExclusion`, 11 theorems |
| `go-chain.sh chain-0001` … `chain-0016` | 1 each | name clashes, splice and context differences; not counted |
| `go-chain.sh chain-0017` / `chain-0018` | 0 / 0 | generic chain; with the exact instance (final) |
| `go.sh handler-explore-0001` … `0006` | 0 each | staged explorations; lemma open until `0006` |
| `go.sh handler-0001` | 0 | `forge_installHandlerIrrelevant`, 3 theorems |
| `go-final.sh final-0001` / `final-0002` | 1 / 1 | tactic error; interrupted while loading (10 s), not a proof result |
| `go-final.sh final-0003` | 0 | `refund_install_exclusion_any_handler` |
| `go-import.sh exact-import` | 1 | my expected term left a variable untyped; not counted |
| `go-import.sh exact-import-0002` | 0 | 9 exact statements, all tags, 404 closure nodes, controls |
| `exact-repeat`, `handler-repeat`, `final-repeat`, `filtered-repeat` | 0 each | byte-identical exports |
| `chain-repeat` | 0 | data identical after replacing the case directory name |
| `dump-replay-a`…`a3`, `b`…`b3` | 1 each | my dump script errors; the empty outputs are not counted |
| `dump-replay-a4` / `dump-replay-b4` | 0 / 0 | canonical dumps byte-identical |

Source and data hashes: see `MANIFEST.json`. Clean replay and independent
replay: NOT_RUN.

## 12. Next smallest obligation

Prove the purely computational compile-level premises for the exact
program: `good_code arm8_config LN L` and the configuration facts
(`c.labels = LN`, `c.pos = 0`, the `compile` equation without `attach_bitmaps`)
for `c = (FST (SND (to_lab …))).lab_conf`. Then `mc_conf_ok` for the ARMv8
machine configuration, then the semantic premises through the published
backend proof.
