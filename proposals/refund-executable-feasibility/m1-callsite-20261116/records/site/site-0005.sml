(* U395: argument validity at reachable close call states of the MODEL machine.
   Reachability is defined over the published machine evaluation function. Oracle success at a call is DERIVED from a behaviour
   inclusion (a failed call puts an FFI outcome or Fail into machine_sem); it is not assumed. Only the name close (index 2).
   The model machine is not the real process: no claim about libSystem, the loader, the slide or the real environment. *)
open preamble targetSemTheory asmPropsTheory lab_to_targetTheory arm8Theory arm8_targetTheory alignmentTheory miscTheory ffiTheory
     semanticsPropsTheory fsFFITheory basis_ffiTheory forge_refundStartupBridgeTheory forge_refundStartupClauseTheory
     forge_refundInstalledDomainsTheory forge_refundFfiFactsTheory forge_refundResidualTheory forge_refundEnvModelTheory
     forge_refundFficloseStepTheory forge_refundFficloseBridgeTheory forge_refundFficloseComposeTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundCallSite";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val mc = mk_var ("mc", mcty); val mc1 = mk_var ("mc1", mcty); val mc' = mk_var ("mc'", mcty);
val names = ``[ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»]``;
(* ---- 1. Static record facts and semantic reachability. ---- *)
val static_def = new_definition ("refund_static_def", ``refund_static ^mc (dm:word64 set) <=>
   mc.ffi_names = ^names /\ mc.ffi_entry_pcs = [0x1000040A0w; 0x100004090w; 0x100004080w; 0x100004070w] /\
   mc.halt_pc = 0x1000040C0w /\ mc.install_pc = 0x1000040B0w /\ mc.mmio_info = [] /\ mc.prog_addresses = dm /\
   0x100004080w NOTIN dm /\ mc.target = arm8_target /\ mc.ptr_reg = 0 /\ mc.len_reg = 1 /\ mc.ptr2_reg = 2 /\ mc.len2_reg = 3``);
val seq_def = new_definition ("mc_static_eq_def", ``mc_static_eq ^mc ^mc' <=>
   mc'.ffi_names = mc.ffi_names /\ mc'.ffi_entry_pcs = mc.ffi_entry_pcs /\ mc'.halt_pc = mc.halt_pc /\ mc'.install_pc = mc.install_pc /\
   mc'.mmio_info = mc.mmio_info /\ mc'.prog_addresses = mc.prog_addresses /\ mc'.target = mc.target /\ mc'.ptr_reg = mc.ptr_reg /\
   mc'.len_reg = mc.len_reg /\ mc'.ptr2_reg = mc.ptr2_reg /\ mc'.len2_reg = mc.len2_reg``);
val step_def = new_definition ("machine_step_def",
  ``machine_step ^mc (ffi:'ffi ffi_state) (ms:arm8_state) ^mc' (ffi':'ffi ffi_state) (ms':arm8_state) <=>
      (!k. targetSem$evaluate mc ffi (k + 1) ms = targetSem$evaluate mc' ffi' k ms') /\ ffi'.oracle = ffi.oracle /\ mc_static_eq mc mc'``);
val reachn_def = Define `
  (machine_reach_n 0 ^mc (ffi:'ffi ffi_state) (ms:arm8_state) ^mc1 (ffi1:'ffi ffi_state) (ms1:arm8_state) <=>
      mc1 = mc /\ ffi1 = ffi /\ ms1 = ms) /\
  (machine_reach_n (SUC n) mc ffi ms mc1 ffi1 ms1 <=>
      ?mc' ffi' ms'. machine_step mc ffi ms mc' ffi' ms' /\ machine_reach_n n mc' ffi' ms' mc1 ffi1 ms1)`;
val reach_def = new_definition ("machine_reach_def",
  ``machine_reach ^mc (ffi:'ffi ffi_state) (ms:arm8_state) ^mc1 (ffi1:'ffi ffi_state) (ms1:arm8_state) <=>
      ?n. machine_reach_n n mc ffi ms mc1 ffi1 ms1``);
val _ = List.app (fn d => pr ("DEFINITION " ^ thm_to_string d)) [static_def, seq_def, step_def, reachn_def, reach_def];
val seq_refl = prove (``mc_static_eq ^mc mc``, simp [seq_def]);
val seq_trans = prove (``mc_static_eq ^mc ^mc' /\ mc_static_eq mc' ^mc1 ==> mc_static_eq mc mc1``, simp [seq_def]);
val static_seq = prove (``refund_static ^mc dm /\ mc_static_eq mc ^mc1 ==> refund_static mc1 dm``, simp [static_def, seq_def]);
val R1 = thm "machine_reach_n_evaluate"
  ``!n mc ffi ms mc1 ffi1 ms1. machine_reach_n n ^mc (ffi:'ffi ffi_state) ms ^mc1 ffi1 ms1 ==>
      (!k. targetSem$evaluate mc ffi (k + n) ms = targetSem$evaluate mc1 ffi1 k ms1) /\ ffi1.oracle = ffi.oracle /\ mc_static_eq mc mc1``
  (Induct >> simp [reachn_def, seq_refl] >> rpt gen_tac >> strip_tac >> first_x_assum drule >> strip_tac >>
   fs [step_def] >> conj_tac
   >- (gen_tac >> `k + SUC n = (k + n) + 1` by decide_tac >> asm_rewrite_tac [])
   >- (metis_tac [seq_trans]));
(* Real transitions are machine steps (so the relation covers them). *)
val S1 = thm "normal_step_is_machine_step"
  ``mc.target.get_pc ms IN (mc.prog_addresses DIFF set mc.ffi_entry_pcs) /\
    encoded_bytes_in_mem mc.target.config (mc.target.get_pc ms) (mc.target.get_byte ms) mc.prog_addresses /\
    EVERY mc.target.state_ok [ms; mc.target.next ms; mc.next_interfer 0 (mc.target.next ms)] /\
    (!x. x NOTIN mc.prog_addresses ==> mc.target.get_byte (mc.target.next ms) x = mc.target.get_byte ms x) ==>
    machine_step ^mc (ffi:'ffi ffi_state) ms (mc with next_interfer := shift_seq 1 mc.next_interfer) ffi (mc.next_interfer 0 (mc.target.next ms))``
  (strip_tac >> simp [step_def, seq_def] >> gen_tac >> simp [Once evaluate_def, apply_oracle_def] >> fs []);
val FR = thm "call_FFI_return_keeps_oracle"
  ``call_FFI (st:'ffi ffi_state) nm cbytes abytes = FFI_return st' nb ==> st'.oracle = st.oracle``
  (rw [call_FFI_def] >> gvs [AllCaseEqs()]);
val S2 = thm "extcall_step_is_machine_step"
  ``mc.target.get_pc ms NOTIN (mc.prog_addresses DIFF set mc.ffi_entry_pcs) /\ mc.target.get_pc ms <> mc.halt_pc /\
    mc.target.get_pc ms <> mc.install_pc /\ find_index (mc.target.get_pc ms) mc.ffi_entry_pcs 0 = SOME i /\
    EL i mc.ffi_names = ExtCall nm /\ ALOOKUP mc.mmio_info i = NONE /\ read_ffi_bytearrays mc ms = (SOME cbytes, SOME abytes) /\
    call_FFI (ffi:'ffi ffi_state) (ExtCall nm) cbytes abytes = FFI_return new_ffi nb ==>
    machine_step ^mc ffi ms (mc with ffi_interfer := shift_seq 1 mc.ffi_interfer) new_ffi (mc.ffi_interfer 0 (i, nb, ms))``
  (strip_tac >> imp_res_tac FR >> simp [step_def, seq_def] >> gen_tac >> simp [Once evaluate_def, apply_oracle_def]);
val R0 = thm "machine_reach_refl" ``machine_reach ^mc (ffi:'ffi ffi_state) ms mc ffi ms``
  (simp [reach_def] >> qexists_tac `0` >> simp [reachn_def]);
(* ---- 2. A close call state of a record with the static facts. ---- *)
val tg = prove (``arm8_target.get_pc (ms:arm8_state) = ms.PC /\ arm8_target.get_byte ms = ms.MEM /\ arm8_target.get_reg ms r = ms.REG (n2w r)``,
  simp [arm8_target_def, FUN_EQ_THM]);
val C1a = thm "close_call_final_halts"
  ``refund_static ^mc1 dm /\ ms1.PC = 0x100004080w /\ read_ffi_bytearrays mc1 ms1 = (SOME cbytes, SOME abytes) /\
    call_FFI (ffi1:'ffi ffi_state) (ExtCall «close») cbytes abytes = FFI_final outcome ==>
    targetSem$evaluate mc1 ffi1 1 ms1 = (Halt (FFI_outcome outcome), ms1, ffi1)``
  (rw [static_def] >> simp [Once evaluate_def, tg, find_index_def]);
val C1b = thm "close_call_unreadable_errors"
  ``refund_static ^mc1 dm /\ ms1.PC = 0x100004080w /\ ~(?cbytes abytes. read_ffi_bytearrays mc1 ms1 = (SOME cbytes, SOME abytes)) ==>
    FST (targetSem$evaluate mc1 (ffi1:'ffi ffi_state) 1 ms1) = Error``
  (rw [static_def] >> simp [Once evaluate_def, tg, find_index_def] >>
   Cases_on `read_ffi_bytearrays mc1 ms1` >> rename1 `(q1, q2)` >> Cases_on `q1` >> Cases_on `q2` >> fs []);
val O1 = DB.fetch "forge_refundFficloseCompose" "ffi_close_accepts_only_valid_lengths";
val bty = type_of ``basis_ffi ext cl fs``;
val C2 = thm "close_call_return_lengths"
  ``(ffi1:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\ call_FFI ffi1 (ExtCall «close») cbytes abytes = FFI_return new_ffi nb ==>
    LENGTH cbytes = 8 /\ 1 <= LENGTH abytes``
  (strip_tac >> pop_assum mp_tac >> simp [call_FFI_def, basis_ffi_oracle_def] >>
   Cases_on `ffi1.ffi_state` >> simp [] >> rpt (CASE_TAC >> simp []) >> rpt strip_tac >> imp_res_tac O1 >> fs []);
val C3 = thm "close_call_read_lengths"
  ``refund_static ^mc1 dm /\ read_ffi_bytearrays mc1 ms1 = (SOME cbytes, SOME abytes) ==>
    LENGTH cbytes = w2n (ms1.REG 1w) /\ LENGTH abytes = w2n (ms1.REG 3w)``
  (rw [static_def, read_ffi_bytearrays_def, read_ffi_bytearray_def] >> imp_res_tac read_bytearray_LENGTH >> fs [tg]);
val E1 = thm "fail_not_in_success_limit" ``Fail NOTIN extend_with_resource_limit {Terminate Success io}``
  (simp [extend_with_resource_limit_def]);
val E2 = thm "ffi_outcome_not_in_success_limit" ``Terminate (FFI_outcome fo) l NOTIN extend_with_resource_limit {Terminate Success io}``
  (simp [extend_with_resource_limit_def]);
val E3 = thm "resource_limit_is_in_success_limit" ``Terminate Resource_limit_hit [] IN extend_with_resource_limit {Terminate Success io}``
  (simp [extend_with_resource_limit_def]);
(* ---- 3. Main theorem: argument validity at every reachable close call state. ---- *)
val D = thm "close_call_site_arguments"
  ``machine_reach ^mc (ffi:^(ty_antiq bty)) ms ^mc1 ffi1 ms1 /\ refund_static mc dm /\ ffi.oracle = basis_ffi_oracle ext /\
    machine_sem mc ffi ms SUBSET extend_with_resource_limit {Terminate Success io} /\ ms1.PC = 0x100004080w ==>
    ms1.REG 1w = 8w /\ ms1.REG 3w <> 0w /\
    ?cbytes abytes. read_ffi_bytearrays mc1 ms1 = (SOME cbytes, SOME abytes) /\ LENGTH cbytes = 8 /\ 1 <= LENGTH abytes``
  (rewrite_tac [reach_def] >> strip_tac >> drule R1 >> strip_tac >>
   `refund_static mc1 dm` by metis_tac [static_seq] >>
   `ffi1.oracle = basis_ffi_oracle ext` by metis_tac [] >>
   `?cbytes abytes. read_ffi_bytearrays mc1 ms1 = (SOME cbytes, SOME abytes)` by
      (CCONTR_TAC >> `FST (targetSem$evaluate mc1 ffi1 1 ms1) = Error` by (match_mp_tac C1b >> metis_tac []) >>
       `machine_sem mc ffi ms Fail` by (simp [machine_sem_def] >> qexists_tac `1 + n` >> metis_tac []) >>
       fs [SUBSET_DEF, IN_DEF] >> res_tac >> metis_tac [E1, IN_DEF]) >>
   Cases_on `call_FFI ffi1 (ExtCall «close») cbytes abytes`
   >- (drule_all C2 >> strip_tac >> drule_all C3 >> strip_tac >>
       `ms1.REG 1w = n2w (w2n (ms1.REG 1w))` by simp [] >>
       `ms1.REG 3w <> 0w` by (strip_tac >> fs []) >>
       `ms1.REG 1w = 8w` by (pop_assum kall_tac >> pop_assum SUBST1_TAC >> qpat_x_assum `LENGTH cbytes = w2n _` (SUBST1_TAC o SYM) >> asm_rewrite_tac []) >>
       metis_tac [])
   >- (rename1 `FFI_final fo` >>
       `targetSem$evaluate mc1 ffi1 1 ms1 = (Halt (FFI_outcome fo), ms1, ffi1)` by (match_mp_tac C1a >> metis_tac []) >>
       `machine_sem mc ffi ms (Terminate (FFI_outcome fo) ffi1.io_events)` by
          (simp [machine_sem_def] >> qexistsl_tac [`1 + n`, `ms1`, `ffi1`] >> metis_tac []) >>
       fs [SUBSET_DEF, IN_DEF] >> res_tac >> metis_tac [E2, IN_DEF]));
(* ---- 4. The model record of U392 and the composition with cake_fficlose_path. ---- *)
val envmc = mk_var ("envmc", mcty);
val AMC = ``refund_mc 0x1000040D0w (refund_abs_env ^envmc)``;
val bffi = ``basis_ffi ext cl fs``;
val names4 = DB.fetch "forge_refundEnvModel" "refund_ffi_names_list";
val FLD = DB.fetch "forge_refundResidual" "refund_mc_concrete_fields";
val flds2 = DB.fetch "forge_refundEnvModel" "refund_mc_register_fields";
val stub_out = DB.fetch "forge_refundResidual" "refund_stub_outside_domain";
val env_def = DB.fetch "forge_refundEnvModel" "refund_abs_env_def";
val sub_env = [envmc |-> ``refund_abs_env ^envmc``];
val fld1 = INST sub_env (MP (SPEC names FLD) (prove (``refund_lab_conf2.ffi_names = SOME ^names /\ LENGTH ^names = 4``, simp [names4])));
val fld2 = INST sub_env flds2;
val env_prog = prove (``(refund_abs_env ^envmc).prog_addresses = (^envmc).prog_addresses``, simp [env_def]);
val ST = thm "refund_abs_record_static"
  ``refund_heap_clear h e /\ (^envmc).prog_addresses = refund_mem_dm h e ==> refund_static ^AMC (refund_mem_dm h e)``
  (strip_tac >> asm_simp_tac (srw_ss()) [static_def, fld1, fld2, env_prog] >> match_mp_tac stub_out >> asm_rewrite_tac [] >> EVAL_TAC);
val A2 = DB.fetch "forge_refundEnvModel" "refund_behavior_abstract_env";
val (a2ant, _) = dest_imp (concl A2);
val fvD = fn n => valOf (List.find (fn v => fst (dest_var v) = n) (free_vars (concl D)));
val D_i = INST [fvD "mc" |-> AMC, fvD "ffi" |-> bffi, fvD "dm" |-> ``refund_mem_dm h e``, fvD "io" |-> mk_var ("io_events", type_of (fvD "io")),
                fvD "ms" |-> ``ms:arm8_state``] D;
val Fth = thm "close_call_site_arguments_model"
  ``^a2ant ==> ?ms. arm8_run 27 s = SOME ms /\ ms.PC = 0x1000040D0w /\
       !mc1 ffi1 ms1. machine_reach ^AMC ^bffi ms mc1 ffi1 ms1 /\ ms1.PC = 0x100004080w ==> ms1.REG 1w = 8w /\ ms1.REG 3w <> 0w``
  (strip_tac >> mp_tac A2 >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >> qexists_tac `ms` >> asm_rewrite_tac [] >>
   rpt gen_tac >> strip_tac >> mp_tac D_i >>
   (impl_tac >- (asm_rewrite_tac [] >> conj_tac >- (match_mp_tac ST >> asm_rewrite_tac []) >> simp [basis_ffi_def])) >>
   strip_tac >> asm_rewrite_tac []);
val pre_def = DB.fetch "forge_refundFficloseCompose" "fficlose_call_pre_def";
val Mpath = DB.fetch "forge_refundFficloseCompose" "cake_fficlose_path";
val (pl, pr') = dest_eq (snd (strip_forall (concl pre_def)));
val pargs = snd (strip_comb pl);
val sv = List.nth (pargs, 1);
val dropped = [``(^sv).REG 1w = 8w``, ``(^sv).REG 3w <> 0w``];
val kept = List.filter (fn cj => not (List.exists (aconv cj) dropped)) (strip_conj pr');
val _ = if length kept + 2 = length (strip_conj pr') then pr ("PREMISES_KEPT " ^ Int.toString (length kept) ^ " DROPPED 2") else raise Fail "premise split";
val weak_c = mk_var ("fficlose_call_pre_no_len", list_mk_fun (map type_of pargs, bool));
val weak_def = new_definition ("fficlose_call_pre_no_len_def", mk_eq (list_mk_comb (weak_c, pargs), list_mk_conj kept));
val _ = pr ("DEFINITION " ^ thm_to_string weak_def);
val weak_tm = lhs (snd (strip_forall (concl weak_def)));
val PW = thm "fficlose_call_pre_from_no_len" (mk_imp (list_mk_conj (weak_tm :: dropped), pl))
  (rewrite_tac [pre_def, weak_def] >> strip_tac >> asm_rewrite_tac []);
val PW2 = thm "fficlose_call_pre_no_len_weaker" (mk_imp (pl, weak_tm))
  (rewrite_tac [pre_def, weak_def] >> strip_tac >> asm_rewrite_tac []);
val [dmv, _, bv, cv, gv] = pargs;
val ms1 = ``ms1:arm8_state``;
val psub = [sv |-> ms1];
val path_concl = subst psub (snd (dest_imp (concl Mpath)));
val G = thm "cake_fficlose_path_at_reachable_call"
  ``^a2ant ==> ?ms. arm8_run 27 s = SOME ms /\ ms.PC = 0x1000040D0w /\
       !mc1 ffi1 ms1 ^dmv ^bv ^cv ^gv. machine_reach ^AMC ^bffi ms mc1 ffi1 ms1 /\ ^(subst psub weak_tm) ==> ^path_concl``
  (strip_tac >> mp_tac Fth >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >> qexists_tac `ms` >> asm_rewrite_tac [] >>
   rpt gen_tac >> strip_tac >>
   `ms1.PC = 0x100004080w` by (qpat_assum `fficlose_call_pre_no_len _ _ _ _ _` mp_tac >> rewrite_tac [weak_def] >> strip_tac) >>
   `ms1.REG 1w = 8w /\ ms1.REG 3w <> 0w` by (first_x_assum match_mp_tac >> metis_tac []) >>
   match_mp_tac (INST psub Mpath) >> match_mp_tac (INST psub PW) >> asm_rewrite_tac []);
(* ---- 5. Negative controls. ---- *)
val N1 = thm "ffi_close_rejects_invalid_lengths"
  ``(LENGTH (cfg8:word8 list) <> 8 \/ (arr:word8 list) = []) ==> ffi_close cfg8 arr fsys = NONE``
  (rw [ffi_close_def] >> fs [] >> show_tac "N1");
val N2 = thm "invalid_clen_call_halts_in_model"
  ``refund_static ^mc1 dm /\ ms1.PC = 0x100004080w /\ (ffi1:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\
    read_ffi_bytearrays mc1 ms1 = (SOME cbytes, SOME abytes) /\ LENGTH cbytes <> 8 ==>
    ?fo. targetSem$evaluate mc1 ffi1 1 ms1 = (Halt (FFI_outcome fo), ms1, ffi1)``
  (strip_tac >> Cases_on `call_FFI ffi1 (ExtCall «close») cbytes abytes`
   >- (drule_all C2 >> fs [])
   >- (rename1 `FFI_final fo` >> qexists_tac `fo` >> match_mp_tac C1a >> metis_tac []));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val closure = "forge_refundCallSite" :: Theory.ancestry "forge_refundCallSite";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
