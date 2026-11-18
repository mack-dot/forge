(* Round 4 replay (2026-11-18): import check for forge_refundInputSat (the fs joint-premise run fs-r4-0001).
   Written in the replay run, in the style of imp4-0001.sml. It is not a packet file.
   The expected joint statement is built here from the STORED theorem forge_refundSlideProfileA.refund_profile_a_sl
   (its antecedent at sl = 0x4000w, closed by seven existential quantifiers), not from the proof script.
   No theorem is proved or stored. Same machine, same session: this is NOT a clean or independent replay. *)
open preamble llistTheory fsFFITheory fsFFIPropsTheory clFFITheory CommandLineProofTheory TextIOProofTheory wordsLib
     targetSemTheory forge_refundEnvModelTheory forge_refundSlideEntryTheory forge_refundSlideSatTheory
     forge_refundSlideProfileATheory forge_refundInputSatTheory;
val _ = Globals.max_print_depth := 40;
fun pr s = print (s ^ "\n");
val bad = ref 0; val good = ref 0;
fun clean th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors end;
val T = "forge_refundInputSat";
fun same name tm = let val th = DB.fetch T name in aconv (concl th) tm andalso clean th end handle _ => false;
fun check name tm = if same name tm then (good := !good + 1; pr ("IMPORTED " ^ T ^ "." ^ name)) else (bad := !bad + 1; pr ("IMPORT_MISMATCH " ^ T ^ "." ^ name));
val TA = DB.fetch "forge_refundSlideProfileA" "refund_profile_a_sl";
val _ = if clean TA then pr "PARENT_CLEAN forge_refundSlideProfileA.refund_profile_a_sl" else (bad := !bad + 1; pr "PARENT_NOT_CLEAN");
val (ante, conc) = dest_imp (concl TA);
fun fv n = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars (concl TA)));
val SL = ``0x4000w:word64``;
val premv = map fv ["s", "h", "stk", "e", "envmc", "fs", "cl"];
val exp_joint = list_mk_exists (premv, subst [fv "sl" |-> SL] ante);
val _ = pr ("PREMISE_CONJUNCTS " ^ Int.toString (length (strip_conj ante)));
val _ = check "refund_profile_a_sl_all_premises_satisfiable_at_0x4000" exp_joint;
val _ = check "refund_input_premises_satisfiable" ``!inp. ?fs cl. stdin_content fs = SOME inp /\ wfcl cl /\ wfFS fs /\ STD_streams fs``;
val _ = check "sat_fs_wfFS" ``!inp. wfFS (sat_fs inp)``;
val _ = check "sat_fs_STD_streams" ``!inp. STD_streams (sat_fs inp)``;
val _ = check "sat_fs_stdin_content" ``!inp. stdin_content (sat_fs inp) = SOME inp``;
val _ = check "sat_cl_wfcl" ``wfcl [strlit "refund"]``;
val _ = check "live_numchars_LREPEAT_one" ``live_numchars (LREPEAT [1n])``;
(* The non-vacuity theorem: structural checks only (no exact statement is rebuilt here). *)
val NVN = "refund_profile_a_sl_conclusion_holds_for_a_constructed_model_state_at_0x4000";
val NV = DB.fetch T NVN;
fun has c tm = can (find_term (fn x => is_const x andalso fst (dest_const x) = c)) tm;
val allowed = ["reason", "amount", "candidate", "opened", "enabled", "remaining", "original", "request", "charge", "ext"];
val nv_ok = clean NV andalso is_exists (concl NV) andalso not (is_imp (concl NV)) andalso has "machine_sem" (concl NV)
            andalso has "extract_fs" (concl NV) andalso has "sat_fs" (concl NV)
            andalso List.all (fn v => mem (fst (dest_var v)) allowed) (free_vars (concl NV));
val _ = if nv_ok then (good := !good + 1; pr ("STRUCTURE_OK " ^ T ^ "." ^ NVN)) else (bad := !bad + 1; pr ("STRUCTURE_MISMATCH " ^ T ^ "." ^ NVN));
val _ = pr ("NONVACUITY_FREE_VARS " ^ String.concatWith " " (map (fst o dest_var) (free_vars (concl NV))));
(* Every stored theorem and definition has no hypothesis, no axiom tag and no oracle tag except DISK_THM. *)
val allths = DB.theorems T @ DB.definitions T;
val unclean = filter (fn (_, th) => not (clean th)) allths;
val _ = pr ("THEORY " ^ T ^ " theorems " ^ Int.toString (length (DB.theorems T)) ^ " definitions " ^ Int.toString (length (DB.definitions T)) ^
            " unclean " ^ Int.toString (length unclean));
val _ = if null unclean then () else bad := !bad + 1;
(* Controls: the checker must reject wrong statements. *)
fun control msg cond = if cond then pr ("CONTROL_OK " ^ msg) else (bad := !bad + 1; pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ msg));
val _ = control "the joint statement with the slide variable left free is not the stored theorem"
          (not (same "refund_profile_a_sl_all_premises_satisfiable_at_0x4000" (list_mk_exists (premv, ante))));
val _ = control "the joint statement at slide 0x8000 is not the stored theorem"
          (not (same "refund_profile_a_sl_all_premises_satisfiable_at_0x4000" (list_mk_exists (premv, subst [fv "sl" |-> ``0x8000w:word64``] ante))));
val _ = control "the input statement without STD_streams is not the stored theorem"
          (not (same "refund_input_premises_satisfiable" ``!inp. ?fs cl. stdin_content fs = SOME inp /\ wfcl cl /\ wfFS fs``));
val closure = T :: Theory.ancestry T;
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else bad := !bad + 1;
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = pr ("IMPORTED_COUNT " ^ Int.toString (!good) ^ " MISMATCH_COUNT " ^ Int.toString (!bad));
val _ = if !bad = 0 then () else raise Fail "import check failed";
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
