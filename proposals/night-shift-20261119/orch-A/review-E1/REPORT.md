# A10 adversarial review of E1-0003 (condensed by Orchestrator A)
Verdict: no false theorem; no harness hole. 18 theorems MACHINE-CHECKED (same machine, cached parents).
- Integrity HOLDS: all 128 recorded inputs re-hashed, 0 mismatches; E1-0002 → E1-0003 differs only in line 31 (`wordsTheory`).
- Mutant E1neg-0001 (premise `untagged t` deleted): actual exit 1, `LEMMA_FAILED BranchTo_erase_untagged`, no export. As required.
  N1a is a stored theorem that refutes the mutant in logic.
- D1 (minor): `CONTROL_OK` checks only the shape of N2 and N4 (proof.sml:255, 257); the negative content is in the stored theorems.
- D2 (scope): nothing lifts the result to one `NextStateARM8` step, to `targetSem$evaluate`, or to the environment
  conditions (`interference_ok`, `ffi_interfer_ok`; `arm8_proj` contains SCTLR_EL1 and TCR_EL1). `arm8_target_real` would
  use `arm8$Next`, another target than the stored theorem's `THE o NextStateARM8`: a bridge is MISSING.
- D3 (wording): the premises are TRADED, not removed: TBI/SA0 become `untagged`/lo55, an SP-alignment or fault disjunct,
  ¬E0E (N3: cannot be erased), and A-INT.
- By reading arm8Script.sml: TBI0/TBI1 are read only in BranchTo; SA0 only in CheckSPAlignment; no instruction writes
  TCR_EL1, SCTLR_EL1 or PSTATE.EL. So the step statements are plausible. NOT PROVED.
- Next runs proposed: a witness theorem (non-vacuity), then `Next_frame`.
