(* A standalone checked obligation from the actual saved branch. *)
val _ = Globals.max_print_depth := 1000;
val lookup_result = Q.prove (
  ‘SOME (env,exp) = do_opapp [fv; Conv NONE []] ∧
   evaluate (st:'ffi semanticPrimitives$state) env [exp] = (st',r) ⇒
   (case do_opapp [fv; Conv NONE []] of
      NONE => (st,Rerr (Rabort Rtype_error))
    | SOME (env',e) => evaluate st env' [e]) = (st',r)’,
  strip_tac >>
  qpat_x_assum ‘SOME _ = do_opapp _’ (assume_tac o SYM) >>
  fs []);
val (ors,axs) = Tag.dest_tag (Thm.tag lookup_result);
val _ = if null (hyp lookup_result) andalso null axs andalso
  List.all (fn s => s = "DISK_THM") ors then ()
  else raise Fail "Unexpected theorem dependencies";
val _ = print ("FOCUSED_THEOREM lookup_result\n" ^ Parse.thm_to_string lookup_result ^ "\n");
val _ = print ("FOCUSED_ORACLES " ^ String.concatWith "," ors ^ "\n");
val _ = print "FOCUSED_HYPOTHESES 0\nFOCUSED_AXIOMS 0\nFOCUSED_LOOKUP_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;
