From Stdlib Require Import ZArith List.
From LinuxProcessSemantics.LinuxProcessSem Require Import BvBase State Run.
From LinuxProcessSemantics.LinuxProcessSem.Checks Require Import Examples.
From LinuxProcessSemantics.EquivalenceDefinition Require Import Equivalence.
From Forge.Binary Require Images Statements Proof WitnessSpec.
Import ListNotations.

Definition witness_input : ProcInput :=
  mkProcInput [[]] [] [] IEof demo_uid demo_gid demo_groups net_silent
    default_nofile (Z_to_bv 64 0) demo_hwcap false Sv48.

Lemma witness_input_valid : valid_input witness_input.
Proof. exact demo_input_valid. Qed.

Theorem selftest_has_valid_execution_holds : WitnessSpec.selftest_has_valid_execution.
Proof.
  pose proof witness_input_valid as Hv.
  destruct (image_brk_satisfiable_entry Images.program witness_input Hv
    (proj2 (proj2 Images.program_wf))) as [en Hen].
  exists witness_input, en. split; [exact Hv |].
  split; [exact Hen |].
  exact (Proof.selftest_halts_holds en witness_input Hen Hv).
Qed.
