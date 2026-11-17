(* U400: (1) the rendered refund response is not empty; (2) a successful write event (result byte 0) of the basis oracle
   carries clen = 8 and the buffer bound to its reachable call state in the MODEL machine of the published target semantics.
   NOT modelled, NOT proved: the real process, libSystem write, loader, slide, write_call_rel, a terminating refund run.
   Nothing is assumed about arguments; failed write events (result byte 1) give no argument facts. *)
open preamble targetSemTheory ffiTheory semanticsPropsTheory fsFFITheory fsFFIPropsTheory basis_ffiTheory TextIOProofTheory mlstringTheory
     MarshallingTheory arm8Theory arm8_targetTheory forge_refundSourceNonFailTheory forge_refundCallSiteTheory forge_refundFfiwriteSiteTheory
     forge_refundFfiwriteSuccessTheory forge_refundWriteReachTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundWriteArgs";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
(* mk_thm is used ONLY to let later lemmas be explored after a failure; the run raises Fail before export if any lemma failed,
   and every stored theorem is tag-checked. *)
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; mk_thm ([], goal));
fun CS n = DB.fetch "forge_refundCallSite" n;
fun WR n = DB.fetch "forge_refundWriteReach" n;
val [static_def, seq_def, step_def, reachn_def, reach_def, S1, S2, R0, R1] = map CS ["refund_static_def", "mc_static_eq_def", "machine_step_def",
      "machine_reach_n_def", "machine_reach_def", "normal_step_is_machine_step", "extcall_step_is_machine_step", "machine_reach_refl",
      "machine_reach_n_evaluate"];
val [wev_def, rev_def, static_seq, RS, SE, S3, CF, ST1, T1, FRr, FRo, FRc, F3] = map WR ["write_event_def", "refund_event_def", "refund_static_step",
      "machine_step_reach", "machine_step_evaluate", "install_step_is_machine_step", "call_FFI_return_appends_one_event", "refund_static_ffi_index",
      "terminating_trace_with_write_event_reaches_write_call", "ffi_read_keeps_inodes", "ffi_open_in_keeps_inodes", "ffi_close_keeps_inodes",
      "add_stdout_changes_inodes"];
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val mc = mk_var ("mc", mcty); val mc1 = mk_var ("mc1", mcty); val mc' = mk_var ("mc'", mcty); val mcw = mk_var ("mcw", mcty);
val names4 = ``[«read»; «write»; «close»; «open_in»]``;
val bty = type_of ``basis_ffi ext cl fs``;
val bst = hd (snd (dest_type bty));
val tg = prove (``arm8_target.get_pc (ms:arm8_state) = ms.PC``, simp [arm8_target_def]);
val sseq = prove (``refund_static ^mc dm /\ mc_static_eq mc ^mc1 ==> refund_static mc1 dm``, simp [static_def, seq_def]);
(* ---- 1. The rendered response is not empty (all fields). ---- *)
val rt = CONJUNCT1 (DB.fetch "forge_refundWireProg" "refund_render_fields_roundtrip");
val pl = DB.fetch "mlsexp" "parse_IMP_LENGTH_LESS";
val _ = pr ("USED " ^ thm_to_string rt); val _ = pr ("USED " ^ thm_to_string pl);
val _ = pr "MARK NE";
val NE = thm "refund_render_fields_not_empty" ``refund_render_fields flds <> «»``
  (PairCases_on `flds` >> strip_tac >>
   assume_tac (Q.INST [`ok` |-> `flds0`, `a` |-> `flds1`, `r` |-> `flds2`, `c` |-> `flds3`, `q` |-> `flds4`, `n` |-> `flds5`] rt) >>
   rfs [] >> imp_res_tac pl >> fs [] >> show_tac "NE");
val KE1 = thm "empty_string_is_not_a_complete_sexp" ``mlsexp$parse (explode «») <> INR (x, [])``
  (strip_tac >> imp_res_tac pl >> fs [] >> show_tac "KE1");
(* ---- 2. The oracle: a write call that returns either failed silently or had valid arguments. ---- *)
val _ = pr "MARK Wn";
val Wn = thm "fs_write_needs_enough_chars" ``fsFFI$write fd n chars fs = SOME (nw, fs') ==> n <= LENGTH chars``
  (rw [write_def] >> rpt (pairarg_tac >> gvs []) >> gvs [AllCaseEqs()] >> rpt (pairarg_tac >> gvs []) >> show_tac "Wn");
val _ = pr "MARK W1";
val W1 = thm "ffi_write_return_cases"
  ``ffi_write c bytes fs = SOME (FFIreturn bytes' fs') ==>
    (bytes' = LUPDATE 1w 0 bytes /\ fs' = fs) \/
    (LENGTH c = 8 /\ ?n1 n0 o1 o0 tll rest. bytes = n1::n0::o1::o0::tll /\ bytes' = 0w :: rest /\
        w22n [n1; n0] + w22n [o1; o0] + 4 <= LENGTH bytes)``
  (strip_tac >> Cases_on `bytes` >- fs [ffi_write_def] >> rename1 `h1::t1` >>
   Cases_on `t1` >- fs [ffi_write_def] >> rename1 `h1::h2::t2` >>
   Cases_on `t2` >- fs [ffi_write_def] >> rename1 `h1::h2::h3::t3` >>
   Cases_on `t3` >- fs [ffi_write_def] >> rename1 `h1::h2::h3::h4::t4` >>
   qpat_x_assum `ffi_write _ _ _ = _` mp_tac >> simp [ffi_write_def, OPTION_CHOICE_EQUALS_OPTION] >> strip_tac >> gvs [] >>
   rpt (pairarg_tac >> gvs []) >> imp_res_tac Wn >> fs [LUPDATE_def] >> show_tac "W1");
(* ---- 3. Successful write events and the file-system replay. ---- *)
val wok_def = new_definition ("write_ok_event_def",
  ``write_ok_event (e:io_event) <=> ?c (x:word8) bs. e = IO_event (ExtCall «write») c ((x, 0w) :: bs)``);
val _ = pr ("DEFINITION " ^ thm_to_string wok_def);
val ms0 = prove (``MAP SND (b:(word8 # word8) list) = 0w :: rest ==> ?x bs. b = (x, 0w) :: bs``,
  Cases_on `b` >> simp [] >> Cases_on `h` >> simp []);
val _ = pr "MARK Lw";
val Lw = thm "failed_write_event_keeps_fs"
  ``ffi_write c (MAP FST b) fs = SOME (FFIreturn (MAP SND b) fs') /\ ~write_ok_event (IO_event (ExtCall «write») c b) ==> fs' = fs``
  (strip_tac >> imp_res_tac W1 >> imp_res_tac ms0 >> gvs [wok_def] >> show_tac "Lw");
val _ = pr "MARK F1b";
val F1b = thm "replay_without_successful_write_keeps_inodes"
  ``!l st st'. extract_fs_with_numchars ext st l = SOME st' /\ EVERY refund_event l /\ ~EXISTS write_ok_event l ==>
               (SND st').inode_tbl = (SND st).inode_tbl``
  (Induct >- simp [extract_fs_with_numchars_def] >>
   rpt gen_tac >> simp [rev_def] >> strip_tac >> rveq >> fs [] >> rveq >> fs [] >>
   qpat_x_assum `extract_fs_with_numchars _ _ _ = _` mp_tac >>
   simp [extract_fs_with_numchars_def, fs_ffi_part_def] >> rpt (CASE_TAC >> simp []) >> strip_tac >>
   first_x_assum drule >> simp [] >> strip_tac >> rveq >>
   imp_res_tac FRr >> imp_res_tac FRo >> imp_res_tac FRc >> imp_res_tac Lw >> fs [] >> show_tac "F1b");
val _ = pr "MARK F2b";
val F2b = thm "nonempty_output_needs_successful_write_event"
  ``extract_fs ext (cl, fs) io = SOME (add_stdout (fastForwardFD fs 0) out) /\ STD_streams fs /\ EVERY refund_event io /\ out <> «» ==>
    EXISTS write_ok_event io``
  (rpt strip_tac >> CCONTR_TAC >>
   Cases_on `extract_fs_with_numchars ext (cl,fs) io` >- fs [extract_fs_def] >>
   rename1 `_ = SOME z` >>
   `(SND z).inode_tbl = fs.inode_tbl` by
      (mp_tac (Q.SPECL [`io`, `(cl,fs)`, `z`] F1b) >> asm_rewrite_tac [] >> simp_tac (srw_ss()) []) >>
   `add_stdout (fastForwardFD fs 0) out = SND z with numchars := fs.numchars` by
      (qpat_x_assum `extract_fs _ _ _ = _` mp_tac >> asm_simp_tac (srw_ss()) [extract_fs_def] >> TRY (metis_tac []) >> show_tac "F2b-b") >>
   `(add_stdout (fastForwardFD fs 0) out).inode_tbl = fs.inode_tbl` by (pop_assum (fn th => rewrite_tac [th]) >> asm_simp_tac (srw_ss()) []) >>
   metis_tac [F3]);
(* ---- 4. One step of the target semantics; the event keeps the arrays and the oracle call. ---- *)
val ev = ``targetSem$evaluate ^mc (ffi:'ffi ffi_state) (SUC k) (ms:arm8_state) = (r, ms':arm8_state, ffi':'ffi ffi_state)``;
val onec = ``ffi' = (ffi:'ffi ffi_state) \/
   (?mc2 ms2. machine_step ^mc ffi (ms:arm8_state) mc2 ffi ms2 /\ targetSem$evaluate mc2 ffi k ms2 = (r, ms':arm8_state, ffi')) \/
   (?mc2 ms2 ffi2 nm c ab nb. machine_step mc ffi ms mc2 ffi2 ms2 /\ targetSem$evaluate mc2 ffi2 k ms2 = (r, ms', ffi') /\
        ffi2.io_events = ffi.io_events ++ [IO_event (ExtCall nm) c (ZIP (ab, nb))] /\ MEM nm ^names4 /\ (nm = «write» ==> ms.PC = 0x100004090w) /\
        read_ffi_bytearrays mc ms = (SOME c, SOME ab) /\ call_FFI ffi (ExtCall nm) c ab = FFI_return ffi2 nb)``;
val U = qpat_x_assum `targetSem$evaluate _ _ (SUC k) _ = _` mp_tac >> simp [Once evaluate_def, apply_oracle_def] >> rw [] >> fs [];
val pcin = ``(^mc).target.get_pc (ms:arm8_state) IN ((^mc).prog_addresses DIFF set (^mc).ffi_entry_pcs)``;
val _ = pr "MARK ONE";
val ONE_A = thm "one_step_normal_args" ``^pcin /\ ^ev ==> ^onec``
  (strip_tac >>
   Cases_on `encoded_bytes_in_mem mc.target.config (mc.target.get_pc ms) (mc.target.get_byte ms) mc.prog_addresses /\
             EVERY mc.target.state_ok [ms; mc.target.next ms; mc.next_interfer 0 (mc.target.next ms)] /\
             (!x. x NOTIN mc.prog_addresses ==> mc.target.get_byte (mc.target.next ms) x = mc.target.get_byte ms x)`
   >- (disj2_tac >> disj1_tac >>
       `machine_step mc ffi ms (mc with next_interfer := shift_seq 1 mc.next_interfer) ffi (mc.next_interfer 0 (mc.target.next ms))` by
          (match_mp_tac S1 >> fs [] >> show_tac "A1-S1") >>
       metis_tac [SE])
   >- (disj1_tac >> U >> TRY (metis_tac []) >> show_tac "A2"));
val ONE_H = thm "one_step_halt_args" ``~^pcin /\ (^mc).target.get_pc (ms:arm8_state) = (^mc).halt_pc /\ ^ev ==> ^onec``
  (strip_tac >> disj1_tac >> U >> show_tac "H");
val ONE_I = thm "one_step_install_args"
  ``~^pcin /\ (^mc).target.get_pc (ms:arm8_state) <> (^mc).halt_pc /\ (^mc).target.get_pc ms = (^mc).install_pc /\ ^ev ==> ^onec``
  (strip_tac >> Cases_on `read_ffi_bytearray mc mc.ptr_reg mc.len_reg ms`
   >- (disj1_tac >> U >> show_tac "I-NONE")
   >- (disj2_tac >> disj1_tac >> rename1 `_ = SOME bytes` >>
       `machine_step mc ffi ms (mc with install_interfer := shift_seq 1 mc.install_interfer) ffi (mc.install_interfer 0 (bytes, ms))` by
          (match_mp_tac S3 >> fs [] >> show_tac "I-S3") >>
       metis_tac [SE]));
val ONE_F = thm "one_step_ffi_args"
  ``~^pcin /\ (^mc).target.get_pc (ms:arm8_state) <> (^mc).halt_pc /\ (^mc).target.get_pc ms <> (^mc).install_pc /\
    find_index ((^mc).target.get_pc ms) (^mc).ffi_entry_pcs 0 = SOME i /\ EL i (^mc).ffi_names = ExtCall nm /\ ALOOKUP (^mc).mmio_info i = NONE /\
    nm <> «» /\ MEM nm ^names4 /\ (nm = «write» ==> ms.PC = 0x100004090w) /\ ^ev ==> ^onec``
  (strip_tac >> Cases_on `read_ffi_bytearrays mc ms` >> rename1 `_ = (q1, q2)` >>
   Cases_on `q1` >- (disj1_tac >> U >> show_tac "F-q1") >>
   Cases_on `q2` >- (disj1_tac >> U >> show_tac "F-q2") >>
   rename1 `_ = (SOME cb, SOME ab)` >>
   Cases_on `call_FFI ffi (ExtCall nm) cb ab`
   >- (rename1 `_ = FFI_return new_ffi nb` >> disj2_tac >> disj2_tac >>
       `machine_step mc ffi ms (mc with ffi_interfer := shift_seq 1 mc.ffi_interfer) new_ffi (mc.ffi_interfer 0 (i, nb, ms))` by
          (mp_tac (Q.INST [`cbytes` |-> `cb`, `abytes` |-> `ab`] S2) >> (impl_tac >- (asm_rewrite_tac [] >> show_tac "F-S2")) >> disch_then ACCEPT_TAC) >>
       `new_ffi.io_events = ffi.io_events ++ [IO_event (ExtCall nm) cb (ZIP (ab, nb))]` by (match_mp_tac CF >> asm_rewrite_tac []) >>
       qexistsl_tac [`mc with ffi_interfer := shift_seq 1 mc.ffi_interfer`, `mc.ffi_interfer 0 (i, nb, ms)`, `new_ffi`, `nm`, `cb`, `ab`, `nb`] >>
       asm_rewrite_tac [] >> metis_tac [SE])
   >- (disj1_tac >> U >> show_tac "F-final"));
val ONE = thm "one_step_cases_args" ``refund_static ^mc dm /\ ^ev ==> ^onec``
  (strip_tac >> Cases_on `^pcin` >- (match_mp_tac ONE_A >> asm_rewrite_tac []) >>
   Cases_on `mc.target.get_pc ms = mc.halt_pc` >- (match_mp_tac ONE_H >> asm_rewrite_tac []) >>
   Cases_on `mc.target.get_pc ms = mc.install_pc` >- (match_mp_tac ONE_I >> asm_rewrite_tac [] >> fs [] >> show_tac "ONE-I") >>
   Cases_on `find_index (mc.target.get_pc ms) mc.ffi_entry_pcs 0`
   >- (disj1_tac >> U >> show_tac "ONE-NOIDX") >>
   rename1 `_ = SOME i` >> drule_all ST1 >> strip_tac >> match_mp_tac ONE_F >> metis_tac []);
(* ---- 5. Every write event of a run has its own reachable call state, with the same arrays and the same oracle call. ---- *)
val callst = ``?mcw ffiw msw ffix. machine_reach ^mc (ffi:'ffi ffi_state) ms mcw ffiw msw /\ msw.PC = 0x100004090w /\
     read_ffi_bytearrays mcw msw = (SOME c, SOME ab) /\ call_FFI ffiw (ExtCall «write») c ab = FFI_return ffix nb``;
val _ = pr "MARK MAIN2";
val MAIN2 = thm "evaluate_trace_write_events_have_call_states"
  ``!k mc ffi ms r ms' ffi'. refund_static ^mc dm /\ targetSem$evaluate mc (ffi:'ffi ffi_state) k ms = (r, ms', ffi') ==>
      ?l. ffi'.io_events = ffi.io_events ++ l /\
          !c bs. MEM (IO_event (ExtCall «write») c bs) l ==> ?ab nb. bs = ZIP (ab, nb) /\ ^callst``
  (Induct
   >- (rw [Once evaluate_def] >> qexists_tac `[]` >> simp [])
   >> rpt gen_tac >> strip_tac >> drule_all ONE >> strip_tac
   >- (qexists_tac `[]` >> asm_rewrite_tac [] >> simp [])
   >- (`refund_static mc2 dm` by metis_tac [static_seq] >>
       first_x_assum (qspecl_then [`mc2`, `ffi`, `ms2`, `r`, `ms'`, `ffi'`] mp_tac) >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
       qexists_tac `l` >> asm_rewrite_tac [] >> rpt strip_tac >> first_x_assum drule >> strip_tac >>
       `machine_reach mc ffi ms mcw ffiw msw` by metis_tac [RS] >> metis_tac [])
   >- (`refund_static mc2 dm` by metis_tac [static_seq] >>
       first_x_assum (qspecl_then [`mc2`, `ffi2`, `ms2`, `r`, `ms'`, `ffi'`] mp_tac) >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
       qexists_tac `IO_event (ExtCall nm) c (ZIP (ab, nb)) :: l` >> conj_tac
       >- (asm_rewrite_tac [] >> simp [] >> show_tac "MAIN2-APP")
       >- (rpt gen_tac >> simp [] >> strip_tac
           >- (rveq >> fs [] >> qexistsl_tac [`ab`, `nb`] >> simp [] >> metis_tac [R0])
           >- (first_x_assum drule >> strip_tac >>
               `machine_reach mc ffi ms mcw ffiw msw` by metis_tac [RS] >> metis_tac []))));
(* ---- 6. The basis oracle and the register arguments. ---- *)
val _ = pr "MARK BO";
val BO = thm "basis_write_call_is_ffi_write"
  ``(ffi1:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\ call_FFI ffi1 (ExtCall «write») c ab = FFI_return ffi2 nb ==>
    ?fs'. ffi_write c ab (SND ffi1.ffi_state) = SOME (FFIreturn nb fs') /\ LENGTH nb = LENGTH ab``
  (strip_tac >> pop_assum mp_tac >> simp [call_FFI_def, basis_ffi_oracle_def] >>
   Cases_on `ffi1.ffi_state` >> simp [] >> rpt (CASE_TAC >> simp []) >> rpt strip_tac >> gvs [] >> show_tac "BO");
val RB4 = thm "read_bytearray_first_four"
  ``read_bytearray (a:word64) n f = SOME ((n1:word8)::n0::o1::o0::tll) ==>
    f a = SOME n1 /\ f (a + 1w) = SOME n0 /\ f (a + 2w) = SOME o1 /\ f (a + 3w) = SOME o0``
  (strip_tac >> imp_res_tac read_bytearray_LENGTH >>
   `n = SUC (SUC (SUC (SUC (LENGTH tll))))` by fs [] >> pop_assum SUBST_ALL_TAC >>
   fs [read_bytearray_def, AllCaseEqs()] >> show_tac "RB4");
val _ = pr "MARK RL";
val RL = thm "write_call_arrays_are_the_register_arguments"
  ``refund_static ^mc dm /\ read_ffi_bytearrays mc (ms:arm8_state) = (SOME c, SOME ab) ==>
    LENGTH c = w2n (ms.REG 1w) /\ LENGTH ab = w2n (ms.REG 3w) /\
    (!n1 n0 o1 o0 tll. ab = n1::n0::o1::o0::tll ==>
        ms.MEM (ms.REG 2w) = n1 /\ ms.MEM (ms.REG 2w + 1w) = n0 /\ ms.MEM (ms.REG 2w + 2w) = o1 /\ ms.MEM (ms.REG 2w + 3w) = o0)``
  (simp [static_def, read_ffi_bytearrays_def, read_ffi_bytearray_def] >> strip_tac >> fs [arm8_target_def] >> show_tac "RL-0" >>
   imp_res_tac read_bytearray_LENGTH >> rpt conj_tac >> TRY (fs [] >> NO_TAC) >> rpt gen_tac >> strip_tac >> rveq >> imp_res_tac RB4 >> fs [arm8_target_def] >> rfs [] >> show_tac "RL");
val ok_args = ``(ms1:arm8_state).REG 1w = 8w /\
    w22n [ms1.MEM (ms1.REG 2w); ms1.MEM (ms1.REG 2w + 1w)] + w22n [ms1.MEM (ms1.REG 2w + 2w); ms1.MEM (ms1.REG 2w + 3w)] + 4 <= w2n (ms1.REG 3w)``;
val _ = pr "MARK A0";
val A0 = thm "successful_write_call_state_has_valid_arguments"
  ``refund_static ^mc1 dm /\ (ffi1:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\ read_ffi_bytearrays mc1 ms1 = (SOME c, SOME ab) /\
    call_FFI ffi1 (ExtCall «write») c ab = FFI_return ffi2 (0w :: rest) ==> ^ok_args``
  (strip_tac >> drule_all BO >> strip_tac >> drule_all RL >> strip_tac >> imp_res_tac W1
   >- (Cases_on `ab` >> fs [LUPDATE_def] >> show_tac "A0-fail")
   >- (first_x_assum (qspecl_then [`n1`, `n0`, `o1`, `o0`, `tll`] mp_tac) >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
       `ms1.REG 1w = 8w` by (rewrite_tac [GSYM w2n_11] >> fs [] >> show_tac "A0-reg") >>
       rveq >> fs [] >> show_tac "A0-ok"));
val _ = pr "MARK A1";
val A1 = thm "successful_write_events_have_valid_call_states"
  ``!k mc ffi ms r ms' ffi'. refund_static ^mc dm /\ (ffi:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\
      targetSem$evaluate mc ffi k ms = (r, ms', ffi') ==>
      ?l. ffi'.io_events = ffi.io_events ++ l /\
          !e. MEM e l /\ write_ok_event e ==> ?mc1 ffi1 ms1. machine_reach mc ffi ms mc1 ffi1 ms1 /\ ms1.PC = 0x100004090w /\ ^ok_args``
  (rpt strip_tac >> drule_all (INST_TYPE [``:'ffi`` |-> bst] MAIN2) >> strip_tac >> qexists_tac `l` >> asm_rewrite_tac [] >> rpt strip_tac >>
   fs [wok_def] >> rveq >> first_x_assum drule >> strip_tac >>
   show_tac "A1-0" >> `?n. machine_reach_n n mc ffi ms mcw ffiw msw` by metis_tac [reach_def] >> drule R1 >> strip_tac >>
   `refund_static mcw dm` by metis_tac [sseq] >>
   `ffiw.oracle = basis_ffi_oracle ext` by metis_tac [] >>
   drule_all BO >> strip_tac >>
   `?rest. nb = 0w :: rest` by (Cases_on `ab` >> Cases_on `nb` >> fs [] >> show_tac "A1-nb") >> rveq >>
   show_tac "A1-1" >> drule_all A0 >> strip_tac >> qexistsl_tac [`mcw`, `ffiw`, `msw`] >> asm_rewrite_tac [] >> show_tac "A1-2");
(* ---- 7. The refund program on the model machine. Successful termination stays an explicit premise. ---- *)
val beh = DB.fetch "forge_refundSourceNonFail" "refund_behavior_valid_request_no_handler";
val (beh_ante, beh_conc) = dest_imp (concl beh);
val (iov, beh_body) = dest_exists beh_conc;
val [beh_sub, beh_fs] = strip_conj beh_body;
val out_tm = rand (rand (rhs beh_fs));
val mc0 = valOf (List.find (fn v => fst (dest_var v) = "mc0") (free_vars beh_ante));
val msv = valOf (List.find (fn v => fst (dest_var v) = "ms") (free_vars beh_ante));
val bffi = ``basis_ffi ext cl fs``;
fun instn th l = INST (map (fn (n, tm) => let val v = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars (concl th))) in
     if type_of v = type_of tm then () else pr ("INSTN_TYPE_MISMATCH " ^ n ^ " : " ^ type_to_string (type_of v) ^ " VERSUS " ^ type_to_string (type_of tm)); v |-> tm end) l) th;
val T1b = INST_TYPE [``:'ffi`` |-> bst] T1;
val prem = ``^beh_ante /\ refund_static ^mc0 dm /\ machine_sem ^mc0 ^bffi ^msv (Terminate Success io')``;
val reachok = ``?mc1 ffi1 ms1. machine_reach ^mc0 ^bffi ^msv mc1 ffi1 ms1 /\ ms1.PC = 0x100004090w /\ ^ok_args``;
val _ = pr "MARK T3b";
val T3b = thm "refund_terminating_run_reaches_valid_write_call" ``^prem ==> EXISTS write_ok_event io' /\ ^reachok``
  (strip_tac >> mp_tac beh >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
   `Terminate Success io' IN extend_with_resource_limit {Terminate Success io_events}` by (fs [SUBSET_DEF, IN_DEF] >> show_tac "T3b-IN") >>
   `io' = io_events` by (pop_assum mp_tac >> simp [extend_with_resource_limit_def] >> show_tac "T3b-EQ") >>
   pop_assum SUBST_ALL_TAC >>
   `(^bffi).io_events = []` by simp [basis_ffi_def] >> `(^bffi).oracle = basis_ffi_oracle ext` by simp [basis_ffi_def] >>
   drule_all T1b >> strip_tac >>
   `EXISTS write_ok_event io_events` by
      (mp_tac (instn F2b [("io", iov), ("out", out_tm)]) >> (impl_tac >- (asm_rewrite_tac [NE] >> show_tac "T3b-F2")) >> disch_then ACCEPT_TAC) >>
   asm_rewrite_tac [] >>
   qpat_x_assum `machine_sem _ _ _ (Terminate _ _)` mp_tac >> simp [machine_sem_def] >> strip_tac >>
   drule_all A1 >> strip_tac >>
   `l = io_events` by metis_tac [APPEND] >> rveq >>
   fs [EXISTS_MEM] >> first_x_assum (qspec_then `e` mp_tac) >> asm_rewrite_tac [] >> disch_then ACCEPT_TAC);
val returns = DB.fetch "forge_refundFfiwriteSuccess" "cake_ffiwrite_path_returns";
fun fv th n = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars (concl th)));
val sv = fv returns "s"; val dmv = fv returns "dm";
val ms1v = mk_var ("ms1", type_of sv); val dm'v = mk_var ("dm'", type_of dmv);
val returns1 = INST [sv |-> ms1v, dmv |-> dm'v] returns;
val path_tm = list_mk_forall (dm'v :: map (fv returns) ["b", "c", "a", "g"], concl returns1);
val _ = pr "MARK T4b";
val T4b = thm "refund_reached_valid_write_call_and_path"
  ``^prem /\ 0x100004090w NOTIN dm ==>
    ?mc1 ffi1 ms1. machine_reach ^mc0 ^bffi ^msv mc1 ffi1 ms1 /\ ms1.PC = 0x100004090w /\ ^ok_args /\
       (?cbytes abytes. read_ffi_bytearrays mc1 ms1 = (SOME cbytes, SOME abytes) /\ 4 <= LENGTH abytes /\ 4 <= w2n (ms1.REG 3w)) /\ ^path_tm``
  (strip_tac >> mp_tac T3b >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
   mp_tac beh >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
   qexistsl_tac [`mc1`, `ffi1`, `ms1`] >> asm_rewrite_tac [] >> conj_tac
   >- (mp_tac (instn (DB.fetch "forge_refundFfiwriteSite" "write_call_site_facts")
                 [("mc", mc0), ("ffi", bffi), ("ms", msv), ("io", ``io_events:io_event list``)]) >>
       (impl_tac >- (asm_rewrite_tac [] >> simp [basis_ffi_def] >> show_tac "T4b-SITE")) >> disch_then ACCEPT_TAC)
   >- (rpt gen_tac >> ACCEPT_TAC returns1));
(* ---- 8. Negative controls. ---- *)
val _ = pr "MARK controls";
val KE2 = thm "empty_trace_has_no_successful_write_and_keeps_fs"
  ``~EXISTS write_ok_event [] /\ extract_fs_with_numchars ext st [] = SOME st``
  (simp [extract_fs_with_numchars_def]);
val KF = thm "failed_write_event_is_not_successful"
  ``~write_ok_event (IO_event (ExtCall «write») c (ZIP (h::t, LUPDATE 1w 0 (h::t)))) /\ ~write_ok_event (IO_event (ExtCall «read») c b) /\
    ~write_ok_event (IO_event (ExtCall «write») c [])``
  (simp [wok_def, LUPDATE_def, ZIP_def]);
val KS = thm "wrong_clen_write_never_succeeds"
  ``LENGTH (c:word8 list) <> 8 /\ ffi_write c bytes fs = SOME (FFIreturn bytes' fs') ==> bytes' = LUPDATE 1w 0 bytes /\ fs' = fs``
  (strip_tac >> imp_res_tac W1 >> fs []);
val KB = thm "out_of_bounds_write_never_succeeds"
  ``LENGTH (bytes:word8 list) < w22n [n1; n0] + w22n [o1; o0] + 4 /\ bytes = n1::n0::o1::o0::tll /\
    ffi_write c bytes fs = SOME (FFIreturn bytes' fs') ==> bytes' = LUPDATE 1w 0 bytes /\ fs' = fs``
  (strip_tac >> imp_res_tac W1 >> gvs []);
val KR = thm "short_array_write_is_rejected" ``LENGTH (bytes:word8 list) < 4 ==> ffi_write c bytes fs = NONE``
  (strip_tac >> simp [ffi_write_def] >> every_case_tac >> fs []);
val KU = thm "write_call_with_unreadable_arrays_is_an_error"
  ``refund_static ^mc dm /\ ms.PC = 0x100004090w /\ ~(?cb ab. read_ffi_bytearrays mc ms = (SOME cb, SOME ab)) ==>
    FST (targetSem$evaluate mc (ffi:'ffi ffi_state) 1 ms) = Error``
  (rw [static_def] >> simp [Once evaluate_def, tg, find_index_def] >>
   Cases_on `read_ffi_bytearrays mc ms` >> rename1 `(q1, q2)` >> Cases_on `q1` >> Cases_on `q2` >> fs []);
val KW = thm "wrong_clen_register_gives_no_successful_write"
  ``refund_static ^mc1 dm /\ (ffi1:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\ read_ffi_bytearrays mc1 ms1 = (SOME c, SOME ab) /\
    ms1.REG 1w <> 8w /\ call_FFI ffi1 (ExtCall «write») c ab = FFI_return ffi2 nb ==> !rest. nb <> 0w :: rest``
  (rpt strip_tac >> rveq >> drule_all A0 >> fs []);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundWriteArgs");
val closure = "forge_refundWriteArgs" :: Theory.ancestry "forge_refundWriteArgs";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundWriteArgs")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
