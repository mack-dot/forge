(* Adapted from the published MIT-licensed tests/proofs/lib/Exit0Run.v.
   The existing LPS checker processes Forge's compiler-produced image. *)
From Stdlib Require Import ZArith List.
From LinuxProcessSemantics.LinuxProcessSem Require Import
  BvBase MemImageType RiscvSemantics State Run OmniRun.
From LinuxProcessSemantics.LinuxProcessSem.Checks Require Import Examples Omni.
From LinuxProcessSemantics.EquivalenceDefinition Require Import MustExit Classifier.
From Forge.Binary.images Require Program.
Import ListNotations.

Module G := Program.M.

Lemma selftest_exits_c : forall sp rnd argv envp uid hw,
  exits_c G.loaded_segments verdict_accept 128
    (init_machine_state G.loaded_segments G.init_pc G.phdrs sp rnd argv envp uid hw)
  = true.
Proof.
  intros. rewrite (with_mem_eta (init_machine_state _ _ _ _ _ _ _ _ _)).
  generalize (ms_mem (init_machine_state G.loaded_segments G.init_pc G.phdrs
                        sp rnd argv envp uid hw)).
  intros mem. vm_compute. reflexivity.
Qed.
