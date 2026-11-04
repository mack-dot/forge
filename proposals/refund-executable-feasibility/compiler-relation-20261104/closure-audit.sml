load "forge_refund_compileTheory";
val closure = "forge_refund_compile" :: Theory.ancestry "forge_refund_compile";
val _ = List.app (fn n => print ("FORGE_PARENT " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n) ^ "\n")) closure;
val _ = List.app (fn n => List.app (fn (a,th) => print ("FORGE_CLOSURE_AXIOM " ^ n ^ "." ^ a ^ "\n")) (DB.axioms n)) closure;
val _ = List.app (fn (n,th) => let val (ors,axs)=Tag.dest_tag (Thm.tag th) in print ("FORGE_TAG " ^ n ^ " oracles=" ^ String.concatWith "," ors ^ " axioms=" ^ String.concatWith "," axs ^ " hypotheses=" ^ Int.toString(length(hyp th)) ^ "\n"); print ("FORGE_STATEMENT " ^ n ^ " " ^ Parse.thm_to_string th ^ "\n") end) (DB.theorems "forge_refund_compile");
OS.Process.exit OS.Process.success;
