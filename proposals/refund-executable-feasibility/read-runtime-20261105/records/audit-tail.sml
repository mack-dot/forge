val checks = [
  ("read_ready",expected_read_ready,forge_refundReadBoundaryTheory.read_ready),
  ("ffi_read_ready",expected_ffi_read_ready,forge_refundReadBoundaryTheory.ffi_read_ready),
  ("ffi_read_ready_status",expected_ffi_read_ready_status,forge_refundReadBoundaryTheory.ffi_read_ready_status),
  ("ffi_read_unavailable",expected_ffi_read_unavailable,forge_refundReadBoundaryTheory.ffi_read_unavailable)];
val _ = Globals.max_print_depth := 1000;
fun check (name,expected,th) =
  let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
    if aconv expected (concl th) then ()
    else raise Fail ("Exact statement mismatch: " ^ name);
    if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
    then () else raise Fail ("Unexpected dependency: " ^ name);
    print ("IMPORTED_THEOREM " ^ name ^ "\n" ^ Parse.thm_to_string th ^ "\n");
    print ("IMPORTED_ORACLES " ^ String.concatWith "," ors ^ "\n");
    print "IMPORTED_HYPOTHESES 0\nIMPORTED_TAGGED_AXIOMS 0\n"
  end;
val _ = List.app check checks;
val _ = if length (DB.theorems "forge_refundReadBoundary") = 4
  then () else raise Fail "Unexpected theorem count";
val closure = "forge_refundReadBoundary" :: Theory.ancestry "forge_refundReadBoundary";
val _ = List.app (fn name => print ("CLOSURE_NODE " ^ name ^ ":" ^
  String.concatWith "," (Theory.parents name) ^ "\n")) closure;
val _ = List.app (fn name => List.app (fn (a,_) =>
  print ("CLOSURE_AXIOM " ^ name ^ "." ^ a ^ "\n")) (DB.axioms name)) closure;
val _ = print "EXACT_EXPECTED_STATEMENTS true\n";
