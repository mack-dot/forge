From Stdlib Require Import List.
From LinuxProcessSemantics.EquivalenceDefinition Require Import Classifier.
From OssFuzzTheorems.Core Require Import Shapes.
From Forge.Binary Require Images.
Import ListNotations.

(* For every valid modeled process input and entry, every execution of this
   exact self-test terminates with status 0, even under the may-fail environment.
   The numerical inputs are the fixed pair embedded in the executable. *)
Definition selftest_halts : Prop :=
  halts_may_fail [verdict_accept] Images.program.
