# A18 adversarial review of L2b-0003 and PX-0001 (condensed by Orchestrator A)
## L2b-0003 (28 theorems): MACHINE-CHECKED; integrity and harness HOLD
- `refund_l2r_third_premise_close` is exactly premise 3 of `refund_profile_a_sl_reach` with `Vok := closeP`
  (`λi nb s. i = 2 ⇒ s.REG 1w = 8w ∧ s.REG 3w ≠ 0w`): same constant, same totalised record, same `basis_ffi ext cl fs`.
- The changed control (L2b-0002 → L2b-0003) is weak but not vacuous; the real guarantee is that the premise term is
  fetched from the stored theorem.
- DEFECT IN THE MEANING: with `Vok = closeP`, premise 2 (`refund_ffi_contract_on … closeP envmc.ffi_interfer`) is FALSE for
  the real C. Concrete state: index 0 (read), REG1 = 0 (configuration length 0), REG3 = 4. The basis oracle RETURNS an
  error byte there (fsFFIScript.sml:313, 323); the real C aborts (`basis_ffi.c:161 assert(clen == 8)`); the same for
  read/write with a short array (164, 180) and open_in with 0 < alen < 9 (139).
- So after tonight NO `Vok` has all premises of `refund_profile_a_sl_reach` proved or plausible:
  `Vok = F`: premise 3 false. `Vok = closeP`: premise 2 false. Best candidate VokY3 (exact argument shapes of the
  program's read and write calls; close and open_in never return): proved for it: R5 (`ffi_calls_ok_of_valid_events`).
  REMAINING: R3 (no top bit from the domain size), R4 (valid event ⇒ VokY3), R6 = L3 (every event of every run is a valid
  read/write event: TextIO re-proofs), R7 assembly; and NATIVE A-FD0-READ, A-FD1-WRITE for premise 2.
## PX-0001 (9 theorems): MACHINE-CHECKED; all items HOLD
- `refund_strict_parse_exact` agrees with the definition; `refund_frame_decision` is the right consumer statement against
  truncation. Not covered: Python parser = HOL parser (TESTED-UNPROVED); real stdout ≼ model render (X8/X9); A-LOADER.
