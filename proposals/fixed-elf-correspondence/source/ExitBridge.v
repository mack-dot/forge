(* Existing LPS exit-event realization. No physical-runtime axiom or semantics. *)
From Stdlib Require Import ZArith List.
From LinuxProcessSemantics.LinuxProcessSem Require Import BvBase RiscvSemantics State Run.
From LinuxProcessSemantics.LinuxProcessSem.Checks Require Import Omni SpuriousCfg.
From LinuxProcessSemantics.EquivalenceDefinition Require Import MustExit Classifier.
Require ForgeSlice.Behavior.
Import ListNotations.
Module B := ForgeSlice.Behavior.
Module O := B.O.
Module G := B.G.

Definition fixed_behavior_and_model_exit : Prop :=
 forall rnd argv envp uid hw mem resv fcsr model,
 m_halted model = None -> m_vm_lazy model = [] ->
 option_map (fun st => bv_unsigned (ms_reg st (Z_to_bv 5 10)))
  (run_steps 15 G.loaded_segments
   (O.observed_initial_machine rnd argv envp uid hw mem resv fcsr))
 = Some (Z.gcd 1071 462) /\
 must_exit_at_cfg may_fail_cfg G.loaded_segments verdict_accept
  (mkCfg (O.observed_initial_machine rnd argv envp uid hw mem resv fcsr) model) /\
 exists tr fs final,
 star_cfg G.loaded_segments may_fail_cfg
  (mkCfg (O.observed_initial_machine rnd argv envp uid hw mem resv fcsr) model)
  (tr ++ [ExitEv verdict_accept fs]) final /\
 m_halted (cfg_model final) = Some verdict_accept.

Theorem fixed_behavior_and_model_exit_holds : fixed_behavior_and_model_exit.
Proof.
 intros rnd argv envp uid hw mem resv fcsr model Hhalt Hlazy.
 pose proof (B.observed_machine_must_exit_zero
  rnd argv envp uid hw mem resv fcsr model Hhalt Hlazy) as Hmust.
 split; [apply B.loop_result_is_fixed_pair_gcd|].
 split; [exact Hmust|].
 eapply must_exit_at_cfg_realizes; [exact Hmust|exact Hhalt].
Qed.

Set Printing Fully Qualified.
Print Assumptions fixed_behavior_and_model_exit_holds.
