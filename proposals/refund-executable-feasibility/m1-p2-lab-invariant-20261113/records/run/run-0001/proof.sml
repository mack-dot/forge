(* P2 for the exact lab program: runs that start outside the installer sections stay outside and never fetch Install. *)
load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "labPropsTheory"; load "wordConvsTheory"; load "labSemTheory";
open preamble cv_transLib backendTheory backend_asmTheory labSemTheory labLangTheory
     forge_refundLabClosureTheory forge_refundLabResolveTheory
     forge_labRegionInvariantTheory forge_labRegionStepTheory forge_labRegionWalkTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_RUN_OUT"));
val _ = new_theory "forge_refundLabRun";
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
val line1_thm = prove (line1_goal, Cases >> simp[line_ok1_def, line_ok_def, loc_pc_thm] >> rpt gen_tac >> rpt (TOP_CASE_TAC >> gvs[]));
val walk1_thm = prove (walk1_goal, ho_match_mp_tac (theorem "hyp_walk1_ind") >> rw[hyp_walk1_def, hyp_walk_def, line1_thm]);
val _ = List.app (fn th => (cv_auto_trans th; ())) [line_ok1_def, hyp_walk1_def, walk_check_def];
val prog_def = DB.fetch "forge_refundWholeProg" "refund_prog_def";
val _ = Feedback.trace ("Theory.allow_rebinds", 1) (cv_trans_deep_embedding EVAL) prog_def;
val c = EVAL ``arm8_config$arm8_backend_config``;
val c_oracle_tm = ``set_oracle ^(rhs (concl c)) refund_alloc_oracle``;
val wcheck = cv_eval ``walk_check [29;31] ^c_oracle_tm refund_prog`` |> REWRITE_RULE [GSYM c];
val wcheck_single = cv_eval ``walk_check [29] ^c_oracle_tm refund_prog`` |> REWRITE_RULE [GSYM c];
val _ = pr ("WALK_CHECK_PAIR " ^ thm_to_string wcheck);
val _ = pr ("WALK_CHECK_SINGLE " ^ thm_to_string wcheck_single);
val lab_link = DB.fetch "forge_refundLabClosure" "lab_forge8_to_lab";
val the_lab = ``lab_forge8 (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog``;
val loc_eqs = [data_to_wordTheory.Install_location_eq, data_to_wordTheory.InstallData_location_eq];
val hyp_L = prove (hyp_L_goal,
  simp loc_eqs >> Cases_on `^the_lab` >- (mp_tac wcheck >> simp[walk_check_def]) >>
  drule lab_link >> strip_tac >> mp_tac wcheck >> gvs[walk_check_def, walk1_thm] >> strip_tac >>
  drule hyp_walk_region_hyp >> simp[]);
val not29 = prove (``~(hyp_walk1 [29] ^L_tm 0 ^L_tm /\ pc_ok [29] ^L_tm 0)``,
  Cases_on `^the_lab` >- (mp_tac wcheck >> simp[walk_check_def]) >>
  drule lab_link >> strip_tac >> mp_tac wcheck_single >> gvs[walk_check_def]);
val G_tm = ``loc_good (pc_ok ^ls_tm ^L_tm) ^L_tm``;
val OK_tm = ``pc_ok ^ls_tm ^L_tm``;
val pref = region_prefix |> Q.GENL [`G`,`OK`,`code`] |> ISPECL [G_tm, OK_tm, L_tm];
val run_L = prove (run_L_goal,
  rpt gen_tac >> strip_tac >> strip_assume_tac hyp_L >>
  qspecl_then [`s`,`k`,`res`,`t`] mp_tac pref >>
  impl_tac >- simp[region_inv_def] >> simp[region_inv_def]);
val stored = [("line_ok1_eq", line1_thm), ("hyp_walk1_eq", walk1_thm), ("refund_lab_region_hyp", hyp_L),
  ("refund_lab_walk_not_closed_29", not29), ("refund_lab_run_avoids_install", run_L)];
val _ = List.app (fn (n, th) => (tags n th; save_thm (n, th); pr ("CHECKED " ^ n ^ "\n" ^ thm_to_string th))) stored;
val _ = export_theory ();
val _ = pr "RUN_PROOF_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
