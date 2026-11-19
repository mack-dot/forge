# A31 adversarial review of EE-0001 and R6base-0001 (condensed by Orchestrator A)
Verdict: EE-0001 HOLDS. R6base-0001 HOLDS with limits on what it shows. No defect breaks either run.
- Integrity and harness HOLD (193 and 199 parent files re-hashed incl. `.dat`; EE `.sig` = 101 PROVED names + `NX_def`; all in
  the tag check; R6base 11 = 11). Weakness as before: `input_sha256` has no `.dat`.
- `NextStateARM8_erase` is the E1-0003 text word for word. It is ∀s and unfolds the whole step, so no instruction class can
  be a counterexample in the model. Confirmed by reading: fetch reads flat memory (a tagged PC is fine); every branch kind
  sets PC only through `BranchTo`; `CheckSPAlignment` runs once on the pre-state SP; `write'SP` checks nothing; MRS/MSR,
  ERET, SVC, HVC, SMC raise UNDEFINED in the model.
- MISSING: non-vacuity for an interesting state (TBI0 or SA0 SET and a non-fault step): no stored fact.
- What remains to use it: the stored target is `THE o NextStateARM8` and `arm8_ok` demands the bits clear; `arm8_proj`
  contains the registers, so real and erased states project differently; at a fault `THE NONE` is unconstrained: the lift
  needs "the erased run never faults"; per step: EL0, no exception, PC in the code region (no stored theorem), SP aligned
  (CakeML avoids register 31: unchecked for start-up code); both interference functions must commute with `erase`.
  NATIVE facts: N1 the OS keeps EL0, E0E = 0 and the three bits fixed; N2 SP_EL0 16-aligned and kept by system calls;
  N3 data addresses untagged (the model's memory ignores tags; hardware strips them); N4 every executed instruction is in
  the subset where the model matches hardware (the model is unfaithful for MRS and SVC at EL0); N5 code and data mapped
  at untagged addresses.
- R6base: `replay_cannot_exclude_error_return_events` refutes exactly "∀io. replay equation ⇒ every event valid". Its bad
  event has an EMPTY configuration: a trace only of a program that calls read so. A stronger bad event (configuration
  `n2w8 0`, short array) should also be replay-neutral: UNCHECKED. `every_clock_events` applies to behaviours inside
  `extend_with_resource_limit {Terminate Success io}` with a fixed ffi.
