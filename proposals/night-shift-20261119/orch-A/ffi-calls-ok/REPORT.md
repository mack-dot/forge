# A8 L2b `ffi_calls_ok_of_returning_calls` (condensed by Orchestrator A; HOL NOT RUN at the time of this note)
- `routeA-L2b.sml` (c2a69ae1…): 19 required theorems; defines `ffi_calls_ok` locally (verbatim text of L2) when the L2 theory
  is not loaded; line `D3_SOURCE` says which mode ran. In local mode a re-run after L2 exports is needed before composition.
- Statement defect found: the close instance WITHOUT premises is FALSE (control N2': an oracle that always returns, close
  with x3 = 0). Repaired: premises target = arm8_target, len regs 1/3, names ExtCall, EL 2 = close, oracle = basis.
- Defect in Y3's event predicate: HOL `ZIP` truncates; add `LENGTH nb = LENGTH ab` (control N4).
- Remaining for the real `Vok` (statements R1–R7 type-check only): oracle alone R1, R2; machine record R3; arrays R4;
  bridge R5; PROGRAM BEHAVIOUR R6 (every event of every run is a valid read/write event) = L3, needs the TextIO re-proofs.
