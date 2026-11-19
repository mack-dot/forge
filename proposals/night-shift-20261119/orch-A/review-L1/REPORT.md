# A7 adversarial review of L1-0001 and L1imp-0001 (condensed by Orchestrator A)
Verdict: the 16 theorems are machine-checked (same machine, cached parents). No defect breaks that.
- Integrity HOLDS: `command.json` exit 0 is the exit of the real `hol` binary; all recomputed SHA-256 equal the records.
  Gap E1: heap `cake_compile_heap` (2f5dbb71…) is not in `arm8-tool-identity.json` (only in other round-4 records).
  Gap E2: `inputs_unchanged_after` covers parent `.sig/.sml`, not parent `.dat`.
- Harness HOLDS: a failed lemma raises before `export_theory`; the tag check covers ALL stored theorems and definitions;
  only `new_definition`; 4 `bool` axioms. Weak points: axiom COUNT checked, not names; L1imp matches 9 of 16.
- Meaning (D1): L1 holds for EVERY `Vok`, also `Vok = F`. L1 + L2 do NOT remove the false fficlose premise.
  They REPLACE it by two unproved premises:
  (a) `refund_ffi_contract_on (sl + 0x1000040D0w) envmc.prog_addresses Vok envmc.ffi_interfer` (NATIVE);
  (b) `ffi_calls_ok Vok (refund_mc … (envmc with ffi_interfer := refund_ffi_tot Vok envmc.ffi_interfer)) (basis_ffi ext cl fs) k ms`
      for the reached states (L3, not attempted).
- D2: the two L1imp controls are "not aconv" checks against one mutant: weak.
- Scope: MODEL only; nothing about the real process; not a clean or independent replay.
