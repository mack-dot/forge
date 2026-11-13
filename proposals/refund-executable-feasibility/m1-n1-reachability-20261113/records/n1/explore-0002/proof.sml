(* Exploration only: can the label checks be cv-translated and evaluated on the
   pre-allocation word program?  Stores nothing that is exported. *)
load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "wordConvsTheory";
open HolKernel Parse boolLib bossLib cv_transLib;
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
  let val th = prove (``!l (p:'a wordLang$prog). no_label l p <=> l NOTIN wordConvs$get_code_labels p``,
      ho_match_mp_tac (theorem "no_label_ind") >> rw[no_label_def, wordConvsTheory.get_code_labels_def] >>
      rpt (TOP_CASE_TAC >> gvs[]) >> metis_tac[])
  in pr ("NO_LABEL_THM " ^ thm_to_string th) end);
val _ = stamp "before cv_trans";
val _ = attempt "cv_trans no_label" (fn () => (cv_auto_trans (INST_TYPE [alpha |-> ``:64``] no_label_def); ()));
val _ = attempt "cv_trans good_handlers" (fn () => (cv_auto_trans (INST_TYPE [alpha |-> ``:64``] wordConvsTheory.good_handlers_def); ()));
val _ = stamp "before cv_eval length";
val _ = attempt "cv_eval length" (fn () =>
  pr ("LENGTH_P0 " ^ thm_to_string (cv_eval ``LENGTH (SND (to_word_0_arm8 arm8_backend_config refund_prog))``)));
val _ = stamp "after cv_eval length";
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
