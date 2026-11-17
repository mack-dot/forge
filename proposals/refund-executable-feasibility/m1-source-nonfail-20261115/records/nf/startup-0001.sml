(* Start-up code clause of the installed-state predicate for the stored ARMv8 code and data.
   The clause is isolated and reduced to conditions on the ARMv8 state. It is NOT proved for any state. *)
open preamble backendTheory targetSemTheory targetPropsTheory asmPropsTheory arm8_targetTheory alignmentTheory
     backendProofTheory arm8_configProofTheory forge_refundArm8CompileTheory forge_refundExclusionRealTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundStartupClause";
val weak_def = DB.fetch "forge_refundExclusionReal" "refund_installed_no_handler_def";
val (wl, wr) = dest_eq (snd (strip_forall (concl weak_def)));
val [mc0, ms, cbspace, data_sp] = snd (strip_comb wl);
val (evs, body) = strip_exists wr;
val [t, m, bitmap_ptr, bitmaps_dm, sdm] = evs;
val body' = rhs (concl ((SIMP_CONV bool_ss [LET_THM]) body)) handle _ => body;
val cs = strip_conj body';
val _ = pr ("CLAUSES " ^ Int.toString (length cs));
fun has tm sub = can (find_term (aconv sub)) tm;
fun named nm tm = can (find_term (fn x => is_const x andalso fst (dest_const x) = nm)) tm;
val r1 = ``(^t).regs 1``; val r3 = ``(^t).regs 3``;
(* Start-up clauses: pc equation, pc alignment, the two register clauses, the five header words. *)
val startup = List.filter (fn c =>
   (is_eq c andalso aconv (lhs c) ``(^t).pc``) orelse
   (is_eq c andalso has (lhs c) ``(^t).align``) orelse
   (named "byte_aligned" c andalso (has c r1 orelse has c r3) andalso not (named "fun2set" c)) orelse
   (named "word_lo" c orelse named "word_ls" c) andalso (has c r1) andalso not (is_forall c) andalso not (named "GSPEC" c) orelse
   (is_eq c andalso is_comb (lhs c) andalso aconv (rator (lhs c)) m)) cs;
val _ = List.app (fn c => pr ("STARTUP_CLAUSE " ^ term_to_string c)) startup;
val _ = if length startup = 11 then () else raise Fail ("expected 11 start-up clauses, found " ^ Int.toString (length startup));
val args = [mc0, ms, t, m, bitmap_ptr, cbspace, data_sp];
val sc = mk_var ("refund_startup_clause", list_mk_fun (map type_of args, bool));
val startup_def = new_definition ("refund_startup_clause_def", mk_eq (list_mk_comb (sc, args), list_mk_conj startup));
val _ = pr ("DEFINITION " ^ thm_to_string startup_def);
val scc = list_mk_comb (fst (strip_comb (lhs (snd (strip_forall (concl startup_def))))), args);
(* S1. Fidelity: the installed-state predicate contains the start-up clause. *)
val thmS1 = store_thm ("refund_installed_startup",
  mk_imp (wl, list_mk_exists ([t, m, bitmap_ptr], scc)),
  rewrite_tac [weak_def] >> simp_tac bool_ss [LET_THM] >> strip_tac >>
  map_every exists_tac [t, m, bitmap_ptr] >> rewrite_tac [startup_def] >>
  rpt conj_tac >> first_assum ACCEPT_TAC);
val _ = (tags "refund_installed_startup" thmS1; pr ("CHECKED refund_installed_startup\n" ^ thm_to_string thmS1));
(* S2. On an ARMv8 machine record the asm-state fields of the clause are fields of the ARMv8 state. *)
val rel = ``is_arm8_machine_config ^mc0 /\ target_state_rel (^mc0).target ^t ^ms /\ target_configured ^t ^mc0``;
val thmL = store_thm ("arm8_startup_fields",
  ``^rel ==> (^t).regs 1 = (^ms).REG 1w /\ (^t).regs 3 = (^ms).REG 3w /\ (^t).pc = (^ms).PC /\ (^t).align = 2 /\
             (^mc0).target.get_pc ^ms = (^ms).PC``,
  strip_tac >> fs [is_arm8_machine_config_def, target_state_rel_def, target_configured_def] >>
  rpt (qpat_x_assum `!i. _` (fn th => assume_tac (Q.SPEC `1` th) >> assume_tac (Q.SPEC `3` th))) >>
  rfs [arm8_target_def, arm8_config_def] >> gvs [] >> show_tac "L" >> gvs [arm8_target_def, arm8_config_def]);
val _ = (tags "arm8_startup_fields" thmL; pr ("CHECKED arm8_startup_fields\n" ^ thm_to_string thmL));
val comp = DB.fetch "forge_refundArm8Compile" "refund_arm8_compiled";
val lens = List.filter (fn th => is_eq (concl th) andalso named "LENGTH" (lhs (concl th)) andalso is_comb (lhs (concl th))
                         andalso is_const (rand (lhs (concl th)))) (CONJUNCTS comp);
val _ = List.app (fn th => pr ("STORED " ^ thm_to_string th)) lens;
val _ = if length lens = 2 then () else raise Fail "expected the two stored length facts";
val facts = CONJUNCTS (UNDISCH thmL);
val red = (REWRITE_CONV [startup_def] THENC
           SIMP_CONV (srw_ss()) (facts @ lens @ [bytes_in_word_def, byte_aligned_def, aligned_bitwise_and, word_mul_n2w]) ) scc;
val thmS2 = save_thm ("refund_startup_clause_arm8", DISCH_ALL red);
val _ = (tags "refund_startup_clause_arm8" thmS2; pr ("CHECKED refund_startup_clause_arm8\n" ^ thm_to_string thmS2));
(* M. is_arm8_machine_config is six field equations of the model record. Every record has a fixed form that satisfies it. *)
val fix_def = new_definition ("arm8_fix_def",
  ``arm8_fix (mc:(64,arm8_state,'b) machine_config) = mc with <| target := arm8_target; len_reg := 1; ptr_reg := 0; len2_reg := 3;
        ptr2_reg := 2; callee_saved_regs := [19;20;21;22;23;24;25;26;27;28] |>``);
val thmM1 = store_thm ("arm8_fix_is_arm8", ``is_arm8_machine_config (arm8_fix (mc:(64,arm8_state,'b) machine_config))``,
  simp [fix_def, is_arm8_machine_config_def]);
val thmM2 = store_thm ("is_arm8_iff_fix", ``is_arm8_machine_config (mc:(64,arm8_state,'b) machine_config) <=> arm8_fix mc = mc``,
  simp [fix_def, is_arm8_machine_config_def, theorem "machine_config_component_equality" handle _ => targetSemTheory.machine_config_component_equality] >> metis_tac []);
val _ = (tags "arm8_fix_is_arm8" thmM1; pr ("CHECKED arm8_fix_is_arm8\n" ^ thm_to_string thmM1));
val _ = (tags "is_arm8_iff_fix" thmM2; pr ("CHECKED is_arm8_iff_fix\n" ^ thm_to_string thmM2));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
