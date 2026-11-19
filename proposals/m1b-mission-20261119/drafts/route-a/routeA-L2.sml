(* Route A, lemma L2 (step C1, worker X7). DRAFT: NOT RUN. Higher risk than L1: the induction tactic was written by
   reading targetSemScript.sml (evaluate_def lines 118-218) and the stored proof of targetProps.evaluate_add_clock
   (targetPropsScript.sml 1059-1076); it has never been executed. Run only after routeA-L1.sml has exit 0.
   Parents: everything of deps-imp4.txt plus forge_refundRouteA1 (the L1 case).
   Content:
     D3. ffi_calls_ok P mc ffi k ms: a copy of the recursion of targetSem.evaluate; it is T where evaluate stops
         (TimeOut, Error, Halt, FFI_final), F at a SharedMem call, and at every ExtCall FFI_return it requires
         P ffi_index new_bytes ms (the call state and the oracle's answer) and continues like evaluate.
     L2.  if mc2 = mc1 with ffi_interfer := refund_ffi_tot Vok mc1.ffi_interfer and ffi_calls_ok Vok mc2 ffi k ms,
          then evaluate mc1 ffi k ms = evaluate mc2 ffi k ms. (Reachability is taken in the TOTALISED machine mc2.)
     L2S. the same for machine_sem when ffi_calls_ok holds for every clock.
     L2R. composition with the stored refund_profile_a_sl: the premise refund_env_ok_sl sl envmc is replaced by
          interference_ok, refund_ffi_contract_on with Vok, and ffi_calls_ok Vok at every clock in the totalised machine;
          the conclusion is the stored conclusion, term for term, for the REAL-effect record envmc.
   NOT proved here: that ffi_calls_ok holds for the refund program for any useful Vok (that is L3); anything native. *)
open preamble targetSemTheory targetPropsTheory ffiTheory semanticsPropsTheory fsFFITheory basis_ffiTheory TextIOProofTheory
     backendTheory asmPropsTheory lab_to_targetTheory arm8Theory arm8_targetTheory alignmentTheory miscTheory set_sepTheory
     backendProofTheory arm8_configProofTheory wordsLib blastLib forge_refundArm8CompileTheory forge_refundExclusionRealTheory
     forge_refundStartupClauseTheory forge_refundStartupBridgeTheory forge_refundInstalledDomainsTheory forge_refundInstalledAssemblyTheory
     forge_refundFfiFactsTheory forge_refundResidualTheory forge_refundEnvModelTheory forge_refundSourceNonFailTheory
     forge_refundProfileATheory forge_refundSlideEntryTheory forge_refundSlideDomainsTheory forge_refundSlideInstalledTheory
     forge_refundSlideSatTheory forge_refundSlideProfileATheory forge_refundRouteA1Theory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundRouteA2";
val failed = ref ([] : string list);
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun has_const n tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;
fun A1 n = DB.fetch "forge_refundRouteA1" n;
val TOT_T = A1 "refund_ffi_tot_valid";
val SHIFT = A1 "refund_ffi_tot_shift_seq";
val L1C = A1 "refund_env_ok_sl_of_contract_on";
val TA = DB.fetch "forge_refundSlideProfileA" "refund_profile_a_sl";
val mc_def = DB.fetch "forge_refundStartupBridge" "refund_mc_def";
val fix_def = DB.fetch "forge_refundStartupClause" "arm8_fix_def";
(* ================= D3 ================= *)
val _ = pr "MARK D3";
val calls_def = Define `
  (ffi_calls_ok (P:num -> word8 list -> 'b -> bool) (mc:('a,'b,'c) machine_config) (ffi:'ffi ffi_state) 0 (ms:'b) <=> T) /\
  (ffi_calls_ok P mc ffi (SUC k) ms <=>
     if mc.target.get_pc ms IN (mc.prog_addresses DIFF (set mc.ffi_entry_pcs)) then
       if encoded_bytes_in_mem mc.target.config (mc.target.get_pc ms) (mc.target.get_byte ms) mc.prog_addresses then
         let ms1 = mc.target.next ms in
         let (ms2,new_oracle) = apply_oracle mc.next_interfer ms1 in
         let mc = mc with next_interfer := new_oracle in
           if EVERY mc.target.state_ok [ms;ms1;ms2] /\
              (!x. x NOTIN mc.prog_addresses ==> mc.target.get_byte ms1 x = mc.target.get_byte ms x)
           then ffi_calls_ok P mc ffi k ms2
           else T
       else T
     else if mc.target.get_pc ms = mc.halt_pc then T
     else if mc.target.get_pc ms = mc.install_pc then
       (case read_ffi_bytearray mc mc.ptr_reg mc.len_reg ms of
        | SOME bytes =>
            let (ms1,new_oracle) = apply_oracle mc.install_interfer (bytes,ms) in
            let mc = mc with install_interfer := new_oracle in
              ffi_calls_ok P mc ffi k ms1
        | _ => T)
     else
       case find_index (mc.target.get_pc ms) mc.ffi_entry_pcs 0 of
       | NONE => T
       | SOME ffi_index =>
           (case EL ffi_index mc.ffi_names of
            | SharedMem op => F
            | ExtCall _ =>
                (case ALOOKUP mc.mmio_info ffi_index of
                 | SOME _ => T
                 | NONE =>
                     (case read_ffi_bytearrays mc ms of
                      | (SOME bytes, SOME bytes2) =>
                          (case call_FFI ffi (EL ffi_index mc.ffi_names) bytes bytes2 of
                           | FFI_final outcome => T
                           | FFI_return new_ffi new_bytes =>
                               P ffi_index new_bytes ms /\
                               (let (ms1,new_oracle) = apply_oracle mc.ffi_interfer (ffi_index,new_bytes,ms) in
                                let mc = mc with ffi_interfer := new_oracle in
                                  ffi_calls_ok P mc new_ffi k ms1))
                      | _ => T))))`;
val _ = pr ("DEFINITION " ^ thm_to_string calls_def);
(* ================= L2 ================= *)
val _ = pr "MARK L2";
fun leaf IH = rpt strip_tac >> fs [TOT_T, SHIFT] >> show_tac "L2-leaf" >>
              match_mp_tac IH >> fs [TOT_T, SHIFT] >>
              TRY (simp [machine_config_component_equality]) >> show_tac "L2-leaf-after";
val L2 = thm "refund_ffi_tot_evaluate_agree"
  ``!k mc1 mc2 ffi ms.
      mc2 = mc1 with ffi_interfer := refund_ffi_tot Vok mc1.ffi_interfer /\ ffi_calls_ok Vok mc2 ffi k ms ==>
      evaluate mc1 ffi k ms = evaluate mc2 ffi k ms``
  (Induct
   >- (rpt strip_tac >> once_rewrite_tac [evaluate_def] >> simp [])
   >> disch_then (fn IH =>
        rpt gen_tac >> strip_tac >> rveq >>
        qpat_x_assum `ffi_calls_ok _ _ _ _ _` mp_tac >>
        once_rewrite_tac [evaluate_def, calls_def] >>
        simp [apply_oracle_def, TOT_T, SHIFT] >>
        rpt (IF_CASES_TAC >> simp [TOT_T, SHIFT]) >>
        rpt (TOP_CASE_TAC >> simp [TOT_T, SHIFT]) >>
        leaf IH));
val _ = pr ("STATEMENT_L2 " ^ term_to_string (concl L2));
val L2S = thm "refund_ffi_tot_machine_sem_agree"
  ``!mc ffi ms.
      (!k. ffi_calls_ok Vok (mc with ffi_interfer := refund_ffi_tot Vok mc.ffi_interfer) ffi k ms) ==>
      machine_sem mc ffi ms = machine_sem (mc with ffi_interfer := refund_ffi_tot Vok mc.ffi_interfer) ffi ms``
  (rpt strip_tac >>
   `!k. evaluate mc ffi k ms = evaluate (mc with ffi_interfer := refund_ffi_tot Vok mc.ffi_interfer) ffi k ms` by
      (gen_tac >> match_mp_tac L2 >> simp []) >>
   simp [FUN_EQ_THM] >> Cases >> simp [machine_sem_def] >> show_tac "L2S");
(* ================= L2R: composition with the stored theorem ================= *)
val _ = pr "MARK L2R";
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val envmc = mk_var ("envmc", mcty);
val B = ``sl + 0x1000040D0w:word64``;
val envT = ``^envmc with ffi_interfer := refund_ffi_tot Vok (^envmc).ffi_interfer``;
val EQM = thm "refund_mc_totalised_record"
  ``refund_mc b (^envmc with ffi_interfer := g) = refund_mc b ^envmc with ffi_interfer := g``
  (simp [mc_def, fix_def] >> TRY (simp [mc_def, fix_def, machine_config_component_equality]) >> show_tac "EQM");
val FLD = thm "refund_mc_totalised_record_fields"
  ``(refund_mc b (^envmc with ffi_interfer := g)).target = (refund_mc b ^envmc).target /\
    (refund_mc b (^envmc with ffi_interfer := g)).install_pc = (refund_mc b ^envmc).install_pc /\
    (refund_mc b ^envmc).ffi_interfer = (^envmc).ffi_interfer``
  (simp [mc_def, fix_def]);
val (ta_ante, ta_conc) = dest_imp (concl TA);
val okp = ``refund_env_ok_sl sl ^envmc``;
val _ = if List.exists (aconv okp) (strip_conj ta_ante) then pr "PREMISE_FOUND refund_env_ok_sl sl envmc" else bad "premise-not-found";
val new_prems = List.concat (map (fn t => if aconv t okp then
      [``interference_ok (^envmc).next_interfer (arm8_target.proj (^envmc).prog_addresses)``,
       ``refund_ffi_contract_on ^B (^envmc).prog_addresses Vok (^envmc).ffi_interfer``,
       ``!ms k. forge_refundCmlMainStep$arm8_run 27 s = SOME ms ==>
                ffi_calls_ok Vok (refund_mc ^B ^envT) (basis_ffi ext cl fs) k ms``]
      else [t]) (strip_conj ta_ante));
val L2R = thm "refund_profile_a_sl_reach"
  (mk_imp (list_mk_conj new_prems, ta_conc))
  (strip_tac >>
   mp_tac (INST [envmc |-> envT] TA) >>
   impl_tac
   >- (rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >> TRY (simp [] >> NO_TAC) >>
       match_mp_tac L1C >> asm_rewrite_tac [] >> show_tac "L2R-prem") >>
   strip_tac >>
   `!k. evaluate (refund_mc ^B ^envmc) (basis_ffi ext cl fs) k ms = evaluate (refund_mc ^B ^envT) (basis_ffi ext cl fs) k ms` by
      (gen_tac >> match_mp_tac L2 >> conj_tac
       >- (rewrite_tac [EQM, FLD])
       >- (FIRST [simp [] >> NO_TAC, metis_tac []]) ) >>
   `machine_sem (refund_mc ^B ^envmc) (basis_ffi ext cl fs) ms = machine_sem (refund_mc ^B ^envT) (basis_ffi ext cl fs) ms` by
      (simp [FUN_EQ_THM] >> Cases >> asm_simp_tac (srw_ss()) [machine_sem_def]) >>
   (* the assumptions speak of refund_mc B envT; FLD turns their .target and .install_pc into those of refund_mc B envmc;
      the two equalities above turn the goal's evaluate and machine_sem terms into those of refund_mc B envT. *)
   qexists_tac `ms` >> RULE_ASSUM_TAC (REWRITE_RULE [FLD]) >> asm_rewrite_tac [] >>
   rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >> show_tac "L2R-end" >>
   qexists_tac `io_events` >> asm_rewrite_tac []);
(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = if aconv (snd (dest_imp (concl L2R))) ta_conc
        then pr "CONTROL_OK L2R conclusion is term-identical to the conclusion of the stored refund_profile_a_sl (not weakened)"
        else bad "L2R-conclusion";
val _ = if not (has_const "refund_env_ok_sl" (fst (dest_imp (concl L2R)))) andalso not (has_const "refund_ffi_contract_at" (fst (dest_imp (concl L2R))))
        then pr "CONTROL_OK L2R premises contain neither refund_env_ok_sl nor the all-states contract refund_ffi_contract_at"
        else bad "L2R-premises";
val _ = if length (strip_conj (fst (dest_imp (concl L2R)))) = length (strip_conj ta_ante) + 2
        then pr "CONTROL_OK L2R has the stored premises with exactly one replaced by three" else bad "L2R-premise-count";
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundRouteA2" @ DB.definitions "forge_refundRouteA2");
val closure = "forge_refundRouteA2" :: Theory.ancestry "forge_refundRouteA2";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundRouteA2")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
