(* written by oft check; never supplied by a pull request *)
From Stdlib Require Import QArith.
Require Forge.Binary.WitnessSpec.
Require Forge.Binary.Witness.
Definition certified : Forge.Binary.WitnessSpec.selftest_has_valid_execution := Forge.Binary.Witness.selftest_has_valid_execution_holds.
Set Printing Fully Qualified.
Print Assumptions certified.
