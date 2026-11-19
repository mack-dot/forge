# A12 adversarial review of L2-0003 (condensed by Orchestrator A)
Verdict: L2 is MACHINE-CHECKED (same machine, cached parents). `refund_profile_a_sl_reach` is a correct restatement of the
stored `refund_profile_a_sl`: the conclusion is term-identical (`aconv`) and speaks about the REAL effect (`refund_mc B envmc`).
- Integrity HOLDS (all digests recomputed). Gap E2 as for L1 (parent `.dat` not in the input hashes).
- Harness HOLDS. No statement or definition changed between L2-0001, L2-0002, L2-0003 (quoted terms diffed).
- `ffi_calls_ok` mirrors every branch of `targetSem$evaluate` (118-216) with the same clock; SharedMem is set to F
  (conservative); this pinned CakeML has no `ccache_pc` branch.
- DEFECT in the claim, not in the proof: "more realistic premise" is NOT established. For `Vok = T` the theorem is the
  stored one (still with the false premise). For `Vok = F` premise 3 says "no FFI call ever returns": vacuous for a program
  that reads stdin. No `Vok` is shown for which all premises hold together. Non-vacuity: MISSING (needs L3 and a native
  contract check).
- Controls: the conclusion check is real; "one premise replaced by three" checks only the count; C-NV uses a toy record.
- L2b-0001 (exit 1) ran with a LOCAL copy of `ffi_calls_ok` (`D3_SOURCE local`): even proved it would not discharge the
  premise of L2R. It must import the L2-0003 theory. Its `closeP` is not the `Vok` that L3 needs (VokY3 sets close and
  open_in to F: L3 must show that no close or open_in call ever RETURNS on the run).
- L3 target: stored premises with `refund_env_ok_sl` replaced by `interference_ok` and `contract_on Vok` imply
  `∀ms k. arm8_run 27 s = SOME ms ⇒ ffi_calls_ok Vok (refund_mc B envT) (basis_ffi ext cl fs) k ms`.
