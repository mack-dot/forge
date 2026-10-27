(* written by oft check; never supplied by a pull request *)
From Stdlib Require Import QArith.
Require OssFuzzTheorems.zlib.checksum_fuzzer.Statements.
Require OssFuzzTheorems.Proofs.zlib.checksum_fuzzer.plain_halts.Proof.
Definition certified : OssFuzzTheorems.zlib.checksum_fuzzer.Statements.plain_halts := OssFuzzTheorems.Proofs.zlib.checksum_fuzzer.plain_halts.Proof.plain_halts_holds.
Set Printing Fully Qualified.
Print Assumptions certified.
