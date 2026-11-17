(* Exact lab program after the published skip filter: shared-memory count and region hypothesis, by in-logic evaluation. *)
open preamble cv_transLib backendTheory backend_asmTheory labSemTheory labLangTheory labPropsTheory lab_filterTheory
     lab_to_targetProofTheory
     forge_refundLabClosureTheory forge_refundLabResolveTheory
     forge_labRegionInvariantTheory forge_labRegionStepTheory forge_labRegionWalkTheory forge_refundLabRunTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundLabFiltered";
val line_is_sharemem_def = Define `line_is_sharemem l = case l of Asm (ShareMem _ _ _) _ _ => T | _ => F`;
val sm_count_def = Define `sm_count secs = SUM (MAP (\sec. LENGTH (FILTER line_is_sharemem (Section_lines sec))) secs)`;
val sm_secs_def = Define `sm_secs secs = MAP Section_num (FILTER (\sec. EXISTS line_is_sharemem (Section_lines sec)) secs)`;
val sm_free_def = Define `sm_free secs = EVERY (\sec. EVERY (\l. ~line_is_sharemem l) (Section_lines sec)) secs`;
val line_count_def = Define `line_count secs = SUM (MAP (\sec. LENGTH (Section_lines sec)) secs)`;
val filt_info_def = Define `filt_info c p = case lab_forge8 c p of NONE => NONE
   | SOME L => SOME (sm_count L, sm_secs L, sm_free L, line_count L,
                     sm_count (filter_skip L), sm_free (filter_skip L), line_count (filter_skip L), lab_stats (filter_skip L))`;
val filt_walk_def = Define `filt_walk ls c p = case lab_forge8 c p of NONE => F
   | SOME L => hyp_walk1 ls (filter_skip L) 0 (filter_skip L) /\ pc_ok ls (filter_skip L) 0`;
val _ = List.app (fn th => (cv_auto_trans th; ())) [line_is_sharemem_def, sm_count_def, sm_secs_def, sm_free_def, line_count_def, filt_info_def, filt_walk_def];
val prog_def = DB.fetch "forge_refundWholeProg" "refund_prog_def";
val _ = Feedback.trace ("Theory.allow_rebinds", 1) (cv_trans_deep_embedding EVAL) prog_def;
val c = EVAL ``arm8_config$arm8_backend_config``;
val c_oracle_tm = ``set_oracle ^(rhs (concl c)) refund_alloc_oracle``;
val info = cv_eval ``filt_info ^c_oracle_tm refund_prog`` |> REWRITE_RULE [GSYM c];
val _ = pr ("EVAL_INFO " ^ thm_to_string info);
val wpair = cv_eval ``filt_walk [29;31] ^c_oracle_tm refund_prog`` |> REWRITE_RULE [GSYM c];
val wsingle = cv_eval ``filt_walk [29] ^c_oracle_tm refund_prog`` |> REWRITE_RULE [GSYM c];
val _ = pr ("EVAL_WALK_PAIR " ^ thm_to_string wpair);
val _ = pr ("EVAL_WALK_SINGLE " ^ thm_to_string wsingle);
val _ = save_thm ("filt_info_eval", info);
val _ = save_thm ("filt_walk_pair_eval", wpair);
val _ = save_thm ("filt_walk_single_eval", wsingle);
val _ = export_theory ();
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
