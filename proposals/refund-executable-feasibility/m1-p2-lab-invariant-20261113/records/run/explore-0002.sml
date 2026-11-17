load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "labPropsTheory"; load "wordConvsTheory"; load "labSemTheory";
open preamble cv_transLib backendTheory backend_asmTheory labSemTheory labLangTheory
     forge_refundLabClosureTheory forge_refundLabResolveTheory
     forge_labRegionInvariantTheory forge_labRegionStepTheory forge_labRegionWalkTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.whole (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_RUN_OUT"));
val _ = new_theory "forge_runExplore";
(* First-order, executable instances of line_ok and hyp_walk: okp := pc_ok ls whole, resolver := loc_pc on whole. *)
val line_ok1_def = Define `
  line_ok1 (ls:num list) whole (pc:num) line =
    case line of
      Asm (Asmi (Inst _)) _ _ => pc_ok ls whole (pc + 1)
    | Asm (Asmi _) _ _ => T
    | Asm (ShareMem _ _ _) _ _ => pc_ok ls whole (pc + 1)
    | LabAsm Halt _ _ _ => T
    | LabAsm (LocValue r (Lab n1 n2)) _ _ _ => (case loc_pc n1 n2 whole of NONE => T | SOME p => pc_ok ls whole p) /\ pc_ok ls whole (pc + 1)
    | LabAsm (Jump (Lab n1 n2)) _ _ _ => (case loc_pc n1 n2 whole of NONE => T | SOME p => pc_ok ls whole p)
    | LabAsm (JumpCmp _ _ _ (Lab n1 n2)) _ _ _ => (case loc_pc n1 n2 whole of NONE => T | SOME p => pc_ok ls whole p) /\ pc_ok ls whole (pc + 1)
    | LabAsm (Call _) _ _ _ => F
    | LabAsm Install _ _ _ => F
    | LabAsm (CallFFI _) _ _ _ => T
    | Label _ _ _ => T`;
val hyp_walk1_def = Define `
  (hyp_walk1 ls whole (pc:num) [] = T) /\
  (hyp_walk1 ls whole pc ((Section k [] md)::xs) = hyp_walk1 ls whole pc xs) /\
  (hyp_walk1 ls whole pc ((Section k (y::ys) md)::xs) =
     if is_Label y then hyp_walk1 ls whole pc ((Section k ys md)::xs)
     else (pc_ok ls whole pc ==> line_ok1 ls whole pc y) /\ hyp_walk1 ls whole (pc + 1) ((Section k ys md)::xs))`;
val walk_check_def = Define `walk_check ls c p = case lab_forge8 c p of NONE => F | SOME L => hyp_walk1 ls L 0 L /\ pc_ok ls L 0`;
val line1_goal = ``!line pc. line_ok1 ls whole pc line = line_ok (pc_ok ls whole) (\n1 n2. loc_to_pc n1 n2 whole) pc line``;
val walk1_goal = ``!ls whole pc secs. hyp_walk1 ls whole pc secs = hyp_walk (pc_ok ls whole) (\n1 n2. loc_to_pc n1 n2 whole) pc secs``;
val L_tm = ``SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val ls_tm = ``[Install_location; InstallData_location]``;
val hyp_L_goal = ``region_hyp (loc_good (pc_ok ^ls_tm ^L_tm) ^L_tm) (pc_ok ^ls_tm ^L_tm) ^L_tm /\ pc_ok ^ls_tm ^L_tm 0``;
val run_L_goal = ``!s k res t.
   s.code = ^L_tm /\ val_inv (loc_good (pc_ok ^ls_tm ^L_tm) ^L_tm) s /\ pc_ok ^ls_tm ^L_tm s.pc /\
   evaluate (s with clock := k) = (res,t) ==>
   pc_ok ^ls_tm ^L_tm t.pc /\ t.code = ^L_tm /\ val_inv (loc_good (pc_ok ^ls_tm ^L_tm) ^L_tm) t /\
   (!i bs n. asm_fetch t <> SOME (LabAsm Install i bs n))``;
open proofManagerLib;
fun goals_now () = (top_goals ()) handle _ => [];
fun proved () = ((top_thm (); true) handle _ => false);
fun clip s = if size s > 1300 then String.substring (s, 0, 500) ^ "\n  ...\n" ^ String.substring (s, size s - 700, 700) else s;
fun goal_string (asl, w) = String.concatWith "\n" (map (fn a => "  ASM " ^ term_to_string a) asl) ^ "\n  GOAL " ^ term_to_string w;
fun show label = (pr ("AFTER " ^ label ^ ": " ^ Int.toString (length (goals_now ())) ^ " goals, proved=" ^ Bool.toString (proved ()));
                  List.app (fn gl => pr (clip (goal_string gl) ^ "\n----")) (List.take (goals_now (), Int.min (2, length (goals_now ())))));
(* Run stages in order on the top goal; stop at the first failure. Returns the theorem if proved. *)
fun run name goal stages =
  let val _ = (proofManagerLib.g `^goal`; ())
      fun go [] = ()
        | go ((label, tac) :: rest) =
            ((e tac; if proved () then pr ("STAGE_OK " ^ name ^ "/" ^ label ^ " (proved)") else (pr ("STAGE_OK " ^ name ^ "/" ^ label); go rest))
             handle ex => (pr ("STAGE_FAILED " ^ name ^ "/" ^ label ^ " :: " ^ exn_to_string ex); show (name ^ "/" ^ label)))
      val _ = go stages
  in if proved () then (pr ("LEMMA_PROVED " ^ name); SOME (top_thm ()))
     else (pr ("LEMMA_OPEN " ^ name); show (name ^ " end"); NONE) end;
val l1 = run "line1" line1_goal [("all", Cases >> simp[line_ok1_def, line_ok_def, loc_pc_thm] >> rpt gen_tac >> rpt (TOP_CASE_TAC >> gvs[]))];
val w1 = run "walk1" walk1_goal [("all", ho_match_mp_tac (theorem "hyp_walk1_ind") >> rw[hyp_walk1_def, hyp_walk_def, valOf l1])];
fun attempt label f = (f (); pr ("STEP_OK " ^ label)) handle ex => pr ("STEP_FAILED " ^ label ^ " :: " ^ exn_to_string ex);
val _ = attempt "translate" (fn () => List.app (fn th => (cv_auto_trans th; ())) [line_ok1_def, hyp_walk1_def, walk_check_def]);
val prog_def = DB.fetch "forge_refundWholeProg" "refund_prog_def";
val _ = Feedback.trace ("Theory.allow_rebinds", 1) (cv_trans_deep_embedding EVAL) prog_def;
val c = EVAL ``arm8_config$arm8_backend_config``;
val c_oracle_tm = ``set_oracle ^(rhs (concl c)) refund_alloc_oracle``;
val _ = attempt "check pair" (fn () => pr ("WALK_CHECK_29_31 " ^ term_to_string (rhs (concl (cv_eval ``walk_check [29;31] ^c_oracle_tm refund_prog``)))));
val _ = attempt "check single" (fn () => pr ("WALK_CHECK_29 " ^ term_to_string (rhs (concl (cv_eval ``walk_check [29] ^c_oracle_tm refund_prog``)))));
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
