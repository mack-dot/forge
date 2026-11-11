val checks = [
  ("exception_event_witness",expected_event_witness,
    forge_refundRejectCompiledTheory.exception_event_witness),
  ("refund_error_compiled_precise",expected_compiled,
    forge_refundRejectCompiledTheory.refund_error_compiled_precise)];
val _ = Globals.max_print_depth := 1000;
val _ = List.app (fn (name,expected,th) =>
  let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
    if aconv expected (concl th) then ()
    else raise Fail ("Exact statement mismatch: " ^ name);
    if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
    then () else raise Fail ("Unexpected dependency: " ^ name);
    print ("IMPORTED_THEOREM " ^ name ^ "\n" ^ Parse.thm_to_string th ^ "\n");
    print ("IMPORTED_ORACLES " ^ String.concatWith "," ors ^ "\n");
    print "IMPORTED_HYPOTHESES 0\nIMPORTED_TAGGED_AXIOMS 0\n"
  end) checks;
val _ = if length (DB.theorems "forge_refundRejectCompiled") = 2
  then () else raise Fail "Unexpected theorem count";
val closure = "forge_refundRejectCompiled" :: Theory.ancestry "forge_refundRejectCompiled";
val _ = List.app (fn name => print ("CLOSURE_NODE " ^ name ^ ":" ^
  String.concatWith "," (Theory.parents name) ^ "\n")) closure;
val _ = List.app (fn name => List.app (fn (a,_) =>
  print ("CLOSURE_AXIOM " ^ name ^ "." ^ a ^ "\n")) (DB.axioms name)) closure;
val _ = print "EXACT_EXPECTED_STATEMENTS true\nERROR_COMPILER_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;
