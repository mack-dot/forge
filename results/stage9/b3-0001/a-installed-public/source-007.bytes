From Stdlib Require Import List.
From LinuxProcessSemantics.LinuxProcessSem Require Import State Run.
From LinuxProcessSemantics.EquivalenceDefinition Require Import MustExit Classifier.
From Forge.Binary Require Images.
Import ListNotations.

(* A real member of the same domain used by selftest_halts, together with
   its universally terminating modeled execution. *)
Definition selftest_has_valid_execution : Prop :=
  exists (inp : ProcInput) (en : ExecEntry),
    valid_input inp /\ valid_entry Images.program en inp /\
    must_exit_in_scfg may_fail_cfg [verdict_accept] Images.program
      source_alloc_limit en inp.
