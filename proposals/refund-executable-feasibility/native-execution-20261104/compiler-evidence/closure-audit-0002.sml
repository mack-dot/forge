load "forge_refundArm8CompileTheory";
val _ = Globals.max_print_depth := 1000;
val closure = "forge_refundArm8Compile" :: Theory.ancestry "forge_refundArm8Compile";
val _ = List.app (fn n => print ("FORGE_PARENT " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n) ^ "\n")) closure;
val _ = List.app (fn n => List.app (fn (a,th) => print ("FORGE_CLOSURE_AXIOM " ^ n ^ "." ^ a ^ "\n")) (DB.axioms n)) closure;
val _ = List.app (fn theory => List.app (fn (n,th) =>
  let val (ors,axs)=Tag.dest_tag (Thm.tag th) in
    print ("FORGE_TAG " ^ theory ^ "." ^ n ^ " oracles=" ^ String.concatWith "," ors ^ " axioms=" ^ String.concatWith "," axs ^ " hypotheses=" ^ Int.toString(length(hyp th)) ^ "\n");
    if n = "refund_arm8_compiled" then print ("FORGE_STATEMENT " ^ theory ^ "." ^ n ^ " " ^ Parse.thm_to_string th ^ "\n") else ()
  end) (DB.theorems theory @ DB.definitions theory)) ["forge_refundArm8Compile"];
print "FORGE_CLOSURE_AUDIT_COMPLETE\n";
OS.Process.exit OS.Process.success;
