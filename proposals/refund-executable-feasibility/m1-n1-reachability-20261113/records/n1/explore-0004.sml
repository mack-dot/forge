(* Exploration only: can the label checks be cv-translated and evaluated on the
   pre-allocation word program?  Stores nothing that is exported. *)
load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "wordConvsTheory";
open preamble cv_transLib;
val _ = Globals.max_print_depth := 40;
fun pr s = print (s ^ "\n");
fun stamp s = pr ("STAMP " ^ s ^ " " ^ Time.toString (Time.now ()));
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_N1_OUT"));
val _ = new_theory "forge_n1Explore";
fun attempt label f = (f (); pr ("STEP_OK " ^ label)) handle ex => pr ("STEP_FAILED " ^ label ^ " :: " ^ exn_to_string ex);
val _ = pr ("TO_WORD_0_ARM8 " ^ thm_to_string backend_arm8Theory.to_word_0_arm8_def);
val _ = List.app (fn (n, th) => if String.isSubstring "to_word_0" n orelse String.isSubstring "compile_cake_arm8" n
                                  then pr ("ARM8_THM " ^ n ^ " :: " ^ thm_to_string th) else ())
          (DB.theorems "backend_arm8" @ DB.definitions "backend_arm8");
val no_label_def = Define `
  (no_label (l:num) (wordLang$Call r d a h) <=>
     (case d of SOME x => x <> l | NONE => T) /\
     (case r of SOME (_,_,x,_,_) => no_label l x | NONE => T) /\
     (case h of SOME (_,x,_,_) => no_label l x | NONE => T)) /\
  (no_label l (Seq p1 p2) <=> no_label l p1 /\ no_label l p2) /\
  (no_label l (Loop names p exit_names) <=> no_label l p) /\
  (no_label l (If _ _ _ p1 p2) <=> no_label l p1 /\ no_label l p2) /\
  (no_label l (MustTerminate p) <=> no_label l p) /\
  (no_label l (LocValue _ l1) <=> l1 <> l) /\
  (no_label l _ <=> T)`;
val _ = pr ("NO_LABEL_DEF " ^ thm_to_string no_label_def);
val _ = attempt "no_label_thm" (fn () =>
  let val th = prove (``!l p. no_label l p <=> l NOTIN wordConvs$get_code_labels p``,
      ho_match_mp_tac (theorem "no_label_ind") >> rw[no_label_def, wordConvsTheory.get_code_labels_def] >>
      rpt (TOP_CASE_TAC >> gvs[]) >> metis_tac[])
  in pr ("NO_LABEL_THM " ^ thm_to_string th) end);
val _ = stamp "before cv_trans";
val _ = attempt "cv_trans no_label" (fn () => (cv_auto_trans (INST_TYPE [alpha |-> ``:64``] no_label_def); ()));
val _ = attempt "cv_trans good_handlers" (fn () => (cv_auto_trans (INST_TYPE [alpha |-> ``:64``] wordConvsTheory.good_handlers_def); ()));
val prog_def = DB.fetch "forge_refundWholeProg" "refund_prog_def" handle _ =>
  #2 (hd (DB.find "refund_prog_def"));
val _ = stamp "before deep embedding";
val _ = attempt "deep embedding" (fn () => (Feedback.trace ("Theory.allow_rebinds", 1) (cv_trans_deep_embedding EVAL) prog_def; ()));
val c = EVAL ``arm8_config$arm8_backend_config``;
val conf_tm = rhs (concl c);
val _ = stamp "before cv_eval length";
val length_tm = ``LENGTH (SND (to_word_0_arm8 ^conf_tm refund_prog))``;
val _ = attempt "cv_eval length" (fn () => pr ("LENGTH_P0 " ^ term_to_string (rhs (concl (cv_eval length_tm)))));
val _ = stamp "after cv_eval length";
val check_def = Define `n1_check (l:num) ps = EVERY (\(n:num,m:num,pp,md:wordLang$metadata). wordConvs$good_handlers n pp /\ (n <> l ==> no_label l pp)) ps`;
val names_def = Define `n1_names (l:num) ps = MAP FST (FILTER (\(n:num,m:num,pp,md:wordLang$metadata). ~no_label l pp) ps)`;
val _ = attempt "cv_trans check" (fn () => (cv_auto_trans (INST_TYPE [alpha |-> ``:64``] check_def); cv_auto_trans (INST_TYPE [alpha |-> ``:64``] names_def); ()));
val _ = attempt "cv_eval names" (fn () => pr ("NAMES_WITH_LABEL_29 " ^ term_to_string (rhs (concl (cv_eval ``n1_names 29 (SND (to_word_0_arm8 ^conf_tm refund_prog))``)))));
val _ = attempt "cv_eval check" (fn () => pr ("CHECK_29 " ^ term_to_string (rhs (concl (cv_eval ``n1_check 29 (SND (to_word_0_arm8 ^conf_tm refund_prog))``)))));
val _ = stamp "after checks";
val _ = pr ("INSTALL_CODE " ^ thm_to_string (EVAL ``data_to_word$Install_code c``));
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
