(* U391: five of the seven residual clauses of U390 discharged at the record refund_mc 0x1000040D0w envmc.
   The two remaining clauses (interference_ok, ffi_interfer_ok) are kept unchanged as refund_installed_rest2. They are NOT proved.
   Definitions are the stored ones. No loader, slide, processor or FFI-code model. *)
open preamble backendTheory targetSemTheory targetPropsTheory asmPropsTheory lab_to_targetTheory arm8_targetTheory alignmentTheory
     backendProofTheory arm8_configProofTheory forge_refundArm8CompileTheory forge_refundExclusionRealTheory forge_refundStartupClauseTheory
     forge_refundStartupBridgeTheory forge_refundLoaderMemoryTheory forge_refundInstalledDomainsTheory forge_refundInstalledAssemblyTheory
     forge_refundFfiFactsTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (300, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1800, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundResidual";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun has_sub nms tm = can (find_term (fn x => is_const x andalso List.exists (fn n => String.isSubstring n (fst (dest_const x))) nms)) tm;
val comp = DB.fetch "forge_refundArm8Compile" "refund_arm8_compiled";
val len_code = valOf (List.find (fn th => is_eq (concl th) andalso aconv (lhs (concl th)) ``LENGTH forge_refundArm8Compile$code``) (CONJUNCTS comp));
fun D n = DB.fetch "forge_refundInstalledDomains" n;
val [code_dm_def, mem_dm_def, clear_def, end_def, C1, T_end] = map D ["refund_code_dm_def", "refund_mem_dm_def", "refund_heap_clear_def",
     "refund_end_state_def", "refund_bitmaps_dm_range", "refund_end_state_established"];
val asm_th = DB.fetch "forge_refundInstalledAssembly" "refund_installed_from_end_state";
val rest_def = DB.fetch "forge_refundInstalledAssembly" "refund_installed_rest_def";
val mc_def = DB.fetch "forge_refundStartupBridge" "refund_mc_def";
val mc_is = DB.fetch "forge_refundStartupBridge" "refund_mc_is_arm8";
val mc_fields = DB.fetch "forge_refundStartupBridge" "refund_mc_fields";
val fix_def = DB.fetch "forge_refundStartupClause" "arm8_fix_def";
val names_thm = DB.fetch "forge_refundFfiFacts" "refund_ffi_names";
val tgt_pc = prove (``arm8_target.get_pc (ms:arm8_state) = ms.PC``, simp [arm8_target_def]);
(* ---- 1. The residual, its two kept clauses, the concrete record. ---- *)
val (rl, rr) = dest_eq (snd (strip_forall (concl rest_def)));
val [mc0, ms] = snd (strip_comb rl);
val cs = strip_conj rr;
val _ = if length cs = 7 then () else raise Fail "expected seven residual clauses";
fun kept c = has_sub ["interference_ok", "ffi_interfer_ok"] c;
val keep = List.filter kept cs;
val _ = if length keep = 2 then () else raise Fail "expected two kept clauses";
val rest2_c = mk_var ("refund_installed_rest2", type_of mc0 --> type_of ms --> bool);
val rest2_def = new_definition ("refund_installed_rest2_def", mk_eq (list_mk_comb (rest2_c, [mc0, ms]), list_mk_conj keep));
val _ = pr ("DEFINITION " ^ thm_to_string rest2_def);
val B = ``0x1000040D0w:word64``;
val envmc = mk_var ("envmc", type_of mc0);
val RMC = ``refund_mc ^B ^envmc``;
val FLD = thm "refund_mc_concrete_fields"
  ``!names. refund_lab_conf2.ffi_names = SOME names /\ LENGTH names = 4 ==>
      (^RMC).ffi_names = names /\ (^RMC).ffi_entry_pcs = [0x1000040A0w; 0x100004090w; 0x100004080w; 0x100004070w] /\
      (^RMC).halt_pc = 0x1000040C0w /\ (^RMC).install_pc = 0x1000040B0w /\ (^RMC).mmio_info = [] /\ (^RMC).shared_addresses = {} /\
      (^RMC).prog_addresses = (^envmc).prog_addresses /\ (^RMC).target = arm8_target``
  (rpt strip_tac >> asm_simp_tac (srw_ss()) [mc_def, fix_def, ffi_offset_def] >> EVAL_TAC >> show_tac "FLD");
val hl = prove (``a <+ 0x1000040D0w ==> ~(0x1000040D0w <=+ a) /\ a <+ 0x100030F30w /\ ~(0x10002C018w <=+ (a:word64))``, blastLib.BBLAST_TAC);
val stub_out = thm "refund_stub_outside_domain"
  ``!a h e. refund_heap_clear h e /\ 0x100000000w <=+ a /\ a <+ 0x1000040D0w ==> a NOTIN refund_mem_dm h e``
  (rewrite_tac [clear_def] >> rpt gen_tac >> strip_tac >> imp_res_tac hl >>
   simp_tac std_ss [mem_dm_def, code_dm_def, IN_UNION, GSPECIFICATION] >> metis_tac [C1]);
(* ---- 2. Each of the five other clauses, at the concrete record. ---- *)
val A = ``refund_heap_clear h e /\ (^envmc).prog_addresses = refund_mem_dm h e /\ (^ms).PC = ^B``;
val stubs = [``0x1000040C0w:word64``, ``0x1000040B0w:word64``, ``0x1000040A0w:word64``, ``0x100004090w:word64``, ``0x100004080w:word64``, ``0x100004070w:word64``];
fun stub_fact a = (SUBGOAL_THEN ``^a NOTIN refund_mem_dm h e`` assume_tac) >- (match_mp_tac stub_out >> asm_rewrite_tac [] >> EVAL_TAC);
val PRE = strip_tac >> strip_assume_tac names_thm >> mp_tac (SPEC ``names:ffiname list`` FLD) >>
          (impl_tac >- asm_rewrite_tac []) >> strip_tac >> EVERY (map stub_fact stubs) >>
          asm_simp_tac (srw_ss()) [start_pc_ok_def, ffi_offset_def, len_code, tgt_pc];
val TAIL = TRY (conj_tac
   >- (gen_tac >> strip_tac >> `index = 0 \/ index = 1 \/ index = 2 \/ index = 3` by decide_tac >>
       asm_simp_tac (srw_ss()) [find_index_def] >> TRY (EVAL_TAC >> NO_TAC))
   >- (rpt gen_tac >> strip_tac >> fs []));
val count = ref 0;
val inst_cs = map (subst [mc0 |-> RMC]) cs;
fun prove_clause c = (count := !count + 1;
  let val th = Tactical.TAC_PROOF (([], mk_imp (A, c)), PRE >> TAIL)
  in pr ("CLAUSE_PROVED " ^ Int.toString (!count) ^ " " ^ String.substring (term_to_string c, 0, Int.min (160, size (term_to_string c)))); SOME th end
  handle e => (pr ("CLAUSE_FAILED " ^ Int.toString (!count) ^ " " ^ term_to_string c);
               ignore (Tactical.TAC_PROOF (([], mk_imp (A, c)), PRE >> TAIL >> show_tac "CLAUSE") handle _ => TRUTH);
               failed := ("clause-" ^ Int.toString (!count)) :: !failed; NONE));
val classed = map (fn c => if kept c then (count := !count + 1;
     pr ("CLAUSE_KEPT_UNPROVED " ^ Int.toString (!count) ^ " " ^ String.substring (term_to_string c, 0, Int.min (160, size (term_to_string c)))); (c, NONE))
   else (c, prove_clause c)) inst_cs;
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val rest2_tm = ``refund_installed_rest2 ^RMC ^ms``;
val A_th = LIST_CONJ (map ASSUME (strip_conj A));
val kept_ths = CONJUNCTS (EQ_MP (SPECL [RMC, ms] rest2_def) (ASSUME rest2_tm));
val clause_ths = map (fn (c, p) => case p of SOME th => MP th A_th | NONE => valOf (List.find (fn r => aconv (concl r) c) kept_ths)) classed;
val rest_body = Tactical.TAC_PROOF ((strip_conj A @ [rest2_tm], list_mk_conj inst_cs), rpt conj_tac >> FIRST (map ACCEPT_TAC clause_ths));
val rest_th = EQ_MP (SYM (SPECL [RMC, ms] rest_def)) rest_body;
val reduced = save_thm ("refund_installed_rest_reduced",
   REWRITE_RULE [AND_IMP_INTRO, GSYM CONJ_ASSOC] (List.foldr (fn (a, th) => DISCH a th) rest_th (strip_conj A @ [rest2_tm])));
val _ = chk "refund_installed_rest_reduced" reduced;
(* ---- 3. Compositions from the entry pre-state. ---- *)
val pre = ``refund_entry_pre s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear h e /\
            (^envmc).prog_addresses = refund_mem_dm h e``;
fun STEP tac = strip_tac >> mp_tac T_end >> (impl_tac >- asm_rewrite_tac []) >> disch_then (qx_choose_then `ms` strip_assume_tac) >>
   first_assum (fn th => if has_sub ["refund_end_state"] (concl th) then strip_assume_tac (REWRITE_RULE [end_def] th) else NO_TAC) >>
   qexists_tac `ms` >> conj_tac >- first_assum ACCEPT_TAC >> conj_tac >- first_assum ACCEPT_TAC >> strip_tac >>
   SUBGOAL_THEN ``refund_installed_rest ^RMC ^ms`` assume_tac >- (mp_tac reduced >> asm_rewrite_tac []) >>
   SUBGOAL_THEN ``refund_installed_no_handler ^RMC ^ms 428 0`` assume_tac
   >- (match_mp_tac asm_th >> asm_rewrite_tac [mc_is, mc_fields]) >> tac;
val T1 = thm "refund_installed_from_entry_reduced"
  ``^pre ==> ?ms. arm8_run 27 s = SOME ms /\ ms.PC = ^B /\
       (refund_installed_rest2 ^RMC ms ==> refund_installed_no_handler ^RMC ms 428 0)``
  (STEP (first_assum ACCEPT_TAC));
fun compose src new =
  let val th = DB.fetch "forge_refundStartupBridge" src
      val fv = fn n => valOf (List.find (fn v => fst (dest_var v) = n) (free_vars (concl th)))
      val th_i = INST [fv "cbspace" |-> ``428:num``, fv "data_sp" |-> ``0:num``, fv "base0" |-> B] th
      val (ant, c) = dest_imp (concl th_i)
      val inputs = tl (strip_conj ant)
      val goal = mk_imp (list_mk_conj (strip_conj pre @ inputs),
                 ``?ms. arm8_run 27 s = SOME ms /\ ms.PC = ^B /\ (refund_installed_rest2 ^RMC ms ==> ^c)``)
  in thm new goal (STEP (match_mp_tac th_i >> asm_rewrite_tac [])) end;
val B1 = compose "refund_mc_behavior_stdin_no_handler" "refund_behavior_from_entry_reduced";
val B2 = compose "refund_mc_u298_exclusion_stdin" "refund_u298_exclusion_from_entry_reduced";
(* ---- 4. Negative controls. ---- *)
val gmc = ``refund_mc (base0:word64) ^envmc``;
val n1 = thm "wrong_base0_rejected" ``!base0 pc. base0 <> pc ==> ~start_pc_ok ^gmc pc``
  (rpt strip_tac >> fs [start_pc_ok_def, mc_def, fix_def] >> show_tac "N1");
val n2 = thm "halt_stub_in_domain_rejected" ``!base0 pc. base0 - n2w ffi_offset IN (^envmc).prog_addresses ==> ~start_pc_ok ^gmc pc``
  (rpt strip_tac >> fs [start_pc_ok_def, mc_def, fix_def] >> show_tac "N2");
val n3 = thm "heap_on_halt_stub_rejected"
  ``h <=+ 0x1000040C0w /\ 0x1000040C0w <+ e /\ (^envmc).prog_addresses = refund_mem_dm h e ==> ~start_pc_ok ^RMC ^B``
  (strip_tac >> match_mp_tac n2 >> asm_simp_tac (srw_ss()) [mem_dm_def, ffi_offset_def] >> show_tac "N3");
val n4 = thm "ffi_entry_stub_in_domain_rejected" ``0x1000040A0w IN (^envmc).prog_addresses ==> ~start_pc_ok ^RMC ^B``
  (strip_tac >> strip_assume_tac names_thm >> mp_tac (SPEC ``names:ffiname list`` FLD) >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
   CCONTR_TAC >> fs [start_pc_ok_def] >> rfs [] >> first_x_assum (qspec_then `0` mp_tac) >> asm_simp_tac (srw_ss()) [ffi_offset_def] >> decide_tac);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val closure = "forge_refundResidual" :: Theory.ancestry "forge_refundResidual";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
