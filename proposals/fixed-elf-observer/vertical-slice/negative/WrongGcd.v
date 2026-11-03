From Stdlib Require Import ZArith.
Require ForgeSlice.Behavior.
Lemma incorrect_fixed_result : Z.gcd 1071 462 = 22%Z.
Proof. exact ForgeSlice.Behavior.fixed_pair_gcd. Qed.
