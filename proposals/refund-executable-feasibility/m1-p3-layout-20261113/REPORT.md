# U381: layout invariant established; corrected strengthened statement; simulation cases not run

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted and not used. Nothing committed.
Local results: same machine, same agent, cached parents.

## 1. Corrected strengthened `compile_correct`: PROPOSED, NOT PROVED

```
∀s1 res mc_conf s2 code2 labs t1 ms1.
  (oracle_tie mc_conf ms1 s1 ∧ evaluate s1 = (res,s2) ∧ res ≠ Error ∧
   encoder_correct mc_conf.target ∧ state_rel (mc_conf,code2,labs,p) s1 t1 ms1) ∧
  (∀k r t. evaluate (s1 with clock := k) = (r,t) ⇒
           ∀i bs n. asm_fetch t ≠ SOME (LabAsm Install i bs n)) ∧
  code_layout_ok (:α) code2 ⇒
  ∃k t2 ms2.
    evaluate mc_conf s1.ffi (s1.clock + k) ms1 = (res,ms2,s2.ffi) ∧
    no_install_prefix mc_conf s1.ffi (s1.clock + k) ms1
```

Machine check (exit 0): removing the three additions gives exactly the
published statement. It replaces the U378 form, which U380 showed to be
unprovable as written.

## 2. Layout invariant: PROVED (theory `forge_simLayout`)

Smallest sufficient condition, a static property of the encoded program:

`code_layout_ok (:α) code2 ⇔ LENGTH (prog_to_bytes code2) + 2 * ffi_offset < dimword (:α)`

- `state_rel_no_install_prefix_layout`:
  `state_rel (mc_conf,code2,labs,p) s1 t1 ms1 ∧ code_layout_ok (:α) code2 ⇒ no_install_prefix mc_conf ffi 0 ms1`.
  It holds for every lab state `s1` and every related target state `ms1`. It
  uses the published `pos_val_bound` (the code offset of any lab counter is
  at most the encoded length, from the `all_enc_ok` clause of `state_rel`)
  and `install_entry_distinct` (U380).
- `installed_bound_code_layout`:
  `cbspace + LENGTH (prog_to_bytes code2) + ffi_offset * (i + 3) < dimword (:α) ⇒ code_layout_ok (:α) code2`.
  The antecedent is the bound that the published `installed` and
  `semantics_compile` state.

Initialization and preservation:

| Question | Answer | Status |
| --- | --- | --- |
| Initial state | The bound follows from the bound clause of `installed` | PROVED as arithmetic. The identification of `bytes` with `prog_to_bytes code2` is made inside the published `semantics_compile` proof and is not re-proved here |
| Preservation along a lab run (ordinary steps, branches, returns, FFI) | The condition does not mention the state. It is unchanged while `code2` is unchanged. Only the `Install` line changes the code, and the lab premise excludes it | Holds by form of the statement |
| Lab-aligned target states | Off the installer entry, for every related pair | PROVED |
| Intermediate target states inside one lab step | Not covered by the layout bound. They need the per-segment lemmas | NOT_RUN |
| Word arithmetic and wraparound | The bound is over natural numbers below `dimword`; the 8-bit wrap example (`install_entry_wrap_example`, U380) is kept and re-read in the import | Negative control kept |

`installed` is not assumed to give the bound at intermediate target states:
the bound is about the code, and the per-state fact is the theorem above for
related states only.

## 3. Strengthened step lemma, per-segment lemmas, nine cases: NOT_RUN

Not attempted in this run. This is a limit of the session, not a proof
blocker found. Structure read from the published script: the single-
instruction lemma `asm_step_IMP_evaluate_step_nop` (line 247) is derived from
`asm_step_IMP_evaluate_step_find_next`. That root lemma is the place for the
per-segment statement about intermediate counters.

| Simulation case | Status |
| --- | --- |
| `Asm`, `ShareMemOp`, `Jump`, `JumpCmp`, `Call`, `LocValue`, `CallFFI`, `Install`, `Halt` | NOT_RUN (all nine) |

## 4. Other items

- Backend chain for `refund_alloc_oracle`: unchanged since U378 (first link
  proved; the rest NOT_RUN).
- Target-level installer exclusion (U298): NOT ESTABLISHED.
- Installed-state obligations: all six OPEN.

## 5. Executed commands

Run directory: `results/refund-p3-layout-local-20261113/attempt-0001`.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `run_case.py explore-0001 …` | 0 | Both lemmas proved in the goal manager |
| `python3 -I -B run_case.py layout-0001 layout-0001.sml …` | 0 | Two theorems, first attempt; corrected statement printed; fidelity check |
| `run_case.py layout-import` | 0 | Three exact statements (definition included), 295 closure nodes; statement control; wrap example re-read |
| `run_case.py layout-repeat` | 0 | Exports byte-identical |

Source SHA256 `d48f3001838032934aa39f14af4f290c461d696406f7c736a616bd3b6c8ac07d`;
theory data `9e934bbc1608279d39d566fe985460fddd50d7759f9bd723cab62d861f867683`.
No separate evidence reader; `MANIFEST.json` lists every member. Clean
replay: NOT_RUN.

## 6. Next smallest obligation

A strengthened `asm_step_IMP_evaluate_step_find_next`: add to its conclusion
`no_install_prefix c io l ms1`, from the published `encoder_correct` with
`no_install_prefix_next` and `no_install_prefix_segment` (U377) and
`install_pc ∉ prog_addresses`.
