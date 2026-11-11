load "ml_translatorLib";
open preamble;
val _ = Globals.max_print_depth := 1000;
val _ = ml_translatorLib.translation_extends "forge_refundStdioProg";
val raw_decls = ml_translatorLib.get_ml_prog_state () |> ml_progLib.get_thm
  |> REWRITE_RULE [ml_progTheory.ML_code_def,ml_progTheory.ML_code_env_def];
val vars = free_vars (concl raw_decls);
val ffi_var = hd (List.filter (fn v => fst (dest_var v) = "ffi") vars);
val po_var = hd (List.filter (fn v => fst (dest_var v) = "po") vars);
val decls = raw_decls |> GEN ffi_var
  |> ISPEC ``basis_ffi$basis_ffi ext cl fs`` |> SPEC_ALL |> GEN po_var
  |> (fn th => HO_MATCH_MP basis_ffiTheory.FORALL_po_Decls th
       handle HOL_ERR _ => HO_MATCH_MP basis_ffiTheory.FORALL_po_Decls_eval th);
val _ = print ("INITIAL_DECLS " ^ Parse.thm_to_string decls ^ "\n");
val (ors,axs) = Tag.dest_tag (Thm.tag decls);
val _ = if null (hyp decls) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
 then () else raise Fail "Unexpected declaration theorem trust dependency";
val _ = print "INITIAL_DECLS_HYPOTHESES 0\nINITIAL_DECLS_TAGGED_AXIOMS 0\nDIAGNOSTIC_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;
