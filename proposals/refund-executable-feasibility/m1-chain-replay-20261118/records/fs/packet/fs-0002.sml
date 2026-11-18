(* U413: the input premises of refund_profile_a_sl are satisfiable, and so are ALL premises together at slide 0x4000.
   A concrete model file system (standard input holds a given text, numchars = LREPEAT [1]) and a one-argument command line.
   Consequence: the slide theorem is not vacuous; for one CONSTRUCTED model state its conclusion holds.
   This is a statement about the HOL model only. It is NOT a native execution witness and NOT evidence about macOS. *)
open preamble llistTheory fsFFITheory fsFFIPropsTheory clFFITheory CommandLineProofTheory TextIOProofTheory wordsLib
     targetSemTheory forge_refundEnvModelTheory forge_refundSlideEntryTheory forge_refundSlideSatTheory forge_refundSlideProfileATheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundInputSat";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
(* mk_thm is used ONLY to let later lemmas be explored after a failure; the run raises Fail before export if any lemma failed,
   and every stored theorem is tag-checked. *)
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; mk_thm ([], goal));
val _ = pr ("USED always_coind\n" ^ thm_to_string always_coind);
val _ = pr ("USED LFINITE_INDUCTION\n" ^ thm_to_string LFINITE_INDUCTION);
(* ---- 1. A live numchars stream. ---- *)
val unf = thm "LREPEAT_one_unfold" ``LREPEAT [1n] = 1 ::: LREPEAT [1]``
  (CONV_TAC (LAND_CONV (ONCE_REWRITE_CONV [LREPEAT_thm])) >> simp []);
val notfin = thm "LFINITE_not_LREPEAT_one" ``!ll. LFINITE ll ==> ll <> LREPEAT [1n]``
  (ho_match_mp_tac LFINITE_INDUCTION >> conj_tac >- simp [] >> rpt gen_tac >> strip_tac >>
   once_rewrite_tac [unf] >> rewrite_tac [LCONS_11] >> asm_rewrite_tac [] >> show_tac "NOTFIN");
val alw = thm "always_eventually_LREPEAT_one"
  ``!ll. ll = LREPEAT [1n] ==> always (eventually (\ll. ?k. LHD ll = SOME k /\ k <> 0n)) ll``
  (ho_match_mp_tac always_coind >> rpt strip_tac >> qexistsl_tac [`1`, `LREPEAT [1]`] >> rpt conj_tac
   >- (asm_rewrite_tac [] >> MATCH_ACCEPT_TAC unf)
   >- (simp [] >> show_tac "ALW2")
   >- (simp [] >> show_tac "ALW3"));
val live = thm "live_numchars_LREPEAT_one" ``live_numchars (LREPEAT [1n])``
  (rewrite_tac [live_numchars_def] >> conj_tac
   >- (strip_tac >> imp_res_tac notfin >> fs [])
   >- (mp_tac (Q.SPEC `LREPEAT [1]` alw) >> simp []));
(* ---- 2. The model file system and command line. ---- *)
val fs_def = new_definition ("sat_fs_def", ``sat_fs (inp:string) =
   <| inode_tbl := [(UStream (strlit "stdin"), inp); (UStream (strlit "stdout"), ""); (UStream (strlit "stderr"), "")];
      files := [];
      infds := [(0, (UStream (strlit "stdin"), ReadMode, 0)); (1, (UStream (strlit "stdout"), WriteMode, 0));
                (2, (UStream (strlit "stderr"), WriteMode, 0))];
      numchars := LREPEAT [1]; maxFD := 2 |>``);
val _ = pr ("DEFINITION " ^ thm_to_string fs_def);
val F1 = thm "sat_fs_wfFS" ``!inp. wfFS (sat_fs inp)``
  (rw [wfFS_def, fs_def, consistentFS_def, liveFS_def, live] >> simp [] >> show_tac "F1");
val F2 = thm "sat_fs_STD_streams" ``!inp. STD_streams (sat_fs inp)``
  (gen_tac >> rewrite_tac [STD_streams_def] >> qexistsl_tac [`0`, `""`, `""`] >> simp [fs_def] >> rw [] >> EQ_TAC >> rw [] >>
   show_tac "F2");
val F3 = thm "sat_fs_stdin_content" ``!inp. stdin_content (sat_fs inp) = SOME inp``
  (rw [stdin_content_def, fs_def] >> show_tac "F3");
val F4 = thm "sat_cl_wfcl" ``wfcl [strlit "refund"]``
  (simp [wfcl_def, validArg_def] >> EVAL_TAC >> show_tac "F4");
val F5 = thm "refund_input_premises_satisfiable"
  ``!inp. ?fs cl. stdin_content fs = SOME inp /\ wfcl cl /\ wfFS fs /\ STD_streams fs``
  (gen_tac >> qexistsl_tac [`sat_fs inp`, `[strlit "refund"]`] >> rewrite_tac [F1, F2, F3, F4]);
(* Control: a file system whose standard input was already read past offset 0 has no standard-input content. *)
val K1 = thm "consumed_stdin_has_no_content"
  ``!inp. stdin_content (sat_fs inp with infds := [(0, (UStream (strlit "stdin"), ReadMode, 1)); (1, (UStream (strlit "stdout"), WriteMode, 0));
                                                   (2, (UStream (strlit "stderr"), WriteMode, 0))]) = NONE``
  (rw [stdin_content_def, fs_def]);
val K2 = thm "finite_numchars_is_not_live" ``~live_numchars [||]``
  (simp [live_numchars_def]);
(* ---- 3. All premises of refund_profile_a_sl together at slide 0x4000; the conclusion for that constructed model state. ---- *)
val TA = DB.fetch "forge_refundSlideProfileA" "refund_profile_a_sl";
val E2 = DB.fetch "forge_refundSlideProfileA" "refund_abs_env_is_ok_sl";
val env_def = DB.fetch "forge_refundEnvModel" "refund_abs_env_def";
val wit = DB.fetch "forge_refundSlideSat" "refund_entry_pre_sl_witness_0x4000";
val heap_sat = DB.fetch "forge_refundSlideSat" "sat_sl_heap_premises";
val [SLv, s0, h0, stk0, e0] = snd (strip_comb (concl wit));
fun fv n = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars (concl TA)));
val envmc = fv "envmc";
val base_env = ``(ARB : ^(ty_antiq (type_of envmc))) with prog_addresses := refund_mem_dm_sl ^SLv ^h0 ^e0``;
val env0 = ``refund_abs_env ^base_env``;
val env0_prog = prove (``(^env0).prog_addresses = refund_mem_dm_sl ^SLv ^h0 ^e0``, simp [env_def]);
val E2i = INST [fv "sl" |-> SLv, envmc |-> base_env] E2;
val (ta_ante, _) = dest_imp (concl TA);
val stdin_prem = valOf (List.find (fn t => can (find_term (fn x => is_const x andalso fst (dest_const x) = "stdin_content")) t) (strip_conj ta_ante));
val inp_tm = rand (rhs stdin_prem);           (* explode (sexp_to_string (refund_request ...)) *)
val _ = pr ("INPUT_TEXT_TERM " ^ term_to_string inp_tm);
val TAi = INST [fv "sl" |-> SLv, fv "s" |-> s0, fv "h" |-> h0, fv "stk" |-> stk0, fv "e" |-> e0, envmc |-> env0,
                fv "fs" |-> ``sat_fs ^inp_tm``, fv "cl" |-> ``[strlit "refund"]``] TA;
val (ante_i, conc_i) = dest_imp (concl TAi);
val prem_th = Tactical.TAC_PROOF (([], ante_i),
   rewrite_tac [wit, heap_sat, env0_prog, E2i, F1, F2, F3, F4] >> show_tac "PREM")
  handle e => (pr ("LEMMA_FAILED joint premises " ^ General.exnMessage e); failed := "joint-premises" :: !failed; mk_thm ([], ante_i));
fun litadd t = if wordsSyntax.is_word_add t andalso null (free_vars t) andalso type_of t = ``:word64`` then EVAL t else NO_CONV t;
val NV = save_thm ("refund_profile_a_sl_conclusion_holds_for_a_constructed_model_state_at_0x4000",
   CONV_RULE (DEPTH_CONV litadd) (MP TAi prem_th));
val _ = chk "refund_profile_a_sl_conclusion_holds_for_a_constructed_model_state_at_0x4000" NV;
val premv = [fv "s", fv "h", fv "stk", fv "e", envmc, fv "fs", fv "cl"];
val joint_goal = list_mk_exists (premv, subst [fv "sl" |-> SLv] ta_ante);
val JS = thm "refund_profile_a_sl_all_premises_satisfiable_at_0x4000" joint_goal
  (map_every exists_tac [s0, h0, stk0, e0, env0, ``sat_fs ^inp_tm``, ``[strlit "refund"]``] >> ACCEPT_TAC prem_th);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundInputSat" @ DB.definitions "forge_refundInputSat");
(* Structural check: the non-vacuity theorem has no hypothesis and no premise; its free variables are the request fields and ext. *)
val _ = pr ("NONVACUITY_FREE_VARS " ^ String.concatWith " " (map (fst o dest_var) (free_vars (concl NV))));
val _ = if is_exists (concl NV) then pr "CONTROL_OK the non-vacuity theorem is an existential statement without premises" else raise Fail "UNEXPECTED_CONTROL_ACCEPTANCE";
val closure = "forge_refundInputSat" :: Theory.ancestry "forge_refundInputSat";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundInputSat")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
