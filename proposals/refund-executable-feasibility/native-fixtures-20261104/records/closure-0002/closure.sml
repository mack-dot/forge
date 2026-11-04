load "forge_refundWireProgTheory";
val _ = Globals.max_print_depth := 1000;
val closure = "forge_refundWireProg" :: Theory.ancestry "forge_refundWireProg";
val _ = List.app (fn n => print ("FIXTURE_PARENT " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n) ^ "\n")) closure;
val _ = List.app (fn n => List.app (fn (a,th) => print ("FIXTURE_AXIOM " ^ n ^ "." ^ a ^ "\n")) (DB.axioms n)) closure;
val _ = List.app (fn (n,th) => let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  print ("FIXTURE_TAG " ^ n ^ " oracles=" ^ String.concatWith "," ors ^ " axioms=" ^ String.concatWith "," axs ^ " hypotheses=" ^ Int.toString (length (Thm.hyp th)) ^ "\n")
  end) (DB.theorems "forge_refundWireProg");
val _ = print "FIXTURE_CLOSURE_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;
