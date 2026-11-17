(* U399: write events and reachable call states in the published target semantics (model machine).
   A "new write event" is an element IO_event (ExtCall «write») conf bytes appended to ffi.io_events by targetSem$evaluate.
   NOT modelled, NOT proved: the real process, libSystem write, loader, slide, write_call_rel. No reachability is assumed. *)
open preamble targetSemTheory ffiTheory semanticsPropsTheory fsFFITheory fsFFIPropsTheory basis_ffiTheory TextIOProofTheory mlstringTheory
     arm8Theory arm8_targetTheory forge_refundCallSiteTheory forge_refundFfiwriteSiteTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundWriteReach";
val failed = ref ([] : string list); val optfailed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm0 lst name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); lst := name :: !lst; mk_thm ([], goal));
(* mk_thm is used ONLY to let later lemmas be explored after a failure; the run raises Fail before export if any lemma failed,
   and every stored theorem is tag-checked. *)
val thm = thm0 failed; val opt = thm0 optfailed;
fun CS n = DB.fetch "forge_refundCallSite" n;
val [static_def, seq_def, step_def, reachn_def, reach_def, S1, S2, R0] = map CS ["refund_static_def", "mc_static_eq_def", "machine_step_def",
      "machine_reach_n_def", "machine_reach_def", "normal_step_is_machine_step", "extcall_step_is_machine_step", "machine_reach_refl"];
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val mc = mk_var ("mc", mcty); val mc1 = mk_var ("mc1", mcty); val mc' = mk_var ("mc'", mcty); val mc2 = mk_var ("mc2", mcty);
val names4 = ``[«read»; «write»; «close»; «open_in»]``;
val tg = prove (``arm8_target.get_pc (ms:arm8_state) = ms.PC``, simp [arm8_target_def]);
(* ---- 1. Definitions. ---- *)
val wev_def = new_definition ("write_event_def", ``write_event (e:io_event) <=> ?c b. e = IO_event (ExtCall «write») c b``);
val rev_def = new_definition ("refund_event_def", ``refund_event (e:io_event) <=> ?n c b. e = IO_event (ExtCall n) c b /\ MEM n ^names4``);
val _ = List.app (fn d => pr ("DEFINITION " ^ thm_to_string d)) [wev_def, rev_def];
(* ---- 2. One step of the target semantics. ---- *)
val static_seq = thm "refund_static_step" ``refund_static ^mc dm /\ machine_step mc (ffi:'ffi ffi_state) ms ^mc' ffi' ms' ==> refund_static mc' dm``
  (simp [static_def, seq_def, step_def]);
val RS = thm "machine_step_reach" ``machine_step ^mc (ffi:'ffi ffi_state) ms ^mc' ffi' ms' /\ machine_reach mc' ffi' ms' ^mc1 ffi1 ms1 ==>
      machine_reach mc ffi ms mc1 ffi1 ms1``
  (rw [reach_def] >> qexists_tac `SUC n` >> simp [reachn_def] >> metis_tac []);
val SE = thm "machine_step_evaluate" ``machine_step ^mc (ffi:'ffi ffi_state) ms ^mc' ffi' ms' ==>
      !k. targetSem$evaluate mc ffi (SUC k) ms = targetSem$evaluate mc' ffi' k ms'``
  (rw [step_def, ADD1]);
val S3 = thm "install_step_is_machine_step"
  ``mc.target.get_pc ms NOTIN (mc.prog_addresses DIFF set mc.ffi_entry_pcs) /\ mc.target.get_pc ms <> mc.halt_pc /\
    mc.target.get_pc ms = mc.install_pc /\ read_ffi_bytearray mc mc.ptr_reg mc.len_reg ms = SOME bytes ==>
    machine_step ^mc (ffi:'ffi ffi_state) ms (mc with install_interfer := shift_seq 1 mc.install_interfer) ffi (mc.install_interfer 0 (bytes, ms))``
  (strip_tac >> simp [step_def, seq_def] >> gen_tac >> simp [Once evaluate_def, apply_oracle_def] >> fs [] >> show_tac "S3");
val CF = thm "call_FFI_return_appends_one_event"
  ``call_FFI (ffi:'ffi ffi_state) (ExtCall nm) cb ab = FFI_return new_ffi nb /\ nm <> «» ==>
    new_ffi.io_events = ffi.io_events ++ [IO_event (ExtCall nm) cb (ZIP (ab, nb))]``
  (rw [call_FFI_def] >> gvs [AllCaseEqs()] >> show_tac "CF");
val ST1 = thm "refund_static_ffi_index"
  ``refund_static ^mc dm /\ find_index (mc.target.get_pc ms) mc.ffi_entry_pcs 0 = SOME i ==>
    ALOOKUP mc.mmio_info i = NONE /\
    ?nm. EL i mc.ffi_names = ExtCall nm /\ nm <> «» /\ MEM nm ^names4 /\ (nm = «write» ==> ms.PC = 0x100004090w)``
  (simp [static_def] >> strip_tac >> qpat_x_assum `find_index _ _ _ = _` mp_tac >> asm_rewrite_tac [] >> simp [find_index_def, tg] >>
   rw [] >> asm_rewrite_tac [] >>
   FIRST (map (fn q => qexists_tac q >> rpt conj_tac >> TRY (EVAL_TAC >> NO_TAC) >> TRY (simp [] >> NO_TAC) >>
                       TRY (asm_simp_tac (srw_ss()) [] >> NO_TAC) >> NO_TAC) [`«read»`, `«write»`, `«close»`, `«open_in»`]
          @ [show_tac "ST1"]));
val ev = ``targetSem$evaluate ^mc (ffi:'ffi ffi_state) (SUC k) (ms:arm8_state) = (r, ms':arm8_state, ffi':'ffi ffi_state)``;
val onec = ``ffi' = (ffi:'ffi ffi_state) \/
   (?mc2 ms2. machine_step ^mc ffi (ms:arm8_state) mc2 ffi ms2 /\ targetSem$evaluate mc2 ffi k ms2 = (r, ms':arm8_state, ffi')) \/
   (?mc2 ms2 ffi2 nm c b. machine_step mc ffi ms mc2 ffi2 ms2 /\ targetSem$evaluate mc2 ffi2 k ms2 = (r, ms', ffi') /\
        ffi2.io_events = ffi.io_events ++ [IO_event (ExtCall nm) c b] /\ MEM nm ^names4 /\ (nm = «write» ==> ms.PC = 0x100004090w))``;
val U = qpat_x_assum `targetSem$evaluate _ _ (SUC k) _ = _` mp_tac >> simp [Once evaluate_def, apply_oracle_def] >> rw [] >> fs [];
val pcin = ``(^mc).target.get_pc (ms:arm8_state) IN ((^mc).prog_addresses DIFF set (^mc).ffi_entry_pcs)``;
val ONE_A = thm "one_step_normal" ``^pcin /\ ^ev ==> ^onec``
  (strip_tac >>
   Cases_on `encoded_bytes_in_mem mc.target.config (mc.target.get_pc ms) (mc.target.get_byte ms) mc.prog_addresses /\
             EVERY mc.target.state_ok [ms; mc.target.next ms; mc.next_interfer 0 (mc.target.next ms)] /\
             (!x. x NOTIN mc.prog_addresses ==> mc.target.get_byte (mc.target.next ms) x = mc.target.get_byte ms x)`
   >- (disj2_tac >> disj1_tac >>
       `machine_step mc ffi ms (mc with next_interfer := shift_seq 1 mc.next_interfer) ffi (mc.next_interfer 0 (mc.target.next ms))` by
          (match_mp_tac S1 >> fs [] >> show_tac "A1-S1") >>
       metis_tac [SE])
   >- (disj1_tac >> U >> show_tac "A2"));
val ONE_H = thm "one_step_halt" ``~^pcin /\ (^mc).target.get_pc (ms:arm8_state) = (^mc).halt_pc /\ ^ev ==> ^onec``
  (strip_tac >> disj1_tac >> U >> show_tac "H");
val ONE_I = thm "one_step_install" ``~^pcin /\ (^mc).target.get_pc (ms:arm8_state) <> (^mc).halt_pc /\ (^mc).target.get_pc ms = (^mc).install_pc /\ ^ev ==> ^onec``
  (strip_tac >> Cases_on `read_ffi_bytearray mc mc.ptr_reg mc.len_reg ms`
   >- (disj1_tac >> U >> show_tac "I-NONE")
   >- (disj2_tac >> disj1_tac >> rename1 `_ = SOME bytes` >>
       `machine_step mc ffi ms (mc with install_interfer := shift_seq 1 mc.install_interfer) ffi (mc.install_interfer 0 (bytes, ms))` by
          (match_mp_tac S3 >> fs [] >> show_tac "I-S3") >>
       metis_tac [SE]));
val ONE_F = thm "one_step_ffi"
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
          (match_mp_tac S2 >> metis_tac []) >>
       `new_ffi.io_events = ffi.io_events ++ [IO_event (ExtCall nm) cb (ZIP (ab, nb))]` by (match_mp_tac CF >> asm_rewrite_tac []) >>
       qexistsl_tac [`mc with ffi_interfer := shift_seq 1 mc.ffi_interfer`, `mc.ffi_interfer 0 (i, nb, ms)`, `new_ffi`, `nm`, `cb`, `ZIP (ab, nb)`] >>
       asm_rewrite_tac [] >> metis_tac [SE])
   >- (disj1_tac >> U >> show_tac "F-final"));
val ONE = thm "one_step_cases" ``refund_static ^mc dm /\ ^ev ==> ^onec``
  (strip_tac >> Cases_on `^pcin` >- (match_mp_tac ONE_A >> asm_rewrite_tac []) >>
   Cases_on `mc.target.get_pc ms = mc.halt_pc` >- (match_mp_tac ONE_H >> asm_rewrite_tac []) >>
   Cases_on `mc.target.get_pc ms = mc.install_pc` >- (match_mp_tac ONE_I >> asm_rewrite_tac [] >> fs [] >> show_tac "ONE-I") >>
   Cases_on `find_index (mc.target.get_pc ms) mc.ffi_entry_pcs 0`
   >- (disj1_tac >> U >> show_tac "ONE-NOIDX") >>
   rename1 `_ = SOME i` >> drule_all ST1 >> strip_tac >> match_mp_tac ONE_F >> metis_tac []);
(* ---- 3. The trace of a run: appended events, their names, and the first write call state. ---- *)
val reach_tm = ``?mc1 ffi1 ms1. machine_reach ^mc (ffi:'ffi ffi_state) ms mc1 ffi1 ms1 /\ ms1.PC = 0x100004090w``;
val MAIN = thm "evaluate_trace_events"
  ``!k mc ffi ms r ms' ffi'. refund_static ^mc dm /\ targetSem$evaluate mc (ffi:'ffi ffi_state) k ms = (r, ms', ffi') ==>
      ?l. ffi'.io_events = ffi.io_events ++ l /\ EVERY refund_event l /\ (EXISTS write_event l ==> ^reach_tm)``
  (Induct
   >- (rw [Once evaluate_def] >> qexists_tac `[]` >> simp [])
   >> rpt gen_tac >> strip_tac >> drule_all ONE >> strip_tac
   >- (qexists_tac `[]` >> asm_rewrite_tac [] >> simp [])
   >- (`refund_static mc2 dm` by metis_tac [static_seq] >>
       first_x_assum (qspecl_then [`mc2`, `ffi`, `ms2`, `r`, `ms'`, `ffi'`] mp_tac) >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
       qexists_tac `l` >> asm_rewrite_tac [] >> strip_tac >> res_tac >> metis_tac [RS])
   >- (`refund_static mc2 dm` by metis_tac [static_seq] >>
       first_x_assum (qspecl_then [`mc2`, `ffi2`, `ms2`, `r`, `ms'`, `ffi'`] mp_tac) >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
       qexists_tac `IO_event (ExtCall nm) c b :: l` >> rpt conj_tac
       >- (asm_rewrite_tac [] >> simp [] >> show_tac "MAIN-APP")
       >- (asm_simp_tac (srw_ss()) [rev_def] >> fs [] >> show_tac "MAIN-EVERY")
       >- (simp [wev_def] >> strip_tac
           >- (rveq >> fs [] >> metis_tac [R0])
           >- (res_tac >> metis_tac [RS]))));
val T1 = thm "terminating_trace_with_write_event_reaches_write_call"
  ``refund_static ^mc dm /\ machine_sem mc (ffi:'ffi ffi_state) ms (Terminate t io) /\ ffi.io_events = [] ==>
    EVERY refund_event io /\ (EXISTS write_event io ==> ^reach_tm)``
  (simp [machine_sem_def] >> strip_tac >>
   qspecl_then [`k`, `mc`, `ffi`, `ms`, `Halt t`, `ms'`, `st'`] mp_tac MAIN >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
   gvs [] >> show_tac "T1");
(* ---- 4. The file-system replay: events other than write keep every inode. ---- *)
val fr_tac = gvs [AllCaseEqs(), OPTION_CHOICE_EQUALS_OPTION] >> rpt (pairarg_tac >> gvs []) >>
             gvs [read_def, openFile_def, closeFD_def, bumpFD_def, AllCaseEqs()] >> rpt (pairarg_tac >> gvs []);
val FRr = thm "ffi_read_keeps_inodes" ``ffi_read c b fs = SOME (FFIreturn b' fs') ==> fs'.inode_tbl = fs.inode_tbl``
  (rw [ffi_read_def] >> fr_tac >> show_tac "FRr");
val FRo = thm "ffi_open_in_keeps_inodes" ``ffi_open_in c b fs = SOME (FFIreturn b' fs') ==> fs'.inode_tbl = fs.inode_tbl``
  (rw [ffi_open_in_def] >> fr_tac >> show_tac "FRo");
val FRc = thm "ffi_close_keeps_inodes" ``ffi_close c b fs = SOME (FFIreturn b' fs') ==> fs'.inode_tbl = fs.inode_tbl``
  (rw [ffi_close_def] >> fr_tac >> show_tac "FRc");
val F1 = thm "replay_without_write_event_keeps_inodes"
  ``!l st st'. extract_fs_with_numchars ext st l = SOME st' /\ EVERY refund_event l /\ ~EXISTS write_event l ==>
               (SND st').inode_tbl = (SND st).inode_tbl``
  (Induct >- simp [extract_fs_with_numchars_def] >>
   rpt gen_tac >> simp [rev_def, wev_def] >> strip_tac >> rveq >> fs [] >> rveq >> fs [] >>
   qpat_x_assum `extract_fs_with_numchars _ _ _ = _` mp_tac >>
   simp [extract_fs_with_numchars_def, fs_ffi_part_def] >> rpt (CASE_TAC >> simp []) >> strip_tac >>
   first_x_assum drule >> simp [] >> strip_tac >>
   imp_res_tac FRr >> imp_res_tac FRo >> imp_res_tac FRc >> fs [] >> show_tac "F1");
val F3 = thm "add_stdout_changes_inodes"
  ``STD_streams fs /\ (add_stdout (fastForwardFD fs 0) out).inode_tbl = fs.inode_tbl ==> out = «»``
  (strip_tac >> `STD_streams (fastForwardFD fs 0)` by simp [STD_streams_fastForwardFD] >>
   `?init. stdout (fastForwardFD fs 0) init` by metis_tac [STD_streams_stdout] >>
   `stdout (add_stdout (fastForwardFD fs 0) out) (strcat init out)` by metis_tac [stdo_add_stdo] >>
   fs [stdo_def] >> rfs [] >>
   Cases_on `init` >> Cases_on `out` >> fs [strcat_thm, implode_def] >> show_tac "F3");
val F2 = thm "nonempty_output_needs_write_event"
  ``extract_fs ext (cl, fs) io = SOME (add_stdout (fastForwardFD fs 0) out) /\ STD_streams fs /\ EVERY refund_event io /\ out <> «» ==>
    EXISTS write_event io``
  (rpt strip_tac >> CCONTR_TAC >> fs [extract_fs_def] >> drule F1 >> simp [] >> strip_tac >>
   `(add_stdout (fastForwardFD fs 0) out).inode_tbl = fs.inode_tbl` by
      (qpat_x_assum `_ = add_stdout _ _` (SUBST1_TAC o SYM) >> fs [] >> show_tac "F2-a") >>
   metis_tac [F3]);
(* ---- 5. Model machine with the basis oracle: a terminating run with non-empty output reaches the write call. ---- *)
val bty = type_of ``basis_ffi ext cl fs``;
val T2 = thm "run_with_output_reaches_write_call"
  ``refund_static ^mc dm /\ machine_sem mc (basis_ffi ext cl fs) ms (Terminate t io) /\
    extract_fs ext (cl, fs) io = SOME (add_stdout (fastForwardFD fs 0) out) /\ STD_streams fs /\ out <> «» ==>
    EXISTS write_event io /\
    ?mc1 ffi1 ms1. machine_reach mc (basis_ffi ext cl fs) ms mc1 ffi1 ms1 /\ ms1.PC = 0x100004090w``
  (strip_tac >> `(basis_ffi ext cl fs).io_events = []` by simp [basis_ffi_def] >>
   drule_all T1 >> strip_tac >> `EXISTS write_event io` by metis_tac [F2] >> fs []);
(* ---- 6. Controls and the converse direction. ---- *)
val K1 = opt "no_step_no_event" ``targetSem$evaluate ^mc (ffi:'ffi ffi_state) 0 ms = (TimeOut, ms, ffi)`` (simp [Once evaluate_def]);
val K2 = opt "other_events_are_not_write_events"
  ``~write_event (IO_event (ExtCall «read») c b) /\ ~write_event (IO_event (ExtCall «close») c b) /\
    ~write_event (IO_event (ExtCall «open_in») c b) /\ ~write_event (IO_event (SharedMem op) c b) /\ ~EXISTS write_event []``
  (simp [wev_def]);
val K3 = opt "trace_without_write_event_gives_no_call_state_claim"
  ``~EXISTS write_event l ==> (EXISTS write_event l ==> P) `` (simp []);
val PROD = opt "write_call_step_appends_write_event"
  ``refund_static ^mc dm /\ ms.PC = 0x100004090w /\ read_ffi_bytearrays mc ms = (SOME cb, SOME ab) /\
    call_FFI (ffi:'ffi ffi_state) (ExtCall «write») cb ab = FFI_return new_ffi nb ==>
    ?ms2. targetSem$evaluate mc ffi 1 ms = (TimeOut, ms2, new_ffi) /\
          new_ffi.io_events = ffi.io_events ++ [IO_event (ExtCall «write») cb (ZIP (ab, nb))]``
  (strip_tac >> `new_ffi.io_events = ffi.io_events ++ [IO_event (ExtCall «write») cb (ZIP (ab, nb))]` by (match_mp_tac CF >> asm_rewrite_tac [] >> EVAL_TAC) >>
   fs [static_def] >> simp [Once evaluate_def, tg, find_index_def, apply_oracle_def] >> simp [Once evaluate_def] >> show_tac "PROD");
val _ = pr ("OPTIONAL_FAILED " ^ String.concatWith " " (rev (!optfailed)));
val _ = if null (!failed) andalso null (!optfailed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed) @ rev (!optfailed)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundWriteReach");
val closure = "forge_refundWriteReach" :: Theory.ancestry "forge_refundWriteReach";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
