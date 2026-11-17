(* Source non-Fail for the exact refund_prog on valid-request input, from the stored refund_semantics.
   Composition with the U386 real-record theorems. No premise is added to the U386 theorems. *)
open preamble backendTheory semanticsPropsTheory semanticsTheory ml_progTheory targetSemTheory targetPropsTheory
     backendProofTheory arm8_configProofTheory forge_refundWholeProgTheory forge_refundArm8CompileTheory
     forge_refundExclusionRealTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundSourceNonFail";
fun fv tm n = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars tm));
val sem = DB.fetch "forge_refundWholeProg" "refund_semantics";
val _ = tags "refund_semantics" sem;
val _ = pr ("STORED refund_semantics\n" ^ thm_to_string sem);
val syn = valOf (List.find (fn th => aconv (concl th) ``prog_syntax_ok refund_prog``)
                 (CONJUNCTS (DB.fetch "forge_refundArm8Compile" "refund_arm8_compiled")));
val _ = pr ("STORED " ^ thm_to_string syn);
val (inp, semc) = dest_imp (concl sem);
val bffi = rand (rand (rator (rator (rand (rator semc)))));
val _ = pr ("FFI " ^ term_to_string bffi ^ " : " ^ type_to_string (type_of bffi));
val post = rand semc;
(* 1. Source non-Fail, in the exact form of the U386 premise. *)
val nofail = ``~semantics_prog (FST (THE (prim_sem_env ^bffi))) (SND (THE (prim_sem_env ^bffi))) refund_prog Fail``;
val thmN = store_thm ("refund_source_nonfail", mk_imp (inp, nofail),
  rewrite_tac [init_state_env_thm, FST, SND] >>
  ACCEPT_TAC (HO_MATCH_MP sem_satisfies_IMP_Terminate (UNDISCH_ALL sem) |> C MP syn |> CONJUNCT1 |> DISCH_ALL));
val _ = (tags "refund_source_nonfail" thmN; pr ("CHECKED refund_source_nonfail\n" ^ thm_to_string thmN));
(* The semantic definition in use: Fail of semantics_prog is a type error under some pointer-equality oracle and some clock. *)
val thmD = store_thm ("semantics_prog_Fail_expanded",
  ``semantics_prog st env prog Fail <=> ?po k. SND (evaluate_prog_with_clock (st with ptr_eq_oracle := po) env k prog) = Rerr (Rabort Rtype_error)``,
  simp [semantics_prog_def, semantics_determ_def]);
val _ = (tags "semantics_prog_Fail_expanded" thmD; pr ("CHECKED semantics_prog_Fail_expanded\n" ^ thm_to_string thmD));
(* 2. Composition with the U386 real-record theorems at ffi = basis_ffi ext cl fs. *)
val thmR = DB.fetch "forge_refundExclusionReal" "refund_u298_exclusion_real";
val thmF = DB.fetch "forge_refundExclusionReal" "refund_compile_correct_no_handler";
fun at_basis th = let val f = fv (concl th) "ffi" in
   INST [inst (match_type (type_of f) (type_of bffi)) f |-> bffi] (INST_TYPE (match_type (type_of f) (type_of bffi)) th) end;
val thmRb = at_basis thmR; val thmFb = at_basis thmF;
val (antR, u298) = dest_imp (concl thmRb);
val [arm, nf, inst_p] = strip_conj antR;
val _ = if aconv nf nofail then pr "PREMISE_FORM_IDENTICAL true" else raise Fail "non-Fail premise form differs from U386";
val thmU = store_thm ("refund_u298_exclusion_valid_request", mk_imp (list_mk_conj [arm, inst_p, inp], u298),
  strip_tac >> match_mp_tac thmRb >> rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >>
  match_mp_tac thmN >> asm_rewrite_tac []);
val _ = (tags "refund_u298_exclusion_valid_request" thmU; pr ("CHECKED refund_u298_exclusion_valid_request\n" ^ thm_to_string thmU));
val mc0 = fv antR "mc0"; val ms = fv antR "ms";
val beh = ``?io_events. machine_sem ^mc0 ^bffi ^ms SUBSET extend_with_resource_limit {Terminate Success io_events} /\ ^(rand (snd (dest_exists (snd (dest_abs post)))))``;
val term2 = HO_MATCH_MP sem_satisfies_IMP_Terminate (UNDISCH_ALL sem) |> C MP syn |> CONJUNCT2
   |> INST_TYPE [] |> Q.INST [`sem` |-> `machine_sem ^mc0 ^bffi ^ms`] |> DISCH_ALL;
val _ = pr ("TERM2 " ^ thm_to_string term2);
val thmB = store_thm ("refund_behavior_valid_request_no_handler", mk_imp (list_mk_conj [arm, inst_p, inp], beh),
  strip_tac >>
  `^nofail` by (match_mp_tac thmN >> asm_rewrite_tac []) >>
  `machine_sem ^mc0 ^bffi ^ms SUBSET extend_with_resource_limit (semantics_prog (FST (THE (prim_sem_env ^bffi))) (SND (THE (prim_sem_env ^bffi))) refund_prog)` by
     (match_mp_tac thmFb >> rpt conj_tac >> first_assum ACCEPT_TAC) >>
  pop_assum (assume_tac o REWRITE_RULE [init_state_env_thm, FST, SND]) >>
  mp_tac term2 >> impl_tac >- asm_rewrite_tac [] >>
  disch_then drule >> rewrite_tac [machine_sem_sing] >> show_tac "B" >> simp []);
val _ = (tags "refund_behavior_valid_request_no_handler" thmB; pr ("CHECKED refund_behavior_valid_request_no_handler\n" ^ thm_to_string thmB));
val _ = export_theory ();
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
