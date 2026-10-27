(* Uses the published LPS soundness theorem to establish termination of every
   modeled execution, rather than merely a finite test trace. *)
From Stdlib Require Import ZArith List.
From LinuxProcessSemantics.LinuxProcessSem Require Import BvBase MemImageType State Run.
From LinuxProcessSemantics.LinuxProcessSem.Checks Require Import SpuriousCfg.
From LinuxProcessSemantics.EquivalenceDefinition Require Import MustExit HaltsAllowed Classifier.
From OssFuzzTheorems.Core Require Import Shapes.
From Forge.Binary Require Statements Images Execution.
Import ListNotations.

Theorem selftest_halts_holds : Statements.selftest_halts.
Proof.
  unfold Statements.selftest_halts.
  intros [sp brk0 mbase rnd] inp _ _.
  unfold Images.program. cbn [must_exit_in_scfg].
  apply must_exit_in_at_cfg_singleton. unfold init_config.
  apply (exits_c_must_exit_at_cfg _ _ _ 128);
    [reflexivity | reflexivity | apply Execution.selftest_exits_c].
Qed.
