(* Deliberately invalid control. The known proof of True cannot establish the
   pinned zlib binary's halts statement. This file must never be accepted. *)
Require OssFuzzTheorems.zlib.checksum_fuzzer.Statements.

Theorem plain_halts_holds :
  OssFuzzTheorems.zlib.checksum_fuzzer.Statements.plain_halts.
Proof.
  exact I.
Qed.
