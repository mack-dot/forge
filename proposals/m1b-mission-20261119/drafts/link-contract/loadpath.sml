(* DRAFT. Optional first file for the U294 replays R1 to R3 and the import I1, used ONLY if probe H0
   shows that `load` by name fails without it. It keeps the three U294 scripts byte-unchanged. *)
val dafny_dir = (case OS.Process.getEnv "CAKEMLDIR" of SOME d => d | NONE => raise Fail "Missing CAKEMLDIR") ^ "/compiler/dafny";
val _ = loadPath := dafny_dir :: (dafny_dir ^ "/forge_refund_experiment") ::
                    (dafny_dir ^ "/forge_refundCertifiedProg_experiment") :: !loadPath;
