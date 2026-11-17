(* U401: (1) the numeric buffer bound of U400 is equivalent to the word-level bound conjunct of ffiwrite_call_pre (no overflow:
   the sum is below 2^18; unsigned comparison; the sign of x3 is a SEPARATE conjunct and is NOT derived);
   (2) ffiwrite_call_pre at the canonical parameters is equivalent to: PC, x1 = 8, the numeric bound, and an explicit
   residual of 12 conjuncts; (3) oracle-level facts about failed and successful write calls.
   NOT proved: a source-level event invariant; a terminating refund run; anything about the real process. *)
open preamble wordsLib blastLib targetSemTheory ffiTheory semanticsPropsTheory fsFFITheory fsFFIPropsTheory basis_ffiTheory TextIOProofTheory
     mlstringTheory MarshallingTheory llistTheory arm8Theory arm8_targetTheory forge_refundSourceNonFailTheory forge_refundCallSiteTheory
     forge_refundFfiwritePathTheory forge_refundFfiwriteSiteTheory forge_refundFfiwriteSuccessTheory forge_refundWriteReachTheory forge_refundWriteArgsTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundWriteWord";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
(* mk_thm is used ONLY to let later lemmas be explored after a failure; the run raises Fail before export if any lemma failed,
   and every stored theorem is tag-checked. *)
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; mk_thm ([], goal));
fun WA n = DB.fetch "forge_refundWriteArgs" n;
val pre_def = DB.fetch "forge_refundFfiwritePath" "ffiwrite_call_pre_def";
val wok_def = WA "write_ok_event_def"; val wev_def = DB.fetch "forge_refundWriteReach" "write_event_def";
val bty = type_of ``basis_ffi ext cl fs``;
(* ---- 1. The bound conjunct, taken from the definition (not retyped). ---- *)
val (pre_l, pre_r) = dest_eq (snd (strip_forall (concl pre_def)));
val [dmv, sv, bv, cv, av, gv] = snd (strip_comb pre_l);
val conjs = strip_conj pre_r;
val _ = pr ("PRE_CONJUNCTS " ^ Int.toString (length conjs));
val reg3 = ``(^sv).REG 3w``;
val bound = valOf (List.find (fn cj => (let val (l, r) = wordsSyntax.dest_word_ls cj in aconv r reg3 end) handle _ => false) conjs);
val (L, _) = wordsSyntax.dest_word_ls bound;
val bytes = [(``(^sv).MEM ^av``, ``m0:word8``), (``(^sv).MEM (^av + 1w)``, ``m1:word8``), (``(^sv).MEM (^av + 2w)``, ``m2:word8``), (``(^sv).MEM (^av + 2w + 1w)``, ``m3:word8``)];
val Lg = subst (map (fn (t, v) => t |-> v) bytes) L;
val _ = pr ("BOUND_LHS_GENERAL " ^ term_to_string Lg);
val _ = if null (List.filter (fn v => not (Lib.mem (fst (dest_var v)) ["m0", "m1", "m2", "m3"])) (free_vars Lg)) then pr "BOUND_LHS_DEPENDS_ONLY_ON_FOUR_BYTES"
        else raise Fail "bound LHS has other free variables";
val _ = pr "MARK E1";
val E1 = save_thm ("write_bound_word_normal_form",
  BBLAST_PROVE (mk_eq (Lg, ``(w2w (m0:word8) << 8 + w2w (m1:word8) + (w2w (m2:word8) << 8 + w2w (m3:word8)) + 4w) : word64``)));
val _ = chk "write_bound_word_normal_form" E1;
val _ = pr "MARK E2";
val E2 = thm "write_bound_word_value_no_overflow"
  ``w2n ((w2w (m0:word8) << 8 + w2w (m1:word8) + (w2w (m2:word8) << 8 + w2w (m3:word8)) + 4w) : word64) = w22n [m0; m1] + w22n [m2; m3] + 4 /\
    w22n [m0; m1] + w22n [m2; m3] + 4 < 2 ** 18``
  (map_every (fn q => assume_tac (Q.ISPEC q w2n_lt)) [`m0:word8`, `m1:word8`, `m2:word8`, `m3:word8`] >>
   fs [w22n_def, w2w_def, WORD_MUL_LSL, word_mul_n2w, word_add_n2w] >> show_tac "E2");
val _ = pr "MARK BR";
val BRg = thm "write_bound_numeric_iff_word"
  (mk_eq (``w22n [m0:word8; m1] + w22n [m2:word8; m3] + 4 <= w2n (x3:word64)``, wordsSyntax.mk_word_ls (Lg, ``x3:word64``)))
  (rewrite_tac [E1, WORD_LS, E2]);
(* ---- 2. The residual: every conjunct of ffiwrite_call_pre that is NOT discharged, at the canonical parameters. ---- *)
val b0 = ``(^sv).SP_EL0 - 32w``; val c0 = ``(^sv).REG 0w``; val a0 = ``(^sv).REG 2w``; val g0 = ``mem_dword (^sv).MEM 0x1000280B0w``;
val inst0 = subst [bv |-> b0, cv |-> c0, av |-> a0, gv |-> g0];
val discharged = [``(^sv).PC = 0x100004090w``, ``(^sv).REG 1w = 8w``, bound];
val by_choice = [``(^sv).SP_EL0 = ^bv + 32w``, ``(^sv).REG 0w = ^cv``, ``(^sv).REG 2w = ^av``, ``mem_dword (^sv).MEM 0x1000280B0w = ^gv``];
fun isin l t = List.exists (aconv t) l;
val _ = if List.all (fn t => isin conjs t) (discharged @ by_choice) then pr "ALL_SEVEN_NAMED_CONJUNCTS_FOUND" else raise Fail "conjunct not found";
val rest = List.filter (fn t => not (isin (discharged @ by_choice) t)) conjs;
val _ = pr ("RESIDUAL_CONJUNCTS " ^ Int.toString (length rest));
val _ = List.app (fn t => pr ("RESIDUAL " ^ term_to_string t)) rest;
val res_def = new_definition ("write_call_residual_def", ``write_call_residual ^dmv ^sv <=> ^(inst0 (list_mk_conj rest))``);
val _ = pr ("DEFINITION " ^ thm_to_string res_def);
val nbound = ``w22n [(^sv).MEM ^a0; (^sv).MEM (^a0 + 1w)] + w22n [(^sv).MEM (^a0 + 2w); (^sv).MEM (^a0 + 3w)] + 4 <= w2n (^sv).REG 3w``;
val BRs = INST [``m0:word8`` |-> ``(^sv).MEM ^a0``, ``m1:word8`` |-> ``(^sv).MEM (^a0 + 1w)``, ``m2:word8`` |-> ``(^sv).MEM (^a0 + 2w)``,
                ``m3:word8`` |-> ``(^sv).MEM (^a0 + 2w + 1w)``, ``x3:word64`` |-> reg3] BRg;
val _ = if aconv (rhs (concl BRs)) (inst0 bound) then pr "BRIDGE_CONCLUSION_IS_THE_DEFINITION_CONJUNCT" else raise Fail "bridge does not match the conjunct";
val w3 = prove (``(a:word64) + 2w + 1w = a + 3w``, simp []);
val BRs' = thm "write_bound_at_call_state" (mk_eq (nbound, inst0 bound)) (rewrite_tac [GSYM BRs, w3]);
val preC = list_mk_comb (fst (strip_comb pre_l), [dmv, sv, b0, c0, a0, g0]);
val _ = pr "MARK PRE";
val PRE1 = thm "write_call_pre_from_residual"
  ``^sv.PC = 0x100004090w /\ ^sv.REG 1w = 8w /\ ^nbound /\ write_call_residual ^dmv ^sv ==> ^preC``
  (rewrite_tac [pre_def, res_def, BRs'] >> strip_tac >> rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >> TRY (simp [] >> NO_TAC) >> show_tac "PRE1");
val PRE2 = thm "write_call_pre_gives_residual"
  ``ffiwrite_call_pre ^dmv ^sv b c a g ==>
    b = ^b0 /\ c = ^c0 /\ a = ^a0 /\ g = ^g0 /\ ^sv.PC = 0x100004090w /\ ^sv.REG 1w = 8w /\ ^nbound /\ write_call_residual ^dmv ^sv``
  (strip_tac >> `b = ^b0 /\ c = ^c0 /\ a = ^a0 /\ g = ^g0` by (fs [pre_def] >> show_tac "PRE2-eq") >> rveq >> asm_rewrite_tac [] >>
   pop_assum mp_tac >> rewrite_tac [pre_def, res_def, BRs'] >> strip_tac >> rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >> TRY (simp [] >> NO_TAC) >> show_tac "PRE2");
val SATR = thm "write_call_residual_satisfiable" ``?dm s. s.PC = 0x100004090w /\ s.REG 1w = 8w /\ ^nbound /\ write_call_residual dm s``
  (strip_assume_tac (DB.fetch "forge_refundFfiwriteSite" "ffiwrite_call_pre_satisfiable") >> imp_res_tac PRE2 >> metis_tac []);
(* ---- 3. Composition with the refund theorem and the U398 path. ---- *)
val T3b = WA "refund_terminating_run_reaches_valid_write_call";
val (prem, _) = dest_imp (concl T3b);
val returns = DB.fetch "forge_refundFfiwriteSuccess" "cake_ffiwrite_path_returns";
fun fv th n = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars (concl th)));
val ms1v = mk_var ("ms1", type_of sv);
val to1 = subst [sv |-> ms1v];
val returnsC = INST [fv returns "s" |-> ms1v, fv returns "b" |-> to1 b0, fv returns "c" |-> to1 c0, fv returns "a" |-> to1 a0, fv returns "g" |-> to1 g0] returns;
val (_, pathC) = dest_imp (concl returnsC);
val msv = valOf (List.find (fn v => fst (dest_var v) = "ms") (free_vars prem));
val mc0 = valOf (List.find (fn v => fst (dest_var v) = "mc0") (free_vars prem));
val _ = pr "MARK T5";
val T5 = thm "refund_terminating_run_write_path_under_residual"
  ``^prem ==>
    ?mc1 ffi1 ms1. machine_reach ^mc0 (basis_ffi ext cl fs) ^msv mc1 ffi1 ms1 /\ ms1.PC = 0x100004090w /\ ms1.REG 1w = 8w /\ ^(to1 (inst0 bound)) /\
       !dm'. write_call_residual dm' ms1 ==> ^(subst [fv returns "dm" |-> ``dm':word64 set``] pathC)``
  (strip_tac >> mp_tac T3b >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
   qexistsl_tac [`mc1`, `ffi1`, `ms1`] >> asm_rewrite_tac [] >>
   `^(to1 (inst0 bound))` by (rewrite_tac [GSYM (INST [sv |-> ms1v] BRs')] >> fs [] >> show_tac "T5-bound") >>
   asm_rewrite_tac [] >> rpt strip_tac >>
   match_mp_tac (INST [fv returns "dm" |-> ``dm':word64 set``] returnsC) >>
   match_mp_tac (INST [sv |-> ms1v, dmv |-> ``dm':word64 set``] PRE1) >> asm_rewrite_tac [] >> fs [] >> show_tac "T5-pre");
(* ---- 4. Oracle level: when a write call succeeds, when it fails, and what a failure does. ---- *)
val _ = pr "MARK O";
val O1 = thm "valid_write_to_open_fd_succeeds"
  ``LENGTH (c:word8 list) = 8 /\ w22n [n1; n0] + w22n [o1; o0] <= LENGTH tll /\
    ALOOKUP fs.infds (w82n c) = SOME (ino, WriteMode, off) /\ ALOOKUP fs.inode_tbl ino = SOME content /\ fs.numchars <> [||] ==>
    ?rest fs'. ffi_write c (n1::n0::o1::o0::tll) fs = SOME (FFIreturn (0w :: rest) fs')``
  (strip_tac >> Cases_on `fs.numchars` >> fs [] >>
   simp [ffi_write_def, write_def, OPTION_CHOICE_EQUALS_OPTION] >> show_tac "O1");
val O2 = thm "write_to_closed_fd_fails_with_valid_clen"
  ``LENGTH (c:word8 list) = 8 /\ ALOOKUP fs.infds (w82n c) = NONE ==>
    ffi_write c (n1::n0::o1::o0::tll) fs = SOME (FFIreturn (1w::n0::o1::o0::tll) fs)``
  (strip_tac >> simp [ffi_write_def, write_def, OPTION_CHOICE_EQUALS_OPTION, LUPDATE_def] >> show_tac "O2");
val O3 = thm "replay_ignores_failed_write_with_valid_clen"
  ``LENGTH (c:word8 list) = 8 /\ ALOOKUP (SND st).infds (w82n c) = NONE ==>
    extract_fs_with_numchars ext st (IO_event (ExtCall «write») c (ZIP (n1::n0::o1::o0::tll, 1w::n0::o1::o0::tll)) :: l) =
    extract_fs_with_numchars ext st l /\
    ~write_ok_event (IO_event (ExtCall «write») c (ZIP (n1::n0::o1::o0::tll, 1w::n0::o1::o0::tll)))``
  (strip_tac >> drule_all O2 >> strip_tac >> simp [extract_fs_with_numchars_def, fs_ffi_part_def, MAP_ZIP, wok_def, ZIP_def] >> show_tac "O3");
val BO2 = thm "basis_write_call_state_change"
  ``(ffi1:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\ call_FFI ffi1 (ExtCall «write») c ab = FFI_return ffi2 nb ==>
    ?fs'. ffi_write c ab (SND ffi1.ffi_state) = SOME (FFIreturn nb fs') /\ ffi2.ffi_state = (FST ffi1.ffi_state, fs')``
  (strip_tac >> pop_assum mp_tac >> simp [call_FFI_def, basis_ffi_oracle_def] >>
   Cases_on `ffi1.ffi_state` >> simp [] >> rpt (CASE_TAC >> simp []) >> rpt strip_tac >> gvs [] >> show_tac "BO2");
val O4 = thm "failed_write_call_keeps_the_file_system"
  ``(ffi1:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\ call_FFI ffi1 (ExtCall «write») c ab = FFI_return ffi2 nb /\ (!rest. nb <> 0w :: rest) ==>
    ffi2.ffi_state = ffi1.ffi_state /\ nb = LUPDATE 1w 0 ab``
  (strip_tac >> drule_all BO2 >> strip_tac >> imp_res_tac (WA "ffi_write_return_cases") >> gvs [] >> Cases_on `ffi1.ffi_state` >> fs [] >> show_tac "O4");
(* ---- 5. Connection of an event-level property of the trace to call states (the property itself is NOT proved for refund). ---- *)
val A1 = WA "successful_write_events_have_valid_call_states";
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val mc = mk_var ("mc", mcty);
val okst = ``?mc1 ffi1 ms1. machine_reach ^mc (ffi:^(ty_antiq bty)) ms mc1 ffi1 ms1 /\ ms1.PC = 0x100004090w /\ ms1.REG 1w = 8w /\ ^(to1 (inst0 bound))``;
val _ = pr "MARK C1";
val C1 = thm "all_successful_trace_gives_valid_call_state_per_write_event"
  ``refund_static ^mc dm /\ (ffi:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\ targetSem$evaluate mc ffi k ms = (r, ms', ffi') ==>
    ?l. ffi'.io_events = ffi.io_events ++ l /\
        ((!e. MEM e l /\ write_event e ==> write_ok_event e) ==> !e. MEM e l /\ write_event e ==> ^okst)``
  (strip_tac >> drule_all A1 >> strip_tac >> qexists_tac `l` >> asm_rewrite_tac [] >> rpt strip_tac >>
   `write_ok_event e` by metis_tac [] >> first_x_assum drule_all >> strip_tac >>
   qexistsl_tac [`mc1`, `ffi1`, `ms1`] >> asm_rewrite_tac [] >>
   rewrite_tac [GSYM (INST [sv |-> ms1v] BRs')] >> fs [] >> show_tac "C1");
(* ---- 6. Negative controls. ---- *)
val _ = pr "MARK K";
val K1 = thm "sixteen_bit_sum_would_overflow" ``(n2w (65535 + 65535 + 4) : word16) = 2w /\ 65535 + 65535 + 4 < 2 ** 18 /\ ~(65535 + 65535 + 4 < 2 ** 16)`` EVAL_TAC;
val K2 = thm "numeric_bound_does_not_give_sign_of_x3"
  ``?x3:word64. w22n [255w; 255w] + w22n [255w; 255w] + 4 <= w2n x3 /\ word_msb x3``
  (qexists_tac `0x8000000000000000w` >> EVAL_TAC);
val K3 = thm "negative_x3_not_covered" ``word_msb (^sv.REG 3w) ==> ~ffiwrite_call_pre ^dmv ^sv b c a g /\ ~write_call_residual ^dmv ^sv``
  (rw [pre_def, res_def] >> fs []);
val K4 = thm "violated_numeric_bound_not_covered" ``~^nbound ==> ~ffiwrite_call_pre ^dmv ^sv b c a g``
  (rpt strip_tac >> imp_res_tac PRE2 >> fs []);
val K5 = thm "failed_event_is_a_write_event_but_not_successful"
  ``write_event (IO_event (ExtCall «write») c (ZIP (h::t, LUPDATE 1w 0 (h::t)))) /\ ~write_ok_event (IO_event (ExtCall «write») c (ZIP (h::t, LUPDATE 1w 0 (h::t))))``
  (simp [wev_def, wok_def, LUPDATE_def, ZIP_def]);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundWriteWord");
val closure = "forge_refundWriteWord" :: Theory.ancestry "forge_refundWriteWord";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundWriteWord")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
