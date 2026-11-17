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
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
