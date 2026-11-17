(* U392: a concrete identity environment for next_interfer; the exact condition for interference_ok on the ARMv8 projection;
   the FFI contract that ffi_interfer_ok requires at refund_mc 0x1000040D0w envmc; an ABSTRACT FFI function that satisfies it.
   The identity environment and the abstract FFI function are models. Nothing here is a proof about the macOS scheduler,
   signals, or the real C functions in basis_ffi.c. Slide 0. *)
open preamble backendTheory targetSemTheory targetPropsTheory asmPropsTheory lab_to_targetTheory arm8Theory arm8_targetTheory alignmentTheory
     miscTheory set_sepTheory backendProofTheory arm8_configProofTheory forge_refundArm8CompileTheory forge_refundExclusionRealTheory
     forge_refundStartupClauseTheory forge_refundStartupBridgeTheory forge_refundInstalledDomainsTheory forge_refundInstalledAssemblyTheory
     forge_refundFfiFactsTheory forge_refundResidualTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (900, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundEnvModel";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
val mc_def = DB.fetch "forge_refundStartupBridge" "refund_mc_def";
val fix_def = DB.fetch "forge_refundStartupClause" "arm8_fix_def";
val names_thm = DB.fetch "forge_refundFfiFacts" "refund_ffi_names";
val all_ext = DB.fetch "forge_refundFfiFacts" "mmio_index_LENGTH_all_ExtCall";
val FLD = DB.fetch "forge_refundResidual" "refund_mc_concrete_fields";
val rest2_def = DB.fetch "forge_refundResidual" "refund_installed_rest2_def";
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val envmc = mk_var ("envmc", mcty);
val B = ``0x1000040D0w:word64``;
val RMC = ``refund_mc ^B ^envmc``;
(* ---- 1. next_interfer: identity environment; exact condition; a weaker non-identity environment. ---- *)
val id_def = new_definition ("refund_id_interfer_def", ``refund_id_interfer (i:num) (ms:arm8_state) = ms``);
val I1 = thm "refund_id_interfer_ok" ``!proj:arm8_state -> 'p. interference_ok refund_id_interfer proj``
  (simp [interference_ok_def, id_def]);
val f2s = prove (``fun2set (m:word64 -> word8, d) = fun2set (m', d) <=> !a. a IN d ==> m a = m' a``,
  simp [fun2set_def, EXTENSION, FORALL_PROD] >> metis_tac []);
val I2 = thm "interference_ok_arm8_iff"
  ``!env dm. interference_ok env (arm8_target.proj dm) <=>
      !i ms. (env i ms).PSTATE = ms.PSTATE /\ (env i ms).SCTLR_EL1 = ms.SCTLR_EL1 /\ (env i ms).TCR_EL1 = ms.TCR_EL1 /\
             (env i ms).exception = ms.exception /\ (env i ms).REG = ms.REG /\ (env i ms).PC = ms.PC /\
             !a. a IN dm ==> (env i ms).MEM a = ms.MEM a``
  (simp [interference_ok_def, arm8_target_def, arm8_proj_def, f2s] >> metis_tac []);
val out_def = new_definition ("refund_outside_interfer_def",
  ``refund_outside_interfer (dm:word64 set) (f:num -> arm8_state -> word64 -> word8) (i:num) (ms:arm8_state) =
      ms with MEM := (\a. if a IN dm then ms.MEM a else f i ms a)``);
val I3 = thm "refund_outside_interfer_ok" ``!dm f. interference_ok (refund_outside_interfer dm f) (arm8_target.proj dm)``
  (simp [I2, out_def]);
val I4 = thm "refund_outside_interfer_not_identity"
  ``!dm a i ms. a NOTIN dm ==> refund_outside_interfer dm (\i ms a. ms.MEM a + 1w) i ms <> ms``
  (rpt strip_tac >> pop_assum (mp_tac o Q.AP_TERM `\s. arm8_state_MEM s a`) >> simp [out_def]);
val N1 = thm "protected_write_breaks_interference"
  ``!dm a. a IN dm ==> ~interference_ok (\(i:num) ms. ms with MEM := (a =+ ms.MEM a + 1w) ms.MEM) (arm8_target.proj dm)``
  (rpt strip_tac >> fs [I2, combinTheory.APPLY_UPDATE_THM] >> first_x_assum (qspecl_then [`ARB`, `a`] mp_tac) >> simp [] >> show_tac "N1b");
val N2 = thm "pc_change_breaks_interference"
  ``!dm. ~interference_ok (\(i:num) ms. ms with PC := ms.PC + 4w) (arm8_target.proj dm)``
  (rpt strip_tac >> fs [I2] >> show_tac "N2");
(* ---- 2. The FFI contract at the record. ---- *)
val rd = ``\(dm:word64 set) (ms:arm8_state) p l. read_bytearray (ms.REG p) (w2n (ms.REG l)) (\a. if a IN dm then SOME (ms.MEM a) else NONE)``;
val contract_def = new_definition ("refund_ffi_contract_def",
  ``refund_ffi_contract (dm:word64 set) (ffi_i:num -> num # word8 list # arm8_state -> arm8_state) <=>
      !k index new_bytes ms2 (t1:64 asm_state) bytes bytes2.
        index < 4 /\ t1.mem_domain = dm /\
        read_bytearray (ms2.REG 0w) (w2n (ms2.REG 1w)) (\a. if a IN dm then SOME (ms2.MEM a) else NONE) = SOME bytes /\
        read_bytearray (ms2.REG 2w) (w2n (ms2.REG 3w)) (\a. if a IN dm then SOME (ms2.MEM a) else NONE) = SOME bytes2 /\
        LENGTH new_bytes = LENGTH bytes2 /\
        target_state_rel arm8_target (t1 with pc := 0x1000040D0w - n2w ((3 + index) * 16)) ms2 /\ aligned 2 (t1.regs 30) ==>
        arm8_ok (ffi_i k (index,new_bytes,ms2)) /\ (ffi_i k (index,new_bytes,ms2)).PC = t1.regs 30 /\
        (!a. a IN dm ==> (ffi_i k (index,new_bytes,ms2)).MEM a = asm_write_bytearray (t1.regs 2) new_bytes t1.mem a) /\
        (!r. MEM r [19;20;21;22;23;24;25;27;28] ==> (ffi_i k (index,new_bytes,ms2)).REG (n2w r) = t1.regs r)``);
val _ = pr ("DEFINITION " ^ thm_to_string contract_def);
val names4 = thm "refund_ffi_names_list"
  ``refund_lab_conf2.ffi_names = SOME [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»]``
  (strip_assume_tac names_thm >> `!j. j < LENGTH names ==> ?s. EL j names = ExtCall s` by (match_mp_tac all_ext >> asm_rewrite_tac []) >>
   fs [LENGTH_EQ_NUM_compute] >> rveq >>
   first_assum (qspec_then `0` mp_tac) >> first_assum (qspec_then `1` mp_tac) >> first_assum (qspec_then `2` mp_tac) >>
   first_x_assum (qspec_then `3` mp_tac) >> simp [] >> rpt strip_tac >> gvs [ffinames_to_string_list_def] >> show_tac "NAMES4");
val flds2 = thm "refund_mc_register_fields"
  ``(^RMC).ffi_interfer = (^envmc).ffi_interfer /\ (^RMC).next_interfer = (^envmc).next_interfer /\ (^RMC).ptr_reg = 0 /\ (^RMC).len_reg = 1 /\
    (^RMC).ptr2_reg = 2 /\ (^RMC).len2_reg = 3 /\ (^RMC).callee_saved_regs = [19;20;21;22;23;24;25;26;27;28]``
  (simp [mc_def, fix_def]);
val tg = prove (``arm8_target.get_pc (ms:arm8_state) = ms.PC /\ arm8_target.get_byte ms = ms.MEM /\ arm8_target.get_reg ms r = ms.REG (n2w r) /\
                  arm8_target.state_ok = arm8_ok /\ arm8_target.config.code_alignment = 2 /\ arm8_target.config.link_reg = SOME 30 /\
                  arm8_target.config.reg_count = 32 /\ arm8_target.config.avoid_regs = [18; 26; 31]``,
  simp [arm8_target_def, arm8_config_def, FUN_EQ_THM]);
val elx = prove (``index < 4 ==> ([ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»]❲index❳ = ExtCall «» <=> F)``,
  strip_tac >> `index = 0 \/ index = 1 \/ index = 2 \/ index = 3` by decide_tac >> simp []);
val idx = prove (``index < 4 ==> (4 <= index <=> F)``, decide_tac);
val rl = prove (``(r = 19 \/ r = 20 \/ r = 21 \/ r = 22 \/ r = 23 \/ r = 24 \/ r = 25 \/ r = 26 \/ r = 27 \/ r = 28) /\ r < 32 /\ r <> 18 /\ r <> 26 /\ r <> 31 <=>
                 MEM r [19;20;21;22;23;24;25;27;28:num]``, simp [] >> decide_tac);
val fld1 = MP (SPEC ``[ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»]`` FLD)
              (prove (``refund_lab_conf2.ffi_names = SOME [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»] /\
                        LENGTH [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»] = 4``, simp [names4]));
val mm4 = prove (``mmio_pcs_min_index [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»] = SOME 4``,
  strip_assume_tac names_thm >> fs [names4] >> rveq >> fs []);
val S = [ffi_interfer_ok_def, read_ffi_bytearrays_def, read_ffi_bytearray_def, ffi_offset_def, LET_THM, tg, fld1, flds2, mm4, elx, idx];
val lhs_n = SIMP_CONV (srw_ss()) S ``ffi_interfer_ok ^B ^RMC``;
val _ = pr ("LHS_N " ^ thm_to_string lhs_n);
val rhs_n = SIMP_CONV (srw_ss()) (contract_def :: S) ``refund_ffi_contract (^envmc).prog_addresses (^envmc).ffi_interfer``;
val _ = pr ("RHS_N " ^ thm_to_string rhs_n);
val long = find_term (fn t => is_conj t andalso is_disj (fst (dest_conj t)) andalso can (find_term (aconv ``r < 32n``)) t) (rhs (concl lhs_n));
val short = find_term (fn t => is_disj t andalso length (strip_disj t) = 9 andalso aconv (hd (strip_disj t)) ``r = 19n``) (rhs (concl rhs_n));
val rl' = prove (mk_eq (long, short), decide_tac);
val lhs_n' = CONV_RULE (RAND_CONV (PURE_REWRITE_CONV [rl'])) lhs_n;
val mid = Tactical.TAC_PROOF (([], mk_eq (rhs (concl lhs_n'), rhs (concl rhs_n))),
  eq_tac >> rpt gen_tac
  >- (disch_then (fn all => rpt gen_tac >> strip_tac >>
        mp_tac (Q.SPECL [`ms2`, `k`, `index`, `new_bytes`, `t1`, `bytes`, `bytes2`] all)) >> asm_rewrite_tac [] >> show_tac "MID1")
  >- (disch_then (fn all => rpt gen_tac >> strip_tac >> strip_tac >>
        mp_tac (Q.SPECL [`k`, `index`, `new_bytes`, `ms2`, `t1`, `bytes`, `bytes2`] all)) >> asm_rewrite_tac [] >> show_tac "MID2"))
  handle e => (pr ("LEMMA_FAILED mid " ^ General.exnMessage e); failed := "mid" :: !failed; TRUTH);
val FC = save_thm ("ffi_interfer_ok_iff_contract", TRANS lhs_n' (TRANS mid (SYM rhs_n)))
  handle e => (pr "LEMMA_FAILED ffi_interfer_ok_iff_contract"; failed := "ffi_interfer_ok_iff_contract" :: !failed; TRUTH);
val _ = if aconv (concl FC) T then () else chk "ffi_interfer_ok_iff_contract" FC;
(* ---- 3. An ABSTRACT FFI function that satisfies the contract. It is a model, not the C code. ---- *)
val abs_def = new_definition ("refund_abs_ffi_def",
  ``refund_abs_ffi (k:num) (x:num # word8 list # arm8_state) =
      (SND (SND x)) with <| PC := (SND (SND x)).REG 30w; MEM := asm_write_bytearray ((SND (SND x)).REG 2w) (FST (SND x)) (SND (SND x)).MEM |>``);
val AWB = thm "asm_write_bytearray_agree_on_domain"
  ``!bs c (m:word64 -> word8) m' dm. (!a. a IN dm ==> m a = m' a) ==>
       !a. a IN dm ==> asm_write_bytearray c bs m a = asm_write_bytearray c bs m' a``
  (Induct >> rw [asm_write_bytearray_def, combinTheory.APPLY_UPDATE_THM] >> metis_tac []);
val tsr_facts = thm "arm8_target_state_rel_facts"
  ``target_state_rel arm8_target (t:64 asm_state) ms ==>
      arm8_ok ms /\ ms.PC = t.pc /\ (!a. a IN t.mem_domain ==> ms.MEM a = t.mem a) /\
      (!i. i < 32 /\ i <> 18 /\ i <> 26 /\ i <> 31 ==> ms.REG (n2w i) = t.regs i)``
  (simp [target_state_rel_def, tg] >> simp [arm8_target_def, arm8_config_def]);
val AB = thm "refund_abs_ffi_contract" ``!dm. refund_ffi_contract dm refund_abs_ffi``
  (rewrite_tac [contract_def] >> rpt gen_tac >> strip_tac >> first_assum (strip_assume_tac o MATCH_MP tsr_facts) >>
   `ms2.REG 30w = t1.regs 30 /\ ms2.REG 2w = t1.regs 2` by
      (first_assum (qspec_then `30` mp_tac) >> first_x_assum (qspec_then `2` mp_tac) >> simp []) >>
   fs [abs_def, arm8_ok_def] >> rpt strip_tac
   >- (show_tac "AB1" >> metis_tac [AWB])
   >> show_tac "AB2" >> first_x_assum match_mp_tac >> simp []);
val env_def = new_definition ("refund_abs_env_def",
  ``refund_abs_env ^envmc = ^envmc with <| next_interfer := refund_id_interfer; ffi_interfer := refund_abs_ffi |>``);
val AMC = ``refund_mc ^B (refund_abs_env ^envmc)``;
val ms = ``ms:arm8_state``;
val ENV = thm "refund_abs_env_rest2" ``!ms. ms.PC = ^B ==> refund_installed_rest2 ^AMC ms``
  (rpt strip_tac >> asm_rewrite_tac [rest2_def, INST [envmc |-> ``refund_abs_env ^envmc``] FC] >>
   strip_assume_tac (INST [envmc |-> ``refund_abs_env ^envmc``] flds2) >>
   asm_simp_tac (srw_ss()) [env_def, I1, AB] >> show_tac "ENV");
val env_prog = prove (``(refund_abs_env ^envmc).prog_addresses = (^envmc).prog_addresses``, simp [env_def]);
fun lift src new =
  let val th = INST [envmc |-> ``refund_abs_env ^envmc``] (DB.fetch "forge_refundResidual" src) |> REWRITE_RULE [env_prog]
      val (ant, c) = dest_imp (concl th)
      val (msv, body) = dest_exists c
      val [c1, c2, c3] = strip_conj body
      val goal = mk_imp (ant, mk_exists (msv, list_mk_conj [c1, c2, snd (dest_imp c3)]))
  in thm new goal (strip_tac >> mp_tac th >> (impl_tac >- asm_rewrite_tac []) >> disch_then (qx_choose_then `ms` strip_assume_tac) >>
                   qexists_tac `ms` >> asm_rewrite_tac [] >> first_x_assum match_mp_tac >> match_mp_tac ENV >> first_assum ACCEPT_TAC) end;
val A1 = lift "refund_installed_from_entry_reduced" "refund_installed_abstract_env";
val A2 = lift "refund_behavior_from_entry_reduced" "refund_behavior_abstract_env";
val A3 = lift "refund_u298_exclusion_from_entry_reduced" "refund_u298_exclusion_abstract_env";
(* ---- 4. Negative controls for the contract and for ffi_interfer_ok itself. ---- *)
val msw_def = new_definition ("refund_ffi_witness_state_def",
  ``refund_ffi_witness_state = (ARB:arm8_state) with <| PC := 0x1000040A0w; PSTATE := (ARB with EL := 0w); exception := NoException;
        SCTLR_EL1 := (ARB with <| E0E := F; SA0 := F |>); TCR_EL1 := (ARB with <| TBI0 := F; TBI1 := F |>); REG := (\r. 0w) |>``);
val W = ``refund_ffi_witness_state``;
val WIT = thm "refund_ffi_contract_at_witness"
  ``!dm ffi_i k. refund_ffi_contract dm ffi_i ==>
      (ffi_i k (0,[],^W)).PC = 0w /\ (!a. a IN dm ==> (ffi_i k (0,[],^W)).MEM a = (^W).MEM a) /\ (ffi_i k (0,[],^W)).REG 19w = 0w``
  (rewrite_tac [contract_def] >> rpt gen_tac >>
   disch_then (qspecl_then [`k`, `0`, `[]`, `^W`,
      `<| regs := (\i. 0w); fp_regs := (\i. 0w); mem := (^W).MEM; mem_domain := dm; pc := ARB; lr := 30; align := 2; be := F; failed := F |>`,
      `[]`, `[]`] mp_tac) >>
   impl_tac
   >- (simp [msw_def, read_bytearray_def, target_state_rel_def, tg, arm8_ok_def] >> simp [arm8_target_def, arm8_config_def] >> EVAL_TAC >> show_tac "WIT1")
   >- (simp [asm_write_bytearray_def] >> strip_tac >> asm_rewrite_tac [] >> first_x_assum (qspec_then `19` mp_tac) >> simp [] >> show_tac "WIT2"));
val bad_ret_def = new_definition ("refund_bad_return_ffi_def",
  ``refund_bad_return_ffi (k:num) (x:num # word8 list # arm8_state) = (refund_abs_ffi k x) with PC := (SND (SND x)).REG 30w + 4w``);
val bad_mem_def = new_definition ("refund_bad_memory_ffi_def",
  ``refund_bad_memory_ffi (a:word64) (k:num) (x:num # word8 list # arm8_state) =
      (refund_abs_ffi k x) with MEM := (a =+ (refund_abs_ffi k x).MEM a + 1w) (refund_abs_ffi k x).MEM``);
val bad_reg_def = new_definition ("refund_bad_register_ffi_def",
  ``refund_bad_register_ffi (k:num) (x:num # word8 list # arm8_state) = (refund_abs_ffi k x) with REG := (19w =+ 1w) (refund_abs_ffi k x).REG``);
fun at_bad f = ``ffi_interfer_ok ^B (refund_mc ^B (^envmc with ffi_interfer := ^f))``;
fun fc_at f = let val e = ``^envmc with ffi_interfer := ^f`` in
   CONV_RULE (RAND_CONV (SIMP_CONV (srw_ss()) [])) (INST [envmc |-> e] FC) end;
val NF1 = thm "wrong_return_address_ffi_rejected" ``~^(at_bad ``refund_bad_return_ffi``)``
  (rewrite_tac [fc_at ``refund_bad_return_ffi``] >> strip_tac >> drule WIT >> disch_then (qspec_then `0` mp_tac) >>
   simp [bad_ret_def, abs_def, msw_def] >> show_tac "NF1");
val NF2 = thm "protected_memory_write_ffi_rejected"
  ``!a. a IN (^envmc).prog_addresses ==> ~^(at_bad ``refund_bad_memory_ffi a``)``
  (gen_tac >> strip_tac >> rewrite_tac [fc_at ``refund_bad_memory_ffi a``] >> strip_tac >> drule WIT >>
   disch_then (qspec_then `0` strip_assume_tac) >> first_x_assum (qspec_then `a` mp_tac) >>
   asm_simp_tac (srw_ss()) [bad_mem_def, abs_def, asm_write_bytearray_def, combinTheory.APPLY_UPDATE_THM] >> show_tac "NF2");
val NF3 = thm "clobbered_callee_saved_register_ffi_rejected" ``~^(at_bad ``refund_bad_register_ffi``)``
  (rewrite_tac [fc_at ``refund_bad_register_ffi``] >> strip_tac >> drule WIT >> disch_then (qspec_then `0` mp_tac) >>
   simp [bad_reg_def, abs_def, combinTheory.APPLY_UPDATE_THM] >> show_tac "NF3");
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val closure = "forge_refundEnvModel" :: Theory.ancestry "forge_refundEnvModel";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
