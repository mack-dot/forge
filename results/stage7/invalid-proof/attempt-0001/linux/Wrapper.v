(* written by oft check; never supplied by a pull request *)
From Stdlib Require Import QArith.
Require OssFuzzTheorems.zlib.checksum_fuzzer.Statements.
Require ForgeNegative.TrueCertificate.
Definition certified : OssFuzzTheorems.zlib.checksum_fuzzer.Statements.plain_halts := ForgeNegative.TrueCertificate.plain_halts_holds.
Set Printing Fully Qualified.
Print Assumptions certified.
