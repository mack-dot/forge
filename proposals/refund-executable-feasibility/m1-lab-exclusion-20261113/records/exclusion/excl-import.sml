(* Fresh import with a structure audit of the final theorem. *)
load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "labPropsTheory"; load "wordConvsTheory"; load "labSemTheory";
load "lab_to_targetProofTheory"; load "blastLib";
open preamble backendTheory labSemTheory labLangTheory targetSemTheory
     forge_refundLabClosureTheory forge_refundLabResolveTheory
     forge_labRegionInvariantTheory forge_labRegionStepTheory forge_labRegionWalkTheory forge_refundLabRunTheory
     forge_labRegionAlignedTheory forge_refundLabExclusionTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val L_tm = ``SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val ls_tm = ``[Install_location; InstallData_location]``;
val OK_tm = ``pc_ok ^ls_tm ^L_tm``;
val G_tm = ``(loc_good ^OK_tm ^L_tm) : 64 word_loc -> bool``;
val D_tm = ``\x:word64. ?a. x = byte_align a``;
val init_tm = ``lab_to_targetProof$make_init mc0 ffi0 t0 (m:word64 -> 64 word_loc) dm1 sdm1 ms0 ^L_tm cmp0 cbpos0 cbspace0 coracle0``;
(* Premise: exactly the memory clause that good_init_state states for aligned addresses. *)
val aligned_goal = ``(!a:word64. ?w. m (byte_align a) = Word w) /\ labSem$evaluate (^init_tm with clock := k) = (res,s2) ==>
   ^OK_tm s2.pc /\ s2.code = ^L_tm /\ (!i bs n. labSem$asm_fetch s2 <> SOME (LabAsm Install i bs n))``;
val good_goal =
  let val (ante, conc) = dest_imp aligned_goal val ev = el 2 (strip_conj ante)
      val m_tm = hd (List.filter (fn v => fst (dest_var v) = "m") (free_vars aligned_goal))
      val mc_tm = hd (List.filter (fn v => fst (dest_var v) = "mc0") (free_vars aligned_goal))
      val ms_tm = hd (List.filter (fn v => fst (dest_var v) = "ms0") (free_vars aligned_goal))
      val t_tm = hd (List.filter (fn v => fst (dest_var v) = "t0") (free_vars aligned_goal))
  in mk_imp (mk_conj (``targetSem$good_init_state ^mc_tm ^ms_tm bytes0 cbs0 ^t_tm ^m_tm dm0 sdm0``, ev), conc) end;
val good = DB.fetch "forge_refundLabExclusion" "refund_lab_good_init_avoids_install";
val aligned = DB.fetch "forge_refundLabExclusion" "refund_lab_aligned_init_avoids_install";
val _ = if aconv good_goal (concl good) then () else raise Fail "Exact statement mismatch: refund_lab_good_init_avoids_install";
val _ = if aconv aligned_goal (concl aligned) then () else raise Fail "Exact statement mismatch: refund_lab_aligned_init_avoids_install";
val _ = (tags "good" good; tags "aligned" aligned);
val _ = pr "IMPORTED refund_lab_good_init_avoids_install EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0";
val _ = pr "IMPORTED refund_lab_aligned_init_avoids_install EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0";
(* Structure audit, independent of the goal construction above. *)
val (ante, conc) = dest_imp (concl good);
val premises = strip_conj ante;
fun head_name t = fst (dest_const (fst (strip_comb t))) handle _ => "?";
val _ = pr ("PREMISE_COUNT " ^ Int.toString (length premises));
val _ = pr ("PREMISE_HEADS " ^ String.concatWith "," (map (fn t => if is_eq t then "=" ^ head_name (lhs t) else head_name t) premises));
fun mentions name t = can (find_term (fn c => is_const c andalso fst (dest_const c) = name)) t;
val _ = pr ("PREMISES_MENTION loc_good=" ^ Bool.toString (mentions "loc_good" ante) ^ " val_inv=" ^ Bool.toString (mentions "val_inv" ante) ^
            " mval_inv=" ^ Bool.toString (mentions "mval_inv" ante) ^ " region_hyp=" ^ Bool.toString (mentions "region_hyp" ante));
val _ = if length premises = 2 andalso not (mentions "loc_good" ante) andalso not (mentions "mval_inv" ante) andalso not (mentions "region_hyp" ante)
        then () else raise Fail "Unexpected premise in the final theorem";
val consts = find_terms (fn t => is_const t andalso String.isSubstring "oracle" (fst (dest_const t))) (concl good);
val _ = pr ("ORACLE_CONSTANTS " ^ String.concatWith "," (Lib.mk_set (map (fn c => #Thy (dest_thy_const c) ^ "$" ^ #Name (dest_thy_const c)) consts)));
val _ = pr ("GOOD_INIT_STATE_CONSTANT " ^ String.concatWith "," (Lib.mk_set (map (fn c => #Thy (dest_thy_const c) ^ "$" ^ #Name (dest_thy_const c))
    (find_terms (fn t => is_const t andalso (fst (dest_const t) = "good_init_state" orelse fst (dest_const t) = "make_init" orelse fst (dest_const t) = "evaluate")) (concl good)))));
val closure = "forge_refundLabExclusion" :: Theory.ancestry "forge_refundLabExclusion";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "RUN_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
