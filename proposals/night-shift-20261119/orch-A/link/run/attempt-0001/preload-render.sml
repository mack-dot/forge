(* DRAFT. Runs first in step H4 (and in its control NR1). Adds folders to loadPath; changes no file. *)
val dafny_dir = (case OS.Process.getEnv "CAKEMLDIR" of SOME d => d | NONE => raise Fail "Missing CAKEMLDIR") ^ "/compiler/dafny";
val _ = loadPath := dafny_dir :: (dafny_dir ^ "/forge_refund_experiment") ::
                    (dafny_dir ^ "/forge_refund_io_experiment") ::
                    (dafny_dir ^ "/forge_refundCertifiedProg_experiment") ::
                    (dafny_dir ^ "/forge_refundWireProg_experiment") :: !loadPath;
load "sexp_to_dafnyTheory";
load "forge_refundTheory";
load "forge_refundCertifiedProgTheory";
load "forge_refundWireProgTheory";
load "mlstringSyntax";
