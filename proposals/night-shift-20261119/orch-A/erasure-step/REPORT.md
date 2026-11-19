# A11 erasure step lift (condensed by Orchestrator A; NOT RUN when written; tactics UNCHECKED)
- `erasure_step_v1.sml` (7ed5a4a5…), case ES-0001, deps = deps-L1 + E1-0003 theory, CPU 1500 s; plan `RUN_PLAN_erasure_step.md`.
- Method: one generated lemma per model definition (130 definitions; 48 `dfn'`), in file order. Worker's own estimate for a
  full pass at the first run: 10–15 %.
- Statements: W (non-vacuity witness), `Next_frame`, `NextStateARM8_frame`, branch class B1/B2, SP class; optional
  `NextStateARM8_erase` with explicit fault (`NONE`) preservation. Controls C1, C2.
- After it, to reach `targetSem$evaluate`: the clock induction with untagged branch targets; the interference side; the
  bridge from `arm8$Next` to the stored target `THE o NextStateARM8` (needs a no-fault invariant).
