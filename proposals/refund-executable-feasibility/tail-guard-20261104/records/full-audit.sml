loadPath := "/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundCfGap_experiment/.hol/objs" :: !loadPath;
load "forge_refundEntryTheory";
load "forge_refundCfGapTheory";
val own = ["forge_refundGuard","forge_refundEntry","forge_refundCfGap"];
val closure = Lib.mk_set (List.concat (map (fn n => n :: Theory.ancestry n) own));
val _ = List.app (fn n => print ("FORGE_PARENT " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n) ^ "\n")) closure;
val _ = List.app (fn n => List.app (fn (a,th) => print ("FORGE_CLOSURE_AXIOM " ^ n ^ "." ^ a ^ "\n")) (DB.axioms n)) closure;
val _ = List.app (fn thy => List.app (fn (n,th) => let val (ors,axs)=Tag.dest_tag (Thm.tag th) in print ("FORGE_TAG " ^ thy ^ "." ^ n ^ " oracles=" ^ String.concatWith "," ors ^ " axioms=" ^ String.concatWith "," axs ^ " hypotheses=" ^ Int.toString(length(hyp th)) ^ "\n"); print ("FORGE_STATEMENT " ^ thy ^ "." ^ n ^ " " ^ Parse.thm_to_string th ^ "\n") end) (DB.theorems thy)) own;
OS.Process.exit OS.Process.success;
