(* Auxiliary consequences of the existing LPS model. No accepted claim change. *)
From Stdlib Require Import ZArith List.
From LinuxProcessSemantics.LinuxProcessSem Require Import
  BvBase MemImageType RiscvSemantics State Run OmniRun.
From LinuxProcessSemantics.LinuxProcessSem.Checks Require Import
  Examples Omni SpuriousCfg.
From LinuxProcessSemantics.EquivalenceDefinition Require Import MustExit Classifier.
Require ForgeObserved.ObservedTransitions.
Import ListNotations.
Module O := ForgeObserved.ObservedTransitions.
Module G := O.G.

Lemma fixed_pair_gcd : Z.gcd 1071 462 = 21%Z.
Proof. vm_compute. reflexivity. Qed.

(* Inspect the actual instruction semantics, not candidate trace assertions.
   The four pairs are the loop inputs and the three completed iterations. *)
Lemma exact_loop_pairs : forall rnd argv envp uid hw mem resv fcsr,
  map (fun k => option_map
    (fun st => (bv_unsigned (ms_reg st (Z_to_bv 5 10)),
                bv_unsigned (ms_reg st (Z_to_bv 5 11))))
    (run_steps k G.loaded_segments
      (O.observed_initial_machine rnd argv envp uid hw mem resv fcsr)))
    [2; 6; 10; 14]%nat
  = [Some (1071%Z,462%Z); Some (462%Z,147%Z);
     Some (147%Z,21%Z); Some (21%Z,0%Z)].
Proof. intros. vm_compute. reflexivity. Qed.

Lemma loop_result_is_fixed_pair_gcd : forall rnd argv envp uid hw mem resv fcsr,
  option_map (fun st => bv_unsigned (ms_reg st (Z_to_bv 5 10)))
    (run_steps 15 G.loaded_segments
      (O.observed_initial_machine rnd argv envp uid hw mem resv fcsr))
  = Some (Z.gcd 1071 462).
Proof. intros. vm_compute. reflexivity. Qed.

(* Hidden reservation and FCSR values do not need to be reconstructed to apply
   this model theorem. Concrete/abstract process-state correspondence is still
   an external obligation. Preserve both Model premises explicitly. *)
Theorem observed_machine_must_exit_zero :
  forall rnd argv envp uid hw mem resv fcsr model,
    m_halted model = None -> m_vm_lazy model = [] ->
    must_exit_at_cfg may_fail_cfg G.loaded_segments verdict_accept
      (mkCfg (O.observed_initial_machine rnd argv envp uid hw mem resv fcsr) model).
Proof.
  intros rnd argv envp uid hw mem resv fcsr model Hhalt Hlazy.
  apply (exits_c_must_exit_at_cfg _ _ _ 128);
    [exact Hhalt | exact Hlazy |].
  vm_compute. reflexivity.
Qed.

Print Assumptions observed_machine_must_exit_zero.
