(* Local feasibility proposal. No accepted software claim or policy change. *)
From Stdlib Require Import ZArith List.
From LinuxProcessSemantics.LinuxProcessSem Require Import
  BvBase MemImageType RiscvSemantics State Run OmniRun.
From LinuxProcessSemantics.LinuxProcessSem.Checks Require Import
  Examples Omni SpuriousCfg.
From LinuxProcessSemantics.EquivalenceDefinition Require Import
  MustExit Classifier.
From Forge.Binary.images Require Program.
Import ListNotations.
Module G := Program.M.

Lemma selftest_exits_c_any_data_memory : forall sp rnd argv envp uid hw mem,
  exits_c G.loaded_segments verdict_accept 128
    (with_mem
      (init_machine_state G.loaded_segments G.init_pc G.phdrs
        sp rnd argv envp uid hw) mem) = true.
Proof. intros. vm_compute. reflexivity. Qed.

Definition selftest_memory_independent_termination : Prop :=
  forall sp rnd argv envp uid hw mem model,
    m_halted model = None ->
    m_vm_lazy model = [] ->
    must_exit_at_cfg may_fail_cfg G.loaded_segments verdict_accept
      (mkCfg
        (with_mem
          (init_machine_state G.loaded_segments G.init_pc G.phdrs
            sp rnd argv envp uid hw) mem)
        model).

Theorem selftest_memory_independent_termination_holds :
  selftest_memory_independent_termination.
Proof.
  unfold selftest_memory_independent_termination.
  intros sp rnd argv envp uid hw mem model Hh Hlazy.
  apply (exits_c_must_exit_at_cfg _ _ _ 128);
    [exact Hh | exact Hlazy | apply selftest_exits_c_any_data_memory].
Qed.
