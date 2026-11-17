load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "labPropsTheory"; load "wordConvsTheory"; load "labSemTheory";
open preamble cv_transLib backendTheory backend_asmTheory labSemTheory forge_refundLabClosureTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun stamp s = pr ("STAMP " ^ s ^ " " ^ Time.toString (Time.now ()));
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P1_OUT"));
val _ = new_theory "forge_p2Explore";
(* Program-counter level checks. pc counts non-label lines, as labSem$asm_fetch_aux does.
   Label resolution uses the published labSem$loc_to_pc. *)
(* Executable twin of labSem$loc_to_pc (the published definition tests a label with an existential). *)
val loc_pc_def = Define `
  (loc_pc n1 n2 [] = NONE) /\
  (loc_pc n1 n2 ((Section k xs md)::ys) =
     if (k = n1) /\ (n2 = 0n) then SOME (0:num) else
       case xs of
       | [] => loc_pc n1 n2 ys
       | (z::zs) =>
         if (case z of Label a b _ => a = n1 /\ b = n2 | _ => F) /\ n2 <> 0 then SOME 0n else
           if is_Label z then loc_pc n1 n2 ((Section k zs md)::ys)
           else
             case loc_pc n1 n2 ((Section k zs md)::ys) of
             | NONE => NONE
             | SOME pos => SOME (pos + 1:num))`;
val loc_pc_goal = ``!n1 n2 secs. loc_pc n1 n2 secs = loc_to_pc n1 n2 secs``;
val sec_at_def = Define `
  (sec_at (pc:num) [] = NONE) /\
  (sec_at pc (sec::rest) =
     let k = LENGTH (FILTER (\l. ~is_Label l) (Section_lines sec)) in
       if pc < k then SOME (Section_num sec) else sec_at (pc - k) rest)`;
val pc_ok_def = Define `pc_ok (ls:num list) secs pc = case sec_at pc secs of NONE => T | SOME n => ~MEM n ls`;
val ref_ok_def = Define `ref_ok ls secs lab = case lab of Lab n1 n2 =>
   (case loc_pc n1 n2 secs of NONE => T | SOME p => pc_ok ls secs p)`;
val line_refs_ok_def = Define `
  line_refs_ok ls secs l = case l of
     LabAsm (Jump lab) _ _ _ => ref_ok ls secs lab
   | LabAsm (JumpCmp _ _ _ lab) _ _ _ => ref_ok ls secs lab
   | LabAsm (LocValue _ lab) _ _ _ => ref_ok ls secs lab
   | LabAsm (Call lab) _ _ _ => ref_ok ls secs lab
   | _ => T`;
val refs_ok_def = Define `
  refs_ok ls secs = EVERY (\sec. MEM (Section_num sec) ls \/ EVERY (line_refs_ok ls secs) (Section_lines sec)) secs`;
val flat_lines_def = Define `
  flat_lines secs = FLAT (MAP (\sec. MAP (\l. (Section_num sec, l)) (FILTER (\l. ~is_Label l) (Section_lines sec))) secs)`;
val fall_pairs_def = Define `
  (fall_pairs (ls:num list) [] = T) /\
  (fall_pairs ls [x] = T) /\
  (fall_pairs ls ((n1,l1)::(n2,l2)::rest) =
     ((~MEM n1 ls /\ MEM n2 ls ==> line_is_exit l1) /\ fall_pairs ls ((n2,l2)::rest)))`;
val line_is_call_def = Define `line_is_call l = case l of LabAsm (Call _) _ _ _ => T | _ => F`;
val line_has_ref_def = Define `line_has_ref l = case l of
     LabAsm (Jump _) _ _ _ => T | LabAsm (JumpCmp _ _ _ _) _ _ _ => T | LabAsm (LocValue _ _) _ _ _ => T | LabAsm (Call _) _ _ _ => T | _ => F`;
val resolve_stats_def = Define `
  resolve_stats secs =
    (LENGTH (flat_lines secs),
     LENGTH (FILTER (\(n,l). line_has_ref l) (flat_lines secs)),
     LENGTH (FILTER (\(n,l). line_is_call l) (flat_lines secs)),
     (case flat_lines secs of [] => NONE | (n,l)::_ => SOME n))`;
val resolve_check_def = Define `
  resolve_check ls c p = case lab_forge8 c p of NONE => F | SOME L => refs_ok ls L /\ fall_pairs ls (flat_lines L)`;
val resolve_info_def = Define `resolve_info c p = case lab_forge8 c p of NONE => NONE | SOME L => SOME (resolve_stats L)`;
val trans_defs = [loc_pc_def, sec_at_def, pc_ok_def, ref_ok_def, line_refs_ok_def, refs_ok_def, flat_lines_def,
                  fall_pairs_def, line_is_call_def, line_has_ref_def, resolve_stats_def, resolve_check_def, resolve_info_def];
val _ = List.app (fn th => (cv_auto_trans th; ())) trans_defs;
val prog_def = DB.fetch "forge_refundWholeProg" "refund_prog_def";
val _ = Feedback.trace ("Theory.allow_rebinds", 1) (cv_trans_deep_embedding EVAL) prog_def;
val c = EVAL ``arm8_config$arm8_backend_config``;
val conf_tm = rhs (concl c);
val c_oracle_tm = ``set_oracle ^conf_tm refund_alloc_oracle``;
val rcheck_pair = cv_eval ``resolve_check [29;31] ^c_oracle_tm refund_prog`` |> REWRITE_RULE [GSYM c];
val rcheck_single = cv_eval ``resolve_check [29] ^c_oracle_tm refund_prog`` |> REWRITE_RULE [GSYM c];
val rinfo = cv_eval ``resolve_info ^c_oracle_tm refund_prog`` |> REWRITE_RULE [GSYM c];
val lab_link = DB.fetch "forge_refundLabClosure" "lab_forge8_to_lab";
val L_tm = ``SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val twin_tac = ho_match_mp_tac (theorem "loc_pc_ind") >> rw[] >> simp[Once loc_pc_def, Once loc_to_pc_def] >>
   rpt (TOP_CASE_TAC >> gvs[]) >> Cases_on `h` >> gvs[];
val rclosed_goal = ``refs_ok [29;31] ^L_tm /\ fall_pairs [29;31] (flat_lines ^L_tm)``;
val rnot_goal = ``~(refs_ok [29] ^L_tm /\ fall_pairs [29] (flat_lines ^L_tm))``;
val rstats_goal = ``resolve_stats ^L_tm = (29095,5244,0,SOME 0)``;
val rmeaning_goal = ``!ls secs. refs_ok ls secs ==>
   !sec a i bs len n1 n2 p. MEM sec secs /\ ~MEM (Section_num sec) ls /\ MEM (LabAsm a i bs len) (Section_lines sec) /\
      (n1,n2) IN labProps$labs_of a /\ loc_to_pc n1 n2 secs = SOME p ==> pc_ok ls secs p``;
val p2s_goal = ``!sec a i bs len n1 n2 p. MEM sec ^L_tm /\ Section_num sec <> Install_location /\ Section_num sec <> InstallData_location /\
      MEM (LabAsm a i bs len) (Section_lines sec) /\ (n1,n2) IN labProps$labs_of a /\ loc_to_pc n1 n2 ^L_tm = SOME p ==>
      pc_ok [Install_location; InstallData_location] ^L_tm p``;
val the_lab = ``lab_forge8 (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog``;
val rclosed_tac = Cases_on `^the_lab` >- (mp_tac rcheck_pair >> simp[resolve_check_def]) >>
   drule lab_link >> strip_tac >> mp_tac rcheck_pair >> gvs[resolve_check_def];
val rnot_tac = Cases_on `^the_lab` >- (mp_tac rcheck_pair >> simp[resolve_check_def]) >>
   drule lab_link >> strip_tac >> mp_tac rcheck_single >> gvs[resolve_check_def];
val rstats_tac = Cases_on `^the_lab` >- (mp_tac rcheck_pair >> simp[resolve_check_def]) >>
   drule lab_link >> strip_tac >> mp_tac rinfo >> gvs[resolve_info_def];
(* Exploration only *)
open proofManagerLib;
fun goals_now () = (top_goals ()) handle _ => [];
fun proved () = ((top_thm (); true) handle _ => false);
fun clip s = String.substring (s, 0, Int.min (1500, size s));
fun goal_string (asl, w) = String.concatWith "\n" (map (fn a => "  ASM " ^ term_to_string a) asl) ^ "\n  GOAL " ^ term_to_string w;
fun show label = (pr ("AFTER " ^ label ^ ": " ^ Int.toString (length (goals_now ())) ^ " goals, proved=" ^ Bool.toString (proved ()));
                  List.app (fn gl => pr (clip (goal_string gl) ^ "\n----")) (goals_now ()));
fun step label tac = ((e tac; show label) handle ex => (pr ("STEP_FAILED " ^ label ^ " " ^ exn_to_string ex); show ("failure of " ^ label)));
val _ = g `^loc_pc_goal`; val _ = step "twin" twin_tac;
val loc_pc_thm = top_thm ();
val _ = g `^rclosed_goal`; val _ = step "closed" rclosed_tac;
val rclosed = top_thm ();
val _ = g `^rnot_goal`; val _ = step "not" rnot_tac;
val _ = g `^rstats_goal`; val _ = step "stats" rstats_tac;
val _ = g `^rmeaning_goal`;
val rmeaning_tac = rw[refs_ok_def, EVERY_MEM] >> first_x_assum drule >> simp[] >> strip_tac >> first_x_assum drule >>
   simp[line_refs_ok_def] >> Cases_on `a` >> fs[labPropsTheory.labs_of_def, ref_ok_def, loc_pc_thm] >>
   TRY (Cases_on `l`) >> gvs[labPropsTheory.labs_of_def];
val _ = step "meaning" rmeaning_tac;
val rmeaning = top_thm ();
val _ = g `^p2s_goal`;
val _ = step "p2s" (rpt gen_tac >> strip_tac >> mp_tac (MATCH_MP rmeaning (CONJUNCT1 rclosed)) >>
   disch_then (qspecl_then [`sec`,`a`,`i`,`bs`,`len`,`n1`,`n2`,`p`] mp_tac) >>
   fs[data_to_wordTheory.Install_location_eq, data_to_wordTheory.InstallData_location_eq]);
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
