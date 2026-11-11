(* written by oft check; never supplied by a pull request *)
From Stdlib Require Import QArith.
Require ForgeMemoryCandidate.MemoryIndependent.
Require ForgeMemoryCandidate.MemoryIndependent.
Definition certified : ForgeMemoryCandidate.MemoryIndependent.selftest_memory_independent_termination := ForgeMemoryCandidate.MemoryIndependent.selftest_memory_independent_termination_holds.
Set Printing Fully Qualified.
Print Assumptions certified.
