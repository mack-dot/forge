# U377–U379: P3 not established; target-level prefix calculus proved; strengthened statement fixed; first backend link for `refund_alloc_oracle`

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted and not used. Nothing committed in
this run. All results are local: same machine, same agent, cached parents.

Statuses: PROVED (HOL kernel accepted it in this session; `DISK_THM` only, no
hypotheses, no tagged axioms), PROPOSED (written down and type-checked, not
proved), NOT_RUN, OPEN.

| Item | Status |
| --- | --- |
| Strengthened `compile_correct` | **PROPOSED, NOT PROVED** |
| Base cases at target-evaluator level: clock zero, Halt, one ordinary step | **PROVED** |
| Base cases of the strengthened simulation itself (with `state_rel`) | **NOT_RUN** |
| Intermediate target-PC invariant | **PARTLY**: one-step fact and segment composition PROVED; multi-step encoder segments NOT_RUN |
| Control-flow cases (jumps, returns, CallFFI, lowering steps) | **NOT_RUN** |
| Backend chain for `refund_alloc_oracle` | **First link PROVED**; the Forge theorems above it NOT_RUN |
| Target-level installer exclusion (U298) | **NOT ESTABLISHED** |

## 1. Published proof: copied, unchanged

`published/lab_to_targetProofScript.sml` is a byte copy of the pinned source
(SHA256 `6cfb4a5f85277e9e4de0ff83f14b515be5d100cedb9375f44e85b072d731b433`).
The pinned tree is unmodified. Structure found: the main proof of
`compile_correct` (lines 7677–7706) is short. It splits on the fetched line
and suspends nine cases (`Asm`, `ShareMemOp`, `Jump`, `JumpCmp`, `Call`,
`LocValue`, `CallFFI`, `Install`, `Halt`), each resumed later. The cases rest
on step lemmas of one shape:

```
∀k. evaluate c io (k + l) ms1 = evaluate (shift_interfer l c) io k ms2
```

(for example `evaluate_nop_steps`, `asm_step_IMP_evaluate_step`). They expose
the end of a segment of `l` target steps, not the states inside it.

## 2. Strengthened statement (PROPOSED, NOT PROVED)

Built from the published statement by term surgery and type-checked:

```
∀s1 res mc_conf s2 code2 labs t1 ms1.
  (oracle_tie mc_conf ms1 s1 ∧ evaluate s1 = (res,s2) ∧ res ≠ Error ∧
   encoder_correct mc_conf.target ∧ state_rel (mc_conf,code2,labs,p) s1 t1 ms1) ∧
  (∀k r t. evaluate (s1 with clock := k) = (r,t) ⇒
           ∀i bs n. asm_fetch t ≠ SOME (LabAsm Install i bs n)) ⇒
  ∃k t2 ms2.
    evaluate mc_conf s1.ffi (s1.clock + k) ms1 = (res,ms2,s2.ffi) ∧
    no_install_prefix mc_conf s1.ffi (s1.clock + k) ms1
```

Fidelity check (machine-checked, exit 0): removing the added premise and the
added conclusion gives exactly the published statement. The relation between
lab positions and target counters is the published `state_rel`, unchanged.

Correction: `statement-0001` printed the prefix bound as `s1.clock`. That was
an extraction error of the agent. `statement-0002` has `s1.clock + k` and
checks that the bound mentions the existential clock. No proof depended on
the wrong form.

Known difficulty, not resolved: the clock-zero case of this statement needs
`get_pc ms1 ≠ install_pc` from `state_rel` alone. Whether `state_rel` gives it
when the lab counter is past the end of the code was not checked.

## 3. Target-level prefix calculus (PROVED)

Theory `forge_targetInstallPrefix`; published `targetSem` only; generic.

`no_install_prefix mc ffi n ms` ⇔ every `TimeOut` prefix of the target
evaluator up to clock `n` has a program counter different from
`mc.install_pc`. `no_install_prefix_all`: for all `n` this is exactly the
frozen U298 exclusion.

| Theorem | Statement |
| --- | --- |
| `no_install_prefix_zero` | At clock 0 it holds iff `get_pc ms ≠ install_pc` |
| `no_install_prefix_mono` | Downward closed in the clock |
| `no_install_prefix_halt` | At the halt entry, with `halt_pc ∉ prog_addresses` and `halt_pc ≠ install_pc`, it holds for every clock |
| `no_install_prefix_next` | For a state in `prog_addresses \ ffi_entry_pcs` with encoded bytes in memory and `install_pc ∉ prog_addresses`: it holds at `SUC n` iff, when the published step conditions hold, it holds at `n` for the successor state and shifted interference |
| `no_install_prefix_segment` | If `∀k. evaluate c io (k + l) ms1 = evaluate c2 io2 k ms2`, the two configurations agree on `install_pc` and `target`, the property holds for the first `l` steps from `ms1` and for `n` steps from `ms2`, then it holds for `l + n` steps from `ms1` |

Instruction boundaries and intermediate states are kept apart:
`no_install_prefix_segment` composes at boundaries (the shape of the
published step lemmas); the first premise of it is the statement about the
intermediate states of one segment, and it must be proved per segment.
`no_install_prefix_next` proves that statement for a segment of one target
step. For an instruction that is encoded as several target instructions the
intermediate counters come from the published `encoder_correct` (`asserts`
with the counter in the instruction's own byte range). That per-segment lemma
is NOT_RUN. Nothing is inferred from endpoint correspondence.

Controls: `prefix-missing-first` (the segment lemma without the first-segment
premise is not the stored statement); `prefix-invalid-layout` (a proved
countermodel: with `halt_pc = install_pc` the Halt claim is false).

## 4. Backend chain for `refund_alloc_oracle`

PROVED `forge_refundAllocBackend.refund_alloc_backend_correct`: the published
`backendProof$compile_correct`, instantiated by matching, for every `c1`:

```
compile arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog = SOME (code,data,c1) ⇒
  (¬semantics_prog s env refund_prog Fail ∧
   backend_config_ok arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) ∧
   mc_conf_ok mc ∧ mc_init_ok arm8_config (set_oracle …) mc ∧
   installed code cbspace data data_sp c1.lab_conf.ffi_names (heap_regs …) mc c1.lab_conf.shmem_extra ms ⇒
   machine_sem mc ffi ms ⊆ extend_with_resource_limit (semantics_prog s env refund_prog))
```

Its antecedent holds for some `c1` by `refund_alloc_compiled` (U368). The
only oracle constant is `refund_alloc_oracle`. The old constant `oracle` is
not used and no equivalence is assumed.

NOT_RUN: `backend_config_ok` for this configuration; the Forge theorems that
were built on the old `oracle` (U291, U296, U347–U358). A fresh import of
this one-theorem theory was not run; its repeat is byte-identical.

## 5. Target-level installer exclusion: NOT ESTABLISHED

Missing, in order:

1. Per-segment prefix lemmas: strengthened forms of the published step
   lemmas (`evaluate_nop_step(s)`, `asm_step_IMP_evaluate_step` and the
   jump, FFI and shared-memory steps) that also conclude
   `no_install_prefix` for their `l` steps.
2. The nine cases of the strengthened `compile_correct`, each by
   `no_install_prefix_segment` plus the induction hypothesis.
3. The link from `refund_lab_good_init_avoids_install` (U375) to the added
   lab premise (its conclusion has the needed form for `make_init`).
4. The strengthened `semantics_compile` and the backend chain for
   `refund_alloc_oracle`.

`install_exclusion_suffices` (U360) is not applicable until then.

Gaps that come from runtime, loader and FFI assumptions, unchanged: the
whole argument is about the machine model. `ffi_interfer_ok` (inside
`good_init_state`) is assumed for the native FFI code; the loader and the
start-up code are assumed to give `installed`; the processor is assumed to
follow the L3 model.

## 6. Installed-state obligations

| # | Obligation | Status |
| --- | --- | --- |
| 1 | Complete machine record and abstract state | OPEN |
| 2 | Start-up code | OPEN |
| 3 | FFI code meets `ffi_interfer_ok` | OPEN |
| 4 | Installer | OPEN. Lab-level exclusion PROVED (U375). Target-level transport (P3) not proved |
| 5 | Loader | OPEN |
| 6 | Processor and operating system | OPEN |

None is discharged.

## 7. Executed commands

Run directory: `results/refund-p3-target-prefix-local-20261113/attempt-0001`.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `run_case.py explore-0001` … `explore-0004` | 0 each | Staged explorations; `0001`–`0003` left the one-step lemma open, `0004` proved all six |
| `python3 -I -B run_case.py prefix-0001 prefix-0001.sml` | 0 | Six theorems, first attempt |
| `run_case.py prefix-import` / `prefix-repeat` | 0 / 0 | Six exact statements (definition included), 288 closure nodes; byte-identical |
| `run_case.py prefix-missing-first` | 1 | Intended statement mismatch |
| `run_case.py prefix-invalid-layout` | 1 | Intended: Halt claim refuted for an invalid layout |
| `run_case.py statement-0001 …` | 0 | Backend instance stored; its PROPOSED statement had the wrong prefix bound (superseded) |
| `run_case.py statement-0002 …` | 0 | Corrected PROPOSED statement; fidelity check; `refund_alloc_backend_correct` |
| `run_case.py statement-repeat` | 0 | Exports byte-identical |
| `python3 -I -B verify_cases_r9.py` / two altered copies | 0 / 1 / 1 | Byte, exit and marker binding; checks the hash of the copied published proof |

Source SHA256: prefix `35114df5ab49cbc06cd0cf79cf0d0a210093e77df83acc26378cf426710bc992`,
statement `934c6ba10319e69edb773abfdd9ddcc558b98e29c67fdeffdc904648c4b08f19`.
Theory data: `forge_targetInstallPrefix` `9082b36f082bef72b2ececd2c6e88778fcbf6ff995fce44cb18a27f1f36658ec`,
`forge_refundAllocBackend` `d11421aaa82b82b6f1f546893187a328fb89c165b8141e95cb7d9388ad177ccf`.
Clean replay: NOT_RUN.

## 8. Next smallest obligation

The per-segment prefix lemma for one encoded instruction: a strengthened
`asm_step_IMP_evaluate_step` whose conclusion adds
`no_install_prefix c io l ms1`, proved from the published `encoder_correct`
(`asserts`) with `no_install_prefix_next` and `no_install_prefix_segment`.
Before it, check whether `state_rel` alone gives `get_pc ms1 ≠ install_pc`
(the clock-zero case).
