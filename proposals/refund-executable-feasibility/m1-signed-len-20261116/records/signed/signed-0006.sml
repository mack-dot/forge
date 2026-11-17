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
   `0w + n2w (w2n q) IN dm` by metis_tac [] >> fs []);
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
  (rw [static_def, read_ffi_bytearrays_def, read_ffi_bytearray_def] >> rfs [tg] >> fs [tg] >>
   qpat_x_assum `read_bytearray _ _ _ = SOME abytes` (fn rb =>
     qpat_x_assum `addresses_below_half _` (fn low =>
       qpat_x_assum `_ NOTIN _` (fn notin => assume_tac (MATCH_MP RB (LIST_CONJ [rb, low, notin, EQT_ELIM lt_stub]))))) >> fs []);
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
(* ---- 3. The model record: the new premise is e <=+ 2^63. ---- *)
val h1 = prove (``a <+ 0x100024000w ==> a <+ ^HALF``, blastLib.BBLAST_TAC);
val h2 = prove (``a <+ 0x100030F30w ==> a <+ ^HALF``, blastLib.BBLAST_TAC);
val h3 = prove (``a <+ (e:word64) /\ e <=+ ^HALF ==> a <+ ^HALF``, blastLib.BBLAST_TAC);
val LH = thm "refund_mem_dm_below_half" ``!h e. e <=+ ^HALF ==> addresses_below_half (refund_mem_dm h e)``
  (rewrite_tac [low_def, mem_dm_def, code_dm_def] >> rpt strip_tac >> fs [IN_UNION, GSPECIFICATION]
   >- (imp_res_tac h1) >- (imp_res_tac h3) >- (imp_res_tac C1r >> imp_res_tac h2));
val AMC = ``refund_mc 0x1000040D0w (refund_abs_env ^envmc)``;
val bffi = ``basis_ffi ext cl fs``;
val A2 = DB.fetch "forge_refundEnvModel" "refund_behavior_abstract_env";
val (a2ant, _) = dest_imp (concl A2);
val fvS = fn n => valOf (List.find (fn v => fst (dest_var v) = n) (free_vars (concl Sgn)));
val S_i = INST [fvS "mc" |-> AMC, fvS "ffi" |-> bffi, fvS "dm" |-> ``refund_mem_dm h e``, fvS "io" |-> mk_var ("io_events", type_of (fvS "io")),
                fvS "ms" |-> ``ms:arm8_state``] Sgn;
val SM = thm "close_call_site_signed_alen_model"
  ``^a2ant /\ e <=+ ^HALF ==> ?ms. arm8_run 27 s = SOME ms /\ ms.PC = 0x1000040D0w /\
       !mc1 ffi1 ms1. machine_reach ^AMC ^bffi ms mc1 ffi1 ms1 /\ ms1.PC = 0x100004080w ==>
                      ms1.REG 1w = 8w /\ ms1.REG 3w <> 0w /\ ~word_msb (ms1.REG 3w) /\ 0w < ms1.REG 3w``
  (strip_tac >> mp_tac A2 >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >> qexists_tac `ms` >> asm_rewrite_tac [] >>
   rpt gen_tac >> strip_tac >> mp_tac S_i >>
   (impl_tac >- (asm_rewrite_tac [] >> rpt conj_tac
                 >- (match_mp_tac ST >> asm_rewrite_tac [])
                 >- (simp [basis_ffi_def])
                 >- (match_mp_tac LH >> first_assum ACCEPT_TAC))) >>
   strip_tac >> asm_rewrite_tac []);
(* ---- 4. Composition with the path theorem. ---- *)
val pre_def = DB.fetch "forge_refundFficloseCompose" "fficlose_call_pre_def";
val Mpath = DB.fetch "forge_refundFficloseCompose" "cake_fficlose_path";
val PW = CS "fficlose_call_pre_from_no_len";
val (wl, wr) = dest_eq (snd (strip_forall (concl weak_def)));
val wargs = snd (strip_comb wl);
val sv = List.nth (wargs, 1);
val sign_tm = ``~word_msb ((^sv).REG 3w)``;
val kept13 = List.filter (fn cj => not (aconv cj sign_tm)) (strip_conj wr);
val _ = if length kept13 = 13 andalso length (strip_conj wr) = 14 then pr "PREMISES_KEPT 13 DROPPED 1 (sign condition)" else raise Fail "premise split";
val w13_c = mk_var ("fficlose_call_pre_no_len_sign", list_mk_fun (map type_of wargs, bool));
val w13_def = new_definition ("fficlose_call_pre_no_len_sign_def", mk_eq (list_mk_comb (w13_c, wargs), list_mk_conj kept13));
val _ = pr ("DEFINITION " ^ thm_to_string w13_def);
val w13_tm = lhs (snd (strip_forall (concl w13_def)));
val PW3 = thm "fficlose_call_pre_no_len_from_no_sign" (mk_imp (mk_conj (w13_tm, sign_tm), wl))
  (rewrite_tac [weak_def, w13_def] >> strip_tac >> asm_rewrite_tac []);
val ms1 = ``ms1:arm8_state``;
val psub = [sv |-> ms1];
val [dmv, _, bv, cv, gv] = wargs;
val path_concl = subst psub (snd (dest_imp (concl Mpath)));
val G2 = thm "cake_fficlose_path_at_reachable_call_signed"
  ``^a2ant /\ e <=+ ^HALF ==> ?ms. arm8_run 27 s = SOME ms /\ ms.PC = 0x1000040D0w /\
       !mc1 ffi1 ms1 ^dmv ^bv ^cv ^gv. machine_reach ^AMC ^bffi ms mc1 ffi1 ms1 /\ ^(subst psub w13_tm) ==> ^path_concl``
  (strip_tac >> mp_tac SM >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >> qexists_tac `ms` >> asm_rewrite_tac [] >>
   rpt gen_tac >> strip_tac >>
   `ms1.PC = 0x100004080w` by (qpat_assum `fficlose_call_pre_no_len_sign _ _ _ _ _` mp_tac >> rewrite_tac [w13_def] >> strip_tac) >>
   `ms1.REG 1w = 8w /\ ms1.REG 3w <> 0w /\ ~word_msb (ms1.REG 3w) /\ 0w < ms1.REG 3w` by (first_x_assum match_mp_tac >> metis_tac []) >>
   match_mp_tac (INST psub Mpath) >> match_mp_tac (INST psub PW) >> asm_rewrite_tac [] >>
   match_mp_tac (INST psub PW3) >> asm_rewrite_tac []);
(* ---- 5. Negative controls. ---- *)
val c1 = thm "negative_alen_not_covered" ``word_msb ((^sv).REG 3w) ==> ~^wl``
  (rewrite_tac [weak_def] >> rpt strip_tac);
val c2 = thm "arbitrary_state_can_violate_arguments"
  ``?ms1:arm8_state. ms1.PC = 0x100004080w /\ ms1.REG 1w <> 8w /\ word_msb (ms1.REG 3w)``
  (qexists_tac `(ARB:arm8_state) with <| PC := 0x100004080w; REG := (\r. 0xFFFFFFFFFFFFFFFFw) |>` >> simp [] >> EVAL_TAC);
val c3 = thm "universe_not_below_half" ``~addresses_below_half (UNIV:word64 set)``
  (simp [low_def] >> qexists_tac `^HALF` >> EVAL_TAC);
val c4 = thm "high_heap_end_not_below_half" ``!h e. h <=+ ^HALF /\ ^HALF <+ e ==> ~addresses_below_half (refund_mem_dm h e)``
  (rpt strip_tac >> fs [low_def, mem_dm_def] >> first_x_assum (qspec_then `^HALF` mp_tac) >> simp [] >> EVAL_TAC >> show_tac "c4");
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val closure = "forge_refundSignedLen" :: Theory.ancestry "forge_refundSignedLen";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
