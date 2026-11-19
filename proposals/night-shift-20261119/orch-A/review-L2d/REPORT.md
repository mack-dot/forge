# A27 adversarial review of L2d-0001 and MG-0001 (condensed by Orchestrator A)
Verdict: both MACHINE-CHECKED at MODEL level; no soundness defect; one wording defect.
- Integrity and harness HOLD (147 input digests, 215 parent files; 29 = 29 and 5 = 5 names; lists empty). The composed
  theorem `refund_model_frame_decision_shape` is an OPTIONAL lemma of the script: cite its CHECKED line (L2d-0001 stdout
  556), not only the exit code.
- `refund_profile_a_sl_shape` = `refund_profile_a_sl_reach` at `Vok := VokS` with exactly the `ffi_calls_ok` conjunct
  removed and nothing added (12 conjuncts; conclusion identical). `refund_ffi_calls_ok_shape_totalised` has no premise;
  `ext` is never reached for the four names; no `wfFS` needed.
- VokS is EXACT by reading the oracle (returns ⇔ shape): the direction "returns ⇒ shape" is machine-checked; the
  direction "shape ⇒ returns" is only read and tested by concrete controls.
- What the remaining premise means: `envmc.ffi_interfer` maps (index, bytes chosen by the oracle, machine state) to the
  next machine state. The premise constrains only that state update (bytes written into the array, return to x30,
  callee-saved registers). That the real C code produces the oracle's bytes, and that the real effect is that
  `ffi_interfer`, are SEPARATE assumptions inside X8 (process refines model).
- WORDING: "the premise is false for the present C code" is loose. Precise: the premise is satisfiable in the model
  (`remaining_premise_met_by_the_abstract_effect`); NO `envmc` that describes the original C can satisfy it, because the C
  aborts at shape-valid states where the model returns an error byte. This blocks the original executable only because the
  premise quantifies over ALL stub states, including states the refund run never reaches; it does not show that the real
  run misbehaves. Restricting to reached states is the VokY3 + R6 route.
- MG-0001: G1 and G2 hold; both visibly conditional on R6 and on the contract at VokY3-valid calls.
