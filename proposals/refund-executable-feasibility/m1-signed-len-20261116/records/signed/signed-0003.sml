(* U396: signed alen at reachable close call states of the MODEL machine.
   The bound w2n x3 < 2^63 is NOT derivable from the earlier premises (a heap of 2^63 bytes or more is admitted).
   It is proved from one NEW explicit premise: every program address is below 2^63 (for the model record: e <=+ 2^63).
   Only the name close. No claim about the real process, libSystem, the loader or the slide. *)
open preamble targetSemTheory asmPropsTheory lab_to_targetTheory arm8Theory arm8_targetTheory alignmentTheory miscTheory ffiTheory
     semanticsPropsTheory basis_ffiTheory forge_refundStartupBridgeTheory forge_refundInstalledDomainsTheory forge_refundEnvModelTheory
     forge_refundFficloseStepTheory forge_refundFficloseComposeTheory forge_refundCallSiteTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2000, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundSignedLen";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val mc = mk_var ("mc", mcty); val mc1 = mk_var ("mc1", mcty); val envmc = mk_var ("envmc", mcty);
val bty = type_of ``basis_ffi ext cl fs``;
fun CS n = DB.fetch "forge_refundCallSite" n;
val [static_def, D, Fth, weak_def, ST] = map CS ["refund_static_def", "close_call_site_arguments", "close_call_site_arguments_model",
       "fficlose_call_pre_no_len_def", "refund_abs_record_static"];
val clear_def = DB.fetch "forge_refundInstalledDomains" "refund_heap_clear_def";
val mem_dm_def = DB.fetch "forge_refundInstalledDomains" "refund_mem_dm_def";
val code_dm_def = DB.fetch "forge_refundInstalledDomains" "refund_code_dm_def";
val C1r = DB.fetch "forge_refundInstalledDomains" "refund_bitmaps_dm_range";
val HALF = ``0x8000000000000000w:word64``;
(* ---- 1. The earlier premises do not bound the domain. ---- *)
val huge = thm "heap_premises_admit_huge_heap"
  ``?h e:word64. aligned 3 h /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear h e /\ ^HALF <=+ e - h``
  (map_every qexists_tac [`0x200000000w`, `0xFFFFFFFFFFFFFFF8w`] >> rewrite_tac [clear_def] >> rpt conj_tac >>
   TRY (EVAL_TAC >> NO_TAC) >> blastLib.BBLAST_TAC);
(* ---- 2. Low-half premise gives the bound. ---- *)
val low_def = new_definition ("addresses_below_half_def", ``addresses_below_half (dm:word64 set) <=> !a. a IN dm ==> a <+ ^HALF``);
val z1 = prove (``!x:word64. x <+ ^HALF /\ x + 0x7FFFFFFFFFFFFFFFw <+ ^HALF ==> x = 0w``, blastLib.BBLAST_TAC);
val RB = thm "read_bytearray_below_half_bound"
  ``!x n (m:word64 -> word8) dm bs q. read_bytearray x n (\a. if a IN dm then SOME (m a) else NONE) = SOME bs /\
      addresses_below_half dm /\ q NOTIN dm /\ q <+ ^HALF ==> n < 2 ** 63``
  (rpt strip_tac >> CCONTR_TAC >> imp_res_tac read_bytearray_IMP_mem_SOME >> fs [IN_all_words, PULL_EXISTS, low_def] >>
   `!i. i < n ==> x + n2w i IN dm` by (rpt strip_tac >> first_x_assum drule >> rw []) >>
   `x IN dm /\ x + 0x7FFFFFFFFFFFFFFFw IN dm` by
      (first_assum (qspec_then `0` mp_tac) >> first_x_assum (qspec_then `9223372036854775807` mp_tac) >> simp []) >>
   `x = 0w` by (match_mp_tac z1 >> metis_tac []) >>
   `w2n q < n` by (Cases_on `q` >> fs [word_lo_n2w]) >>
   `0w + n2w (w2n q) IN dm` by metis_tac [] >> fs [] >> show_tac "RB");
val msb63 = prove (``!w:word64. word_msb w <=> 2 ** 63 <= w2n w``, Cases >> simp [word_msb_n2w_numeric] >> EVAL_TAC >> simp []);
val pos = prove (``!w:word64. w <> 0w /\ ~word_msb w ==> 0w < w``, blastLib.BBLAST_TAC);
val tg = prove (``arm8_target.get_pc (ms:arm8_state) = ms.PC /\ arm8_target.get_byte ms = ms.MEM /\ arm8_target.get_reg ms r = ms.REG (n2w r)``,
  simp [arm8_target_def, FUN_EQ_THM]);
val static_seq = prove (``refund_static ^mc dm /\ mc_static_eq mc ^mc1 ==> refund_static mc1 dm``,
  simp [static_def, DB.fetch "forge_refundCallSite" "mc_static_eq_def"]);
val R1 = CS "machine_reach_n_evaluate"; val reach_def = CS "machine_reach_def";
val lt_stub = EVAL ``0x100004080w <+ 0x8000000000000000w:word64``;
val LB = thm "close_call_alen_below_half"
  ``refund_static ^mc1 dm /\ read_ffi_bytearrays mc1 ms1 = (SOME cbytes, SOME abytes) /\ addresses_below_half dm ==>
    w2n (ms1.REG 3w) < 2 ** 63``
  (rw [static_def, read_ffi_bytearrays_def, read_ffi_bytearray_def] >> fs [tg] >> show_tac "LB" >>
   qpat_x_assum `read_bytearray (ms1.REG 2w) _ _ = SOME abytes` (fn rb =>
     qpat_x_assum `addresses_below_half _` (fn low =>
       qpat_x_assum `_ NOTIN _` (fn notin => ACCEPT_TAC (MATCH_MP RB (LIST_CONJ [rb, low, notin, EQT_ELIM lt_stub]))))));
val Sgn = thm "close_call_site_signed_alen"
  ``machine_reach ^mc (ffi:^(ty_antiq bty)) ms ^mc1 ffi1 ms1 /\ refund_static mc dm /\ ffi.oracle = basis_ffi_oracle ext /\
    machine_sem mc ffi ms SUBSET extend_with_resource_limit {Terminate Success io} /\ ms1.PC = 0x100004080w /\
    addresses_below_half dm ==>
    ms1.REG 1w = 8w /\ ms1.REG 3w <> 0w /\ ~word_msb (ms1.REG 3w) /\ 0w < ms1.REG 3w``
  (strip_tac >> mp_tac D >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
   `refund_static mc1 dm` by (fs [reach_def] >> drule R1 >> strip_tac >> metis_tac [static_seq]) >>
   `w2n (ms1.REG 3w) < 2 ** 63` by (match_mp_tac LB >> metis_tac []) >>
   `~word_msb (ms1.REG 3w)` by (rewrite_tac [msb63] >> decide_tac) >>
   asm_rewrite_tac [] >> match_mp_tac pos >> asm_rewrite_tac []);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
