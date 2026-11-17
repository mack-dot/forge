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
  (rpt strip_tac >> fs [I2] >> first_x_assum (qspecl_then [`0`, `ARB`] strip_assume_tac) >>
   first_x_assum (qspec_then `a` mp_tac) >> simp [combinTheory.APPLY_UPDATE_THM] >> show_tac "N1");
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
val FC = thm "ffi_interfer_ok_iff_contract"
  ``ffi_interfer_ok ^B ^RMC <=> refund_ffi_contract (^envmc).prog_addresses (^envmc).ffi_interfer``
  (mp_tac (SPEC ``[ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»]`` FLD) >>
   (impl_tac >- simp [names4]) >> strip_tac >> strip_assume_tac flds2 >>
   `mmio_pcs_min_index [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»] = SOME 4` by
      (strip_assume_tac names_thm >> fs [names4] >> rveq >> fs []) >>
   asm_simp_tac (srw_ss()) [ffi_interfer_ok_def, contract_def, read_ffi_bytearrays_def, read_ffi_bytearray_def, arm8_target_def,
                            arm8_config_def, ffi_offset_def, LET_THM] >> show_tac "FC");
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
