# A5 FFI / fficlose / erasure (worker report, condensed by Orchestrator A; HOL NOT RUN; all tactics UNCHECKED)

- `routeA-L2_v2.sml` (4e1c1542…): tactic-only repairs. A-D1 HIGH: line 103 of the draft used `Induct >> disch_then`
  (the IH is an assumption after `Induct`); A-D2: helper lemmas RFB1, RFB2 for `read_ffi_bytearray(s)`; a non-vacuity
  control C-NV added. No statement changed.
- fficlose: the false premise is the contract conjunct of `refund_env_ok_sl` at index 2 (close) at the zero-length state.
  Real C: `basis_ffi.c:192 assert(alen >= 1)`, `:193 assert(clen == 8)`. L1+L2 remove this state by definition
  (model `ffi_close` asserts both lengths; the call is `FFI_final`). Remaining close gap: x3 with top bit set.
  Close reachability NOT proved. L3 = 15 TextIO specs to prove again with an FFI part of read and write only.
- Proposed next theorem (NOT ATTEMPTED): `ffi_calls_ok_of_returning_calls` (statement in the worker message, STATE.md).
- `erasure_v2.sml` (062a12f4…): draft defects E-D1 (8 `NO_TAC` proofs stop the file), E-D2 (no `chDir FORGE_P3_OUT`).
  Erasure alone is NOT enough: code/domain bound P-LO55 is not given (`slide_ok` admits tagged bases); data addresses
  are unconstrained; faults are hidden by `THE o NextStateARM8`; SA0 needs SP alignment.
  NATIVE assumptions (no vendor document in the repository): N-M1-TBI0, N-M1-SA0, N-M1-E0E, N-M1-EL0, N-M1-STABLE,
  N-M1-SP16, N-M1-DATA56.
- Ready: E1-0001 (`erasure_v2.sml`, no Forge parent, 600 s); L2-0001 after L1 and L1imp. Plan: `RUN_PLAN_ffi_erasure.md`.

## Correction by Orchestrator A (after review A7, 08:19Z)
The line "L1+L2 remove this state by definition" overclaims. Correct: L1+L2 move the false premise into two unproved
premises (a) the on-form contract for the real effect (NATIVE) and (b) `ffi_calls_ok Vok` at reached states (L3). See `review-L1/REPORT.md`.
