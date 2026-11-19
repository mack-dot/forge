(* DRAFT probe H0: can the three parent theories be loaded by name in the present tree? *)
load "sexp_to_dafnyTheory";
load "forge_refundTheory";
load "forge_refundCertifiedProgTheory";
val _ = print "EXACT_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;
