(* written by oft check; never supplied by a pull request *)
From Stdlib Require Import QArith.
Require Forge.Binary.Statements.
Require Forge.Binary.Proof.
Definition certified : Forge.Binary.Statements.selftest_halts := Forge.Binary.Proof.selftest_halts_holds.
Set Printing Fully Qualified.
Print Assumptions certified.
