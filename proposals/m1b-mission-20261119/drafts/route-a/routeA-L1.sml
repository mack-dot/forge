(* Route A, lemma L1 (step C1, worker X7). DRAFT: NOT RUN. Nothing in this file is proved until a run ends with exit 0
   and the marker EXACT_COMPLETE, and the tag check and the closure-axiom check pass.
   Content:
     D1. refund_ffi_contract_on b dm Vok ffi_i: the stored contract refund_ffi_contract_at b dm ffi_i (U409, theory
         forge_refundSlideProfileA) with ONE extra hypothesis Vok index new_bytes ms2 on the call. Built from the stored
         definition term, not retyped.
     D2. refund_ffi_tot Vok f: f where Vok holds, else the stored abstract effect refund_abs_ffi (U392).
     L1. refund_ffi_contract_on b dm Vok f ==> refund_ffi_contract_at b dm (refund_ffi_tot Vok f).
     L1C. the corollary for refund_env_ok_sl of the record whose ffi_interfer is totalised.
     S.  sanity: Vok = (\i nb ms. T) gives exactly the stored contract.
     N1. negative control: WITHOUT totalisation the implication is false (Vok = (\i nb ms. F), refund_bad_return_ffi).
     N2. negative control: a close-call predicate that EXCLUDES the U393 counterexample state (x3 = 0w); a stand-in
         effect that does not return there; it meets the on-form and fails the stored contract.
   NOT proved here: that any model of the real C code meets refund_ffi_contract_on (that is the native side, Q3b);
   L2 (agreement of the two machines at reachable calls); L3 (Vok at every reachable call of the refund program).
   L1 alone changes nothing about the real process. It is not "verified native execution". *)
open preamble targetSemTheory targetPropsTheory ffiTheory semanticsPropsTheory fsFFITheory basis_ffiTheory TextIOProofTheory
     backendTheory asmPropsTheory lab_to_targetTheory arm8Theory arm8_targetTheory alignmentTheory miscTheory set_sepTheory
     backendProofTheory arm8_configProofTheory wordsLib blastLib forge_refundArm8CompileTheory forge_refundExclusionRealTheory
     forge_refundStartupClauseTheory forge_refundStartupBridgeTheory forge_refundInstalledDomainsTheory forge_refundInstalledAssemblyTheory
     forge_refundFfiFactsTheory forge_refundResidualTheory forge_refundEnvModelTheory forge_refundSourceNonFailTheory
     forge_refundProfileATheory forge_refundSlideEntryTheory forge_refundSlideDomainsTheory forge_refundSlideInstalledTheory
     forge_refundSlideSatTheory forge_refundSlideProfileATheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundRouteA1";
val failed = ref ([] : string list);
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
(* No mk_thm anywhere. A failed lemma is recorded and replaced by TRUTH only so that later lines still run and print;
   the run raises Fail before export_theory if any lemma failed. *)
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun has_const n tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val envmc = mk_var ("envmc", mcty);
(* ---- Stored items used (all from theories loaded by deps-imp4.txt; names checked against the .sig files) ---- *)
fun SP n = DB.fetch "forge_refundSlideProfileA" n;
fun EM n = DB.fetch "forge_refundEnvModel" n;
val contract_at_def = SP "refund_ffi_contract_at_def";
val ok_sl_def = SP "refund_env_ok_sl_def";
val AB = SP "refund_abs_ffi_contract_at";                        (* !b dm. refund_ffi_contract_at b dm refund_abs_ffi *)
val R0 = SP "refund_ffi_contract_at_link_base_is_the_old_contract";
val abs_def = EM "refund_abs_ffi_def";
val bad_ret_def = EM "refund_bad_return_ffi_def";
val msw_def = EM "refund_ffi_witness_state_def";
val WIT = EM "refund_ffi_contract_at_witness";
val _ = List.app (fn (n, th) => pr ("USED " ^ n ^ "\n" ^ thm_to_string th))
          [("refund_ffi_contract_at_def", contract_at_def), ("refund_env_ok_sl_def", ok_sl_def), ("refund_abs_ffi_contract_at", AB),
           ("refund_abs_ffi_def", abs_def), ("refund_bad_return_ffi_def", bad_ret_def), ("refund_ffi_witness_state_def", msw_def),
           ("refund_ffi_contract_at_witness", WIT), ("refund_ffi_contract_at_link_base_is_the_old_contract", R0)];
val tg = prove (``arm8_target.get_pc (ms:arm8_state) = ms.PC /\ arm8_target.get_byte ms = ms.MEM /\ arm8_target.get_reg ms r = ms.REG (n2w r) /\
                  arm8_target.state_ok = arm8_ok /\ arm8_target.config.code_alignment = 2 /\ arm8_target.config.link_reg = SOME 30 /\
                  arm8_target.config.reg_count = 32 /\ arm8_target.config.avoid_regs = [18; 26; 31]``,
  simp [arm8_target_def, arm8_config_def, FUN_EQ_THM]);
(* ================= D1, D2 ================= *)
val _ = pr "MARK D";
val ([bv, dmv, ffiv], ceq) = strip_forall (concl contract_at_def);
val (_, cat_rhs) = dest_eq ceq;
val (qvs, cimp) = strip_forall cat_rhs;
val [kv, iv, nbv, msv2, t1v, bsv, bs2v] = qvs;
val (chyp, cconc) = dest_imp cimp;
val Vty = ``:num -> word8 list -> arm8_state -> bool``;
val Vv = mk_var ("Vok", Vty);
val on_hyps = strip_conj chyp @ [list_mk_comb (Vv, [iv, nbv, msv2])];
val on_body = list_mk_forall (qvs, mk_imp (list_mk_conj on_hyps, cconc));
val on_c = mk_var ("refund_ffi_contract_on", type_of bv --> type_of dmv --> Vty --> type_of ffiv --> bool);
val on_def = new_definition ("refund_ffi_contract_on_def", mk_eq (list_mk_comb (on_c, [bv, dmv, Vv, ffiv]), on_body));
val _ = pr ("DEFINITION " ^ thm_to_string on_def);
val tot_def = new_definition ("refund_ffi_tot_def",
  ``refund_ffi_tot (Vok:num -> word8 list -> arm8_state -> bool) (f:num -> num # word8 list # arm8_state -> arm8_state) (k:num)
                   (x:num # word8 list # arm8_state) =
      if Vok (FST x) (FST (SND x)) (SND (SND x)) then f k x else refund_abs_ffi k x``);
val _ = pr ("DEFINITION " ^ thm_to_string tot_def);
(* Structural controls on D1: exactly one hypothesis more than the stored contract, same conclusions, same binders. *)
val (_, on_rhs) = dest_eq (snd (strip_forall (concl on_def)));
val (on_qvs, on_imp) = strip_forall on_rhs;
val (on_h, on_c2) = dest_imp on_imp;
val _ = if length (strip_conj on_h) = length (strip_conj chyp) + 1 andalso aconv on_c2 cconc andalso length on_qvs = 7
        then pr "CONTROL_OK refund_ffi_contract_on = stored contract body + exactly one hypothesis (Vok index new_bytes ms2); conclusions identical"
        else bad "on-definition shape";
(* Text check (non-fatal; the DEFINITION line above is authoritative): the definition equals this literal reading. *)
val _ = (if aconv (concl on_def)
  ``!(b:word64) (dm:word64 set) (Vok:num -> word8 list -> arm8_state -> bool) (ffi_i:num -> num # word8 list # arm8_state -> arm8_state).
      refund_ffi_contract_on b dm Vok ffi_i <=>
      !k index new_bytes ms2 (t1:64 asm_state) bytes bytes2.
        index < 4 /\ t1.mem_domain = dm /\
        read_bytearray (ms2.REG 0w) (w2n (ms2.REG 1w)) (\a. if a IN dm then SOME (ms2.MEM a) else NONE) = SOME bytes /\
        read_bytearray (ms2.REG 2w) (w2n (ms2.REG 3w)) (\a. if a IN dm then SOME (ms2.MEM a) else NONE) = SOME bytes2 /\
        LENGTH new_bytes = LENGTH bytes2 /\
        target_state_rel arm8_target (t1 with pc := b - n2w ((3 + index) * 16)) ms2 /\ aligned 2 (t1.regs 30) /\
        Vok index new_bytes ms2 ==>
        arm8_ok (ffi_i k (index,new_bytes,ms2)) /\ (ffi_i k (index,new_bytes,ms2)).PC = t1.regs 30 /\
        (!a. a IN dm ==> (ffi_i k (index,new_bytes,ms2)).MEM a = asm_write_bytearray (t1.regs 2) new_bytes t1.mem a) /\
        (!r. MEM r [19;20;21;22;23;24;25;27;28] ==> (ffi_i k (index,new_bytes,ms2)).REG (n2w r) = t1.regs r)``
  then pr "TEXT_CHECK_OK refund_ffi_contract_on_def" else pr "TEXT_CHECK_MISMATCH refund_ffi_contract_on_def")
  handle e => pr ("TEXT_CHECK_MISMATCH refund_ffi_contract_on_def (parse) " ^ General.exnMessage e);
(* ================= helper lemmas on D2 ================= *)
val _ = pr "MARK H";
val TOT_T = thm "refund_ffi_tot_valid"
  ``!Vok f k index new_bytes ms2. Vok index new_bytes ms2 ==> refund_ffi_tot Vok f k (index,new_bytes,ms2) = f k (index,new_bytes,ms2)``
  (rpt strip_tac >> asm_simp_tac (srw_ss()) [tot_def]);
val TOT_F = thm "refund_ffi_tot_invalid"
  ``!Vok f k index new_bytes ms2. ~Vok index new_bytes ms2 ==>
      refund_ffi_tot Vok f k (index,new_bytes,ms2) = refund_abs_ffi k (index,new_bytes,ms2)``
  (rpt strip_tac >> asm_simp_tac (srw_ss()) [tot_def]);
val TOT_ID = thm "refund_ffi_tot_all_valid_is_identity" ``!f. refund_ffi_tot (\i nb ms. T) f = f``
  (simp [FUN_EQ_THM, tot_def]);
(* Needed by L2: evaluate shifts ffi_interfer by apply_oracle (shift_seq 1) after every FFI call. refund_abs_ffi ignores k. *)
val SHIFT = thm "refund_ffi_tot_shift_seq"
  ``!n Vok f. shift_seq n (refund_ffi_tot Vok f) = refund_ffi_tot Vok (shift_seq n f)``
  (simp [FUN_EQ_THM, shift_seq_def, tot_def, abs_def]);
(* ================= L1 ================= *)
val _ = pr "MARK L1";
val L1 = thm "refund_ffi_contract_on_totalises"
  ``!b dm Vok f. refund_ffi_contract_on b dm Vok f ==> refund_ffi_contract_at b dm (refund_ffi_tot Vok f)``
  (rpt gen_tac >> rewrite_tac [on_def, contract_at_def] >> disch_then (fn ON =>
     rpt gen_tac >> strip_tac >> Cases_on `Vok index new_bytes ms2`
     >- (first_assum (fn th => rewrite_tac [MATCH_MP TOT_T th]) >>
         mp_tac (Q.SPECL [`k`, `index`, `new_bytes`, `ms2`, `t1`, `bytes`, `bytes2`] ON) >> asm_rewrite_tac [] >> show_tac "L1-valid")
     >- (first_assum (fn th => rewrite_tac [MATCH_MP TOT_F th]) >>
         mp_tac (Q.SPECL [`k`, `index`, `new_bytes`, `ms2`, `t1`, `bytes`, `bytes2`]
                   (REWRITE_RULE [contract_at_def] (Q.SPECL [`b`, `dm`] AB))) >>
         asm_rewrite_tac [] >> show_tac "L1-invalid")));
val _ = pr ("STATEMENT_L1 " ^ term_to_string (concl L1));
(* ================= L1C: corollary for the environment predicate ================= *)
val UPD = thm "refund_env_with_ffi_interfer_fields"
  ``(^envmc with ffi_interfer := g).next_interfer = (^envmc).next_interfer /\
    (^envmc with ffi_interfer := g).prog_addresses = (^envmc).prog_addresses /\
    (^envmc with ffi_interfer := g).ffi_interfer = g``
  (simp []);
val L1C = thm "refund_env_ok_sl_of_contract_on"
  ``interference_ok (^envmc).next_interfer (arm8_target.proj (^envmc).prog_addresses) /\
    refund_ffi_contract_on (sl + 0x1000040D0w) (^envmc).prog_addresses Vok (^envmc).ffi_interfer ==>
    refund_env_ok_sl sl (^envmc with ffi_interfer := refund_ffi_tot Vok (^envmc).ffi_interfer)``
  (strip_tac >> rewrite_tac [ok_sl_def, UPD] >> conj_tac
   >- first_assum ACCEPT_TAC
   >- (match_mp_tac L1 >> first_assum ACCEPT_TAC));
(* ================= S: sanity ================= *)
val _ = pr "MARK S";
val S1 = thm "refund_ffi_contract_on_all_valid_is_the_stored_contract"
  ``!b dm f. refund_ffi_contract_on b dm (\i nb ms. T) f <=> refund_ffi_contract_at b dm f``
  (rpt gen_tac >> rewrite_tac [on_def, contract_at_def] >> BETA_TAC >> rewrite_tac []);
(* ================= N1: totalisation is needed ================= *)
val _ = pr "MARK N1";
val N1 = thm "contract_on_without_totalisation_is_not_the_stored_contract"
  ``~(!b dm Vok f. refund_ffi_contract_on b dm Vok f ==> refund_ffi_contract_at b dm f)``
  (strip_tac >>
   first_x_assum (qspecl_then [`0x1000040D0w`, `dm`, `\i nb ms. F`, `refund_bad_return_ffi`] mp_tac) >>
   impl_tac >- (rewrite_tac [on_def] >> BETA_TAC >> rewrite_tac [] >> show_tac "N1-vacuous") >>
   rewrite_tac [R0] >> strip_tac >> drule WIT >> disch_then (qspec_then `0` mp_tac) >>
   simp [bad_ret_def, abs_def, msw_def] >> show_tac "N1-witness");
val N1b = thm "bad_return_ffi_totalised_with_empty_predicate_meets_contract"
  ``!b dm. refund_ffi_contract_at b dm (refund_ffi_tot (\i nb ms. F) refund_bad_return_ffi)``
  (rpt gen_tac >> match_mp_tac L1 >> rewrite_tac [on_def] >> BETA_TAC >> rewrite_tac []);
(* ================= N2: the U393 close state ================= *)
val _ = pr "MARK N2";
(* refund_close_call_valid: the conditions under which the real fficlose (basis_ffi.c 191-197) does not abort:
   assert(alen >= 1) on the signed long x3 and assert(clen == 8) on x1. Other indices: no condition here.
   The real code at x3 = 0w: U394 theorem zero_alen_reaches_assert_block (theory forge_refundFficloseCompose,
   results/refund-fficlose-compose-local-20261116/attempt-0001/compose-0018): from PC 0x100004080w with s.REG 3w = 0w (and the
   frame premises) 6 L3 steps reach 0x1000252A4w, the call into the assertion block (__assert_rtn, abort). Slide 0 only.
   Also invalid_clen_reaches_assert_block (x1 <> 8w, x3 <> 0w, not word_msb x3: 8 steps to 0x1000252A8w) and
   negative_alen_not_covered (U396). Those native steps are NOT re-proved here. *)
val vclose_def = new_definition ("refund_close_call_valid_def",
  ``refund_close_call_valid (i:num) (nb:word8 list) (ms:arm8_state) <=>
      (i = 2 ==> ms.REG 1w = 8w /\ ms.REG 3w <> 0w /\ ~word_msb (ms.REG 3w))``);
(* A STAND-IN for "control does not return": where the close predicate fails, the effect jumps to the address of the
   assertion block (slide 0). It is NOT a model of the C code. Where the predicate holds it is the abstract effect. *)
val abort_def = new_definition ("refund_close_abort_model_ffi_def",
  ``refund_close_abort_model_ffi (k:num) (x:num # word8 list # arm8_state) =
      if refund_close_call_valid (FST x) (FST (SND x)) (SND (SND x)) then refund_abs_ffi k x
      else (SND (SND x)) with PC := 0x1000252A4w``);
val W2 = ``refund_ffi_witness_state with PC := 0x100004080w``;   (* close stub at slide 0: 0x1000040D0 - (3+2)*16 *)
val N2a = thm "refund_close_call_valid_excludes_zero_alen"
  ``!nb ms. ms.REG 3w = 0w ==> ~refund_close_call_valid 2 nb ms``
  (rpt strip_tac >> fs [vclose_def]);
val N2a2 = thm "refund_close_call_valid_rejects_u393_witness" ``~refund_close_call_valid 2 [] ^W2``
  (simp [vclose_def, msw_def]);
val N2b = thm "stored_contract_demands_return_at_u393_close_state"
  ``!dm ffi_i. refund_ffi_contract_at 0x1000040D0w dm ffi_i ==> (ffi_i 0 (2,[],^W2)).PC = 0w``
  (rewrite_tac [contract_at_def] >> rpt gen_tac >>
   disch_then (qspecl_then [`0`, `2`, `[]`, `^W2`,
      `<| regs := (\i. 0w); fp_regs := (\i. 0w); mem := (^W2).MEM; mem_domain := dm; pc := ARB; lr := 30; align := 2; be := F; failed := F |>`,
      `[]`, `[]`] mp_tac) >>
   impl_tac
   >- (simp [msw_def, read_bytearray_def, target_state_rel_def, tg, arm8_ok_def] >> simp [arm8_target_def, arm8_config_def] >>
       EVAL_TAC >> show_tac "N2b-hyps")
   >- (strip_tac >> asm_rewrite_tac [] >> simp [] >> show_tac "N2b-pc"));
val N2c = thm "close_abort_model_satisfies_contract_on"
  ``!b dm. refund_ffi_contract_on b dm refund_close_call_valid refund_close_abort_model_ffi``
  (rpt gen_tac >> rewrite_tac [on_def] >> rpt gen_tac >> strip_tac >>
   `refund_close_abort_model_ffi k (index,new_bytes,ms2) = refund_abs_ffi k (index,new_bytes,ms2)` by
      (asm_simp_tac (srw_ss()) [abort_def] >> show_tac "N2c-a") >>
   pop_assum (fn th => rewrite_tac [th]) >>
   mp_tac (Q.SPECL [`k`, `index`, `new_bytes`, `ms2`, `t1`, `bytes`, `bytes2`] (REWRITE_RULE [contract_at_def] (Q.SPECL [`b`, `dm`] AB))) >>
   asm_rewrite_tac [] >> show_tac "N2c-b");
val N2d = thm "close_abort_model_fails_stored_contract"
  ``!dm. ~refund_ffi_contract_at 0x1000040D0w dm refund_close_abort_model_ffi``
  (gen_tac >> strip_tac >> drule N2b >> simp [abort_def, vclose_def, msw_def] >> show_tac "N2d");
val N2e = thm "close_abort_model_totalised_meets_stored_contract"
  ``!b dm. refund_ffi_contract_at b dm (refund_ffi_tot refund_close_call_valid refund_close_abort_model_ffi)``
  (rpt gen_tac >> match_mp_tac L1 >> MATCH_ACCEPT_TAC N2c);
(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = if is_neg (concl N1) then pr "CONTROL_OK N1 is a proved negation: without totalisation the on-form does not give the stored contract"
        else bad "N1-not-negation";
val _ = if is_neg (snd (strip_forall (concl N2d))) then pr "CONTROL_OK N2 the stand-in that does not return at the U393 close state fails the stored contract"
        else bad "N2d-not-negation";
val _ = if is_neg (concl N2a2) then pr "CONTROL_OK N2 the close predicate rejects the U393 state (x1 = 0w, x3 = 0w at PC 0x100004080w)"
        else bad "N2a2-not-negation";
val _ = let val (a, c) = dest_imp (snd (strip_forall (concl L1))) in
          if has_const "refund_ffi_contract_on" a andalso not (has_const "refund_ffi_contract_at" a) andalso has_const "refund_ffi_tot" c
          then pr "CONTROL_OK L1: premise is the on-form only; conclusion is the stored contract at the totalised effect" else bad "L1-shape" end
        handle _ => bad "L1-shape";
val _ = if aconv (concl L1) ``!b dm Vok f. refund_ffi_contract_on b dm Vok f ==> refund_ffi_contract_at b dm (refund_ffi_tot Vok f)``
        then pr "CONTROL_OK L1 statement is the literal planned statement" else bad "L1-literal";
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundRouteA1" @ DB.definitions "forge_refundRouteA1");
val closure = "forge_refundRouteA1" :: Theory.ancestry "forge_refundRouteA1";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundRouteA1")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundRouteA1")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
