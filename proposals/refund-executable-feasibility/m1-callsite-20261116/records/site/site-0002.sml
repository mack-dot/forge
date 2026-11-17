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
  (strip_tac >> simp [step_def, seq_def] >> gen_tac >> simp [Once evaluate_def, apply_oracle_def] >> fs [] >> show_tac "S1");
val FR = thm "call_FFI_return_keeps_oracle"
  ``call_FFI (st:'ffi ffi_state) nm cbytes abytes = FFI_return st' nb ==> st'.oracle = st.oracle``
  (rw [call_FFI_def] >> gvs [AllCaseEqs()]);
val S2 = thm "extcall_step_is_machine_step"
  ``mc.target.get_pc ms NOTIN (mc.prog_addresses DIFF set mc.ffi_entry_pcs) /\ mc.target.get_pc ms <> mc.halt_pc /\
    mc.target.get_pc ms <> mc.install_pc /\ find_index (mc.target.get_pc ms) mc.ffi_entry_pcs 0 = SOME i /\
    EL i mc.ffi_names = ExtCall nm /\ ALOOKUP mc.mmio_info i = NONE /\ read_ffi_bytearrays mc ms = (SOME cbytes, SOME abytes) /\
    call_FFI (ffi:'ffi ffi_state) (ExtCall nm) cbytes abytes = FFI_return new_ffi nb ==>
    machine_step ^mc ffi ms (mc with ffi_interfer := shift_seq 1 mc.ffi_interfer) new_ffi (mc.ffi_interfer 0 (i, nb, ms))``
  (strip_tac >> imp_res_tac FR >> simp [step_def, seq_def] >> gen_tac >> simp [Once evaluate_def, apply_oracle_def] >> show_tac "S2");
val R0 = thm "machine_reach_refl" ``machine_reach ^mc (ffi:'ffi ffi_state) ms mc ffi ms``
  (simp [reach_def] >> qexists_tac `0` >> simp [reachn_def]);
(* ---- 2. A close call state of a record with the static facts. ---- *)
val tg = prove (``arm8_target.get_pc (ms:arm8_state) = ms.PC /\ arm8_target.get_byte ms = ms.MEM /\ arm8_target.get_reg ms r = ms.REG (n2w r)``,
  simp [arm8_target_def, FUN_EQ_THM]);
val C1a = thm "close_call_final_halts"
  ``refund_static ^mc1 dm /\ ms1.PC = 0x100004080w /\ read_ffi_bytearrays mc1 ms1 = (SOME cbytes, SOME abytes) /\
    call_FFI (ffi1:'ffi ffi_state) (ExtCall «close») cbytes abytes = FFI_final outcome ==>
    targetSem$evaluate mc1 ffi1 1 ms1 = (Halt (FFI_outcome outcome), ms1, ffi1)``
  (rw [static_def] >> simp [Once evaluate_def, tg, find_index_def] >> show_tac "C1a");
val C1b = thm "close_call_unreadable_errors"
  ``refund_static ^mc1 dm /\ ms1.PC = 0x100004080w /\ ~(?cbytes abytes. read_ffi_bytearrays mc1 ms1 = (SOME cbytes, SOME abytes)) ==>
    FST (targetSem$evaluate mc1 (ffi1:'ffi ffi_state) 1 ms1) = Error``
  (rw [static_def] >> simp [Once evaluate_def, tg, find_index_def] >>
   Cases_on `read_ffi_bytearrays mc1 ms1` >> rename1 `(q1, q2)` >> Cases_on `q1` >> Cases_on `q2` >> fs [] >> show_tac "C1b");
val O1 = DB.fetch "forge_refundFficloseCompose" "ffi_close_accepts_only_valid_lengths";
val C2 = thm "close_call_return_lengths"
  ``ffi1.oracle = basis_ffi_oracle ext /\ call_FFI ffi1 (ExtCall «close») cbytes abytes = FFI_return new_ffi nb ==>
    LENGTH cbytes = 8 /\ 1 <= LENGTH abytes``
  (strip_tac >> pop_assum mp_tac >> simp [call_FFI_def, basis_ffi_oracle_def] >>
   Cases_on `ffi1.ffi_state` >> simp [] >> rpt (CASE_TAC >> simp []) >> rpt strip_tac >> imp_res_tac O1 >> fs [] >> show_tac "C2");
val C3 = thm "close_call_read_lengths"
  ``refund_static ^mc1 dm /\ read_ffi_bytearrays mc1 ms1 = (SOME cbytes, SOME abytes) ==>
    LENGTH cbytes = w2n (ms1.REG 1w) /\ LENGTH abytes = w2n (ms1.REG 3w)``
  (rw [static_def, read_ffi_bytearrays_def, read_ffi_bytearray_def] >> fs [tg] >> imp_res_tac read_bytearray_LENGTH >> fs []);
val E1 = thm "fail_not_in_success_limit" ``Fail NOTIN extend_with_resource_limit {Terminate Success io}``
  (simp [extend_with_resource_limit_def]);
val E2 = thm "ffi_outcome_not_in_success_limit" ``Terminate (FFI_outcome fo) l NOTIN extend_with_resource_limit {Terminate Success io}``
  (simp [extend_with_resource_limit_def]);
val E3 = thm "resource_limit_is_in_success_limit" ``Terminate Resource_limit_hit [] IN extend_with_resource_limit {Terminate Success io}``
  (simp [extend_with_resource_limit_def]);
(* ---- 3. Main theorem: argument validity at every reachable close call state. ---- *)
val D = thm "close_call_site_arguments"
  ``machine_reach ^mc (ffi:'ffi ffi_state) ms ^mc1 ffi1 ms1 /\ refund_static mc dm /\ ffi.oracle = basis_ffi_oracle ext /\
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
   >- (rename1 `FFI_return new_ffi nb` >> drule_all C2 >> strip_tac >> drule_all C3 >> strip_tac >>
       `w2n (ms1.REG 1w) = 8 /\ w2n (ms1.REG 3w) <> 0` by decide_tac >>
       rpt conj_tac
       >- (pop_assum kall_tac >> pop_assum (mp_tac o Q.AP_TERM `n2w:num -> word64`) >> simp [])
       >- (strip_tac >> fs [])
       >- (metis_tac []))
   >- (rename1 `FFI_final fo` >>
       `targetSem$evaluate mc1 ffi1 1 ms1 = (Halt (FFI_outcome fo), ms1, ffi1)` by (match_mp_tac C1a >> metis_tac []) >>
       `machine_sem mc ffi ms (Terminate (FFI_outcome fo) ffi1.io_events)` by
          (simp [machine_sem_def] >> qexistsl_tac [`1 + n`, `ms1`, `ffi1`] >> metis_tac []) >>
       fs [SUBSET_DEF, IN_DEF] >> res_tac >> metis_tac [E2, IN_DEF]));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
