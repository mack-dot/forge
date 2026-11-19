(* routeA-L2b.sml: worker A8 (Night-Shift Orchestrator A). Route A, lemma L2b. NOT RUN. Every tactic here is UNCHECKED.
   Statement under test (proposed by an earlier worker; never attempted before):
     ffi_calls_ok_of_returning_calls:
       !P k mc ffi ms. (!i. i < LENGTH mc.ffi_entry_pcs ==> ?nm. EL i mc.ffi_names = ExtCall nm) /\
         (!ffi1 ms1 i c ab ffi2 nb. ffi1.oracle = ffi.oracle /\ i < LENGTH mc.ffi_entry_pcs /\
            read_ffi_bytearrays mc ms1 = (SOME c, SOME ab) /\
            call_FFI ffi1 (EL i mc.ffi_names) c ab = FFI_return ffi2 nb ==> P i nb ms1)
         ==> ffi_calls_ok P mc ffi k ms
   A8 statement notes (old text = the proposal; nothing weakened):
     (a) P was free in the proposal; here it is universally quantified (same theorem after GEN).
     (b) The close instance as proposed, `ffi_calls_ok (\i nb ms. i = 2 ==> ms.REG 1w = 8w /\ ms.REG 3w <> 0w) mc ffi k ms`,
         is FALSE without premises (control N2' below: an oracle that returns at alen = 0). It is stated here with the
         premises target = arm8_target, len_reg = 1, len2_reg = 3, all names ExtCall, EL 2 names = close, and
         ffi.oracle = basis_ffi_oracle ext (generic: close_returning_calls_have_valid_lengths), and for the refund record
         with only the oracle premise (refund_ffi_calls_ok_close, refund_ffi_calls_ok_close_totalised).
     (c) D3 (ffi_calls_ok): L2-0001 ran on 2026-11-19 with actual exit 1 (LEMMA_FAILED refund_ffi_tot_evaluate_agree,
         refund_ffi_tot_machine_sem_agree, refund_profile_a_sl_reach); theory forge_refundRouteA2 was NOT exported.
         So this script imports ffi_calls_ok_def from forge_refundRouteA2 when that theory is loaded, and otherwise
         defines it here with the VERBATIM text of L2-0001.sml lines 74-113 (sha256 4e1c1542...a88e). The line
         D3_SOURCE says which. With the local definition, the theorems are about forge_refundRouteA2b$ffi_calls_ok
         and must be re-run against forge_refundRouteA2 once an L2 attempt exports it.
   Read facts used (file:line, by reading only):
     targetSemScript.sml 118-220 evaluate_def; 60-73 read_ffi_bytearray(s) (conf length = w2n (get_reg len_reg),
     array length = w2n (get_reg len2_reg)); ffiScript.sml 64-80 call_FFI_def (FFI_return keeps st.oracle);
     arm8_targetScript.sml 371-381 (get_reg s n = s.REG (n2w n)); fsFFIScript.sml 351-362 ffi_close_def;
     basis_ffiScript.sml 19-59 basis_ffi_oracle_def, 94-99 basis_ffi_def; miscScript.sml 122 read_bytearray_LENGTH,
     939 find_index_LESS_LENGTH; stored refund_mc_register_fields_sl (forge_refundSlideProfileA): len_reg 1, len2_reg 3;
     stored refund_ffi_names_list (forge_refundEnvModel): [read; write; close; open_in].
   NOT proved here: the valid-call predicate Vok for read, write, open_in; the signed bound (word_msb) for close;
   anything about the program's behaviour (L3); anything native. Those are STATEMENTS only (section R below). *)
open preamble targetSemTheory targetPropsTheory ffiTheory semanticsPropsTheory fsFFITheory basis_ffiTheory TextIOProofTheory
     backendTheory asmPropsTheory lab_to_targetTheory arm8Theory arm8_targetTheory alignmentTheory miscTheory set_sepTheory
     backendProofTheory arm8_configProofTheory wordsLib blastLib forge_refundArm8CompileTheory forge_refundExclusionRealTheory
     forge_refundStartupClauseTheory forge_refundStartupBridgeTheory forge_refundInstalledDomainsTheory forge_refundInstalledAssemblyTheory
     forge_refundFfiFactsTheory forge_refundResidualTheory forge_refundEnvModelTheory forge_refundSourceNonFailTheory
     forge_refundProfileATheory forge_refundSlideEntryTheory forge_refundSlideDomainsTheory forge_refundSlideInstalledTheory
     forge_refundSlideSatTheory forge_refundSlideProfileATheory forge_refundRouteA1Theory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundRouteA2b";
val failed = ref ([] : string list);
val problems = ref ([] : string list);
val stmt_bad = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun has_const n tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;
(* Ordered list of tactics for ONE fixed goal; the goal never changes between attempts. No mk_thm. *)
fun tryall name goal tacs =
  let fun go _ [] = raise Fail "all listed tactics failed"
        | go i (t :: ts) =
            (let val th = Tactical.TAC_PROOF (([], goal), t) in pr ("TACTIC_USED " ^ name ^ " " ^ Int.toString i); th end
             handle e => (pr ("TACTIC_ATTEMPT_FAILED " ^ name ^ " " ^ Int.toString i ^ " " ^ General.exnMessage e); go (i + 1) ts))
  in go 1 tacs end;
fun thmA name goal tacs = (let val th = save_thm (name, tryall name goal tacs) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
(* OPTIONAL: a failure is printed as OPTIONAL_FAILED and does not stop the export. *)
fun thmO name goal tacs = (let val th = save_thm (name, tryall name goal tacs) in chk name th; SOME th end)
  handle e => (pr ("OPTIONAL_FAILED " ^ name ^ " " ^ General.exnMessage e); NONE);
(* STATEMENT ONLY: parse and type check; nothing is proved. A failure is printed and counted; it does not stop the export. *)
fun stmt name (f : unit -> term) =
  (let val t = f () in
     if type_of t = bool then (pr ("STATEMENT_TYPECHECKS " ^ name ^ "\n" ^ term_to_string t); SOME t)
     else (pr ("STATEMENT_NOT_BOOL " ^ name); stmt_bad := name :: !stmt_bad; NONE) end)
  handle e => (pr ("STATEMENT_PARSE_FAILED " ^ name ^ " " ^ General.exnMessage e); stmt_bad := name :: !stmt_bad; NONE);
fun A1 n = DB.fetch "forge_refundRouteA1" n;
val L1C = A1 "refund_env_ok_sl_of_contract_on";
val TA = DB.fetch "forge_refundSlideProfileA" "refund_profile_a_sl";
val mc_def = DB.fetch "forge_refundStartupBridge" "refund_mc_def";
val fix_def = DB.fetch "forge_refundStartupClause" "arm8_fix_def";
val NM = DB.fetch "forge_refundEnvModel" "refund_ffi_names_list";
(* ================= D3 ================= *)
val _ = pr "MARK D3";
fun d3_local () = Define `
  (ffi_calls_ok (P:num -> word8 list -> 'b -> bool) (mc:('a,'b,'c) machine_config) (ffi:'ffi ffi_state) 0 (ms:'b) <=> T) /\
  (ffi_calls_ok P mc ffi (SUC k) ms <=>
     if mc.target.get_pc ms IN (mc.prog_addresses DIFF (set mc.ffi_entry_pcs)) then
       if encoded_bytes_in_mem mc.target.config (mc.target.get_pc ms) (mc.target.get_byte ms) mc.prog_addresses then
         let ms1 = mc.target.next ms in
         let (ms2,new_oracle) = apply_oracle mc.next_interfer ms1 in
         let mc = mc with next_interfer := new_oracle in
           if EVERY mc.target.state_ok [ms;ms1;ms2] /\
              (!x. x NOTIN mc.prog_addresses ==> mc.target.get_byte ms1 x = mc.target.get_byte ms x)
           then ffi_calls_ok P mc ffi k ms2
           else T
       else T
     else if mc.target.get_pc ms = mc.halt_pc then T
     else if mc.target.get_pc ms = mc.install_pc then
       (case read_ffi_bytearray mc mc.ptr_reg mc.len_reg ms of
        | SOME bytes =>
            let (ms1,new_oracle) = apply_oracle mc.install_interfer (bytes,ms) in
            let mc = mc with install_interfer := new_oracle in
              ffi_calls_ok P mc ffi k ms1
        | _ => T)
     else
       case find_index (mc.target.get_pc ms) mc.ffi_entry_pcs 0 of
       | NONE => T
       | SOME ffi_index =>
           (case EL ffi_index mc.ffi_names of
            | SharedMem op => F
            | ExtCall _ =>
                (case ALOOKUP mc.mmio_info ffi_index of
                 | SOME _ => T
                 | NONE =>
                     (case read_ffi_bytearrays mc ms of
                      | (SOME bytes, SOME bytes2) =>
                          (case call_FFI ffi (EL ffi_index mc.ffi_names) bytes bytes2 of
                           | FFI_final outcome => T
                           | FFI_return new_ffi new_bytes =>
                               P ffi_index new_bytes ms /\
                               (let (ms1,new_oracle) = apply_oracle mc.ffi_interfer (ffi_index,new_bytes,ms) in
                                let mc = mc with ffi_interfer := new_oracle in
                                  ffi_calls_ok P mc new_ffi k ms1))
                      | _ => T))))`;
val calls_def =
  (let val th = DB.fetch "forge_refundRouteA2" "ffi_calls_ok_def"
   in pr "D3_SOURCE imported forge_refundRouteA2.ffi_calls_ok_def"; th end)
  handle _ => (pr "D3_SOURCE local (verbatim L2-0001.sml lines 74-113; forge_refundRouteA2 not loaded)"; d3_local ());
val _ = pr ("DEFINITION " ^ thm_to_string calls_def);
(* ================= helpers ================= *)
val _ = pr "MARK H";
val RFBN = thm "rfb2_next_interfer_update"
  ``!(mc:('a,'b,'c) machine_config) g ms. read_ffi_bytearrays (mc with next_interfer := g) ms = read_ffi_bytearrays mc ms``
  (simp [read_ffi_bytearrays_def, read_ffi_bytearray_def]);
val RFBI = thm "rfb2_install_interfer_update"
  ``!(mc:('a,'b,'c) machine_config) g ms. read_ffi_bytearrays (mc with install_interfer := g) ms = read_ffi_bytearrays mc ms``
  (simp [read_ffi_bytearrays_def, read_ffi_bytearray_def]);
val RFBF = thm "rfb2_ffi_interfer_update"
  ``!(mc:('a,'b,'c) machine_config) g ms. read_ffi_bytearrays (mc with ffi_interfer := g) ms = read_ffi_bytearrays mc ms``
  (simp [read_ffi_bytearrays_def, read_ffi_bytearray_def]);
val CALLO = thmA "call_FFI_return_keeps_oracle"
  ``!(st:'ffi ffi_state) s c b st' b'. call_FFI st s c b = FFI_return st' b' ==> st'.oracle = st.oracle``
  [(rw [call_FFI_def] >> every_case_tac >> fs [] >> rw []),
   (rw [call_FFI_def] >> gvs [AllCaseEqs()]),
   (rpt gen_tac >> simp [call_FFI_def] >> rpt (TOP_CASE_TAC >> simp []) >> rw [] >> simp [])];
(* ================= G: the general lemma ================= *)
val _ = pr "MARK G";
val G_goal =
  ``!P k (mc:('a,'b,'c) machine_config) (ffi:'ffi ffi_state) (ms:'b).
      (!i. i < LENGTH mc.ffi_entry_pcs ==> ?nm. EL i mc.ffi_names = ExtCall nm) /\
      (!ffi1 ms1 i c ab ffi2 nb. ffi1.oracle = ffi.oracle /\ i < LENGTH mc.ffi_entry_pcs /\
         read_ffi_bytearrays mc ms1 = (SOME c, SOME ab) /\
         call_FFI ffi1 (EL i mc.ffi_names) c ab = FFI_return ffi2 nb ==> P i nb ms1) ==>
      ffi_calls_ok P mc ffi k ms``;
(* Leaf finisher. Leaves (by the L2-0001 SHOW output of the same unfolding): (1) goal F at SharedMem, closed by premise 1
   and find_index_LESS_LENGTH; (2) a recursive ffi_calls_ok with mc updated in one interference field (and new_ffi
   after a returning call), closed by IH, RFB*, CALLO; (3) P ffi_index new_bytes ms, closed by premise 2 with ffi1 = ffi. *)
fun leafG IH =
  rpt strip_tac >>
  TRY (imp_res_tac find_index_LESS_LENGTH) >>
  TRY (imp_res_tac CALLO) >>
  fs [RFBN, RFBI, RFBF] >>
  FIRST [(res_tac >> fs [] >> NO_TAC),
         (match_mp_tac IH >> simp [RFBN, RFBI, RFBF] >> metis_tac []),
         (first_x_assum match_mp_tac >> metis_tac []),
         (show_tac "G-leaf" >> NO_TAC)];
val G = thmA "ffi_calls_ok_of_returning_calls" G_goal
  [(* 1: the unfolding of L2-0001 tactic 1 (it reached its leaves in that run), then leafG *)
   (gen_tac >> Induct
    >- simp [calls_def]
    >> pop_assum (fn IH =>
         rpt gen_tac >> strip_tac >>
         once_rewrite_tac [calls_def] >>
         simp [apply_oracle_def, RFBN, RFBI, RFBF] >>
         rpt (IF_CASES_TAC >> simp [RFBN, RFBI, RFBF]) >>
         rpt (TOP_CASE_TAC >> simp [RFBN, RFBI, RFBF]) >>
         rpt strip_tac >> every_case_tac >> fs [] >>
         leafG IH)),
   (* 2: every_case_tac variant (the unfolding of L2-0001 tactic 2) *)
   (gen_tac >> Induct
    >- simp [calls_def]
    >> pop_assum (fn IH =>
         rpt gen_tac >> strip_tac >>
         once_rewrite_tac [calls_def] >>
         simp_tac (srw_ss()) [apply_oracle_def, LET_THM, RFBN, RFBI, RFBF] >>
         every_case_tac >> fs [] >> rpt strip_tac >> fs [] >>
         leafG IH)),
   (* 3: rw variant *)
   (gen_tac >> Induct
    >- simp [calls_def]
    >> pop_assum (fn IH =>
         rpt gen_tac >> strip_tac >>
         once_rewrite_tac [calls_def] >>
         rw [apply_oracle_def] >> every_case_tac >> gvs [] >>
         leafG IH))];
val _ = pr ("STATEMENT_G " ^ term_to_string (concl G));
(* ================= the close instance ================= *)
val _ = pr "MARK CLOSE";
val CLOSE_LEN = thmA "ffi_close_return_lengths"
  ``!c ab fsys nb fsys'. ffi_close c ab fsys = SOME (FFIreturn nb fsys') ==> LENGTH c = 8 /\ 1 <= LENGTH ab``
  [(rw [ffi_close_def] >> gvs [OPTION_CHOICE_EQUALS_OPTION] >> rpt (pairarg_tac >> gvs [])),
   (fn g => metis_tac [GEN_ALL (DB.fetch "forge_refundFficloseCompose" "ffi_close_accepts_only_valid_lengths")] g),
   (rw [ffi_close_def] >> fs [option_eq_some] >> TRY pairarg_tac >> fs [] >> rw [])];
val CLOSE_RET = thmA "basis_close_return_lengths"
  ``!ext (st:(mlstring list # IO_fs) ffi_state) c ab st' nb.
      st.oracle = basis_ffi_oracle ext /\ call_FFI st (ExtCall «close») c ab = FFI_return st' nb ==>
      LENGTH c = 8 /\ 1 <= LENGTH ab``
  [(rpt gen_tac >> strip_tac >> fs [call_FFI_def] >> Cases_on `st.ffi_state` >> fs [basis_ffi_oracle_def] >>
    every_case_tac >> fs [] >> imp_res_tac CLOSE_LEN >> fs []),
   (rpt gen_tac >> strip_tac >> fs [call_FFI_def, basis_ffi_oracle_def, pairTheory.UNCURRY] >>
    every_case_tac >> fs [] >> imp_res_tac CLOSE_LEN >> fs []),
   (rpt gen_tac >> strip_tac >> gvs [call_FFI_def, basis_ffi_oracle_def, pairTheory.UNCURRY, AllCaseEqs()] >>
    imp_res_tac CLOSE_LEN >> fs [])];
val closeP = ``\i (nb:word8 list) (s:arm8_state). i = 2 ==> s.REG 1w = 8w /\ s.REG 3w <> 0w``;
val CLOSE_OK_goal =
  ``!ext k mc (ffi:(mlstring list # IO_fs) ffi_state) ms.
      mc.target = arm8_target /\ mc.len_reg = 1 /\ mc.len2_reg = 3 /\
      (!i. i < LENGTH mc.ffi_entry_pcs ==> ?nm. EL i mc.ffi_names = ExtCall nm) /\
      EL 2 mc.ffi_names = ExtCall «close» /\ ffi.oracle = basis_ffi_oracle ext ==>
      ffi_calls_ok ^closeP mc ffi k ms``;
fun close_regs_tac (g as (asl, w)) =
  (`LENGTH c = 8 /\ 1 <= LENGTH ab` by metis_tac [CLOSE_RET] >>
   fs [read_ffi_bytearrays_def, read_ffi_bytearray_def, arm8_target_def] >>
   imp_res_tac read_bytearray_LENGTH >> fs [] >>
   conj_tac
   >- (FIRST [metis_tac [wordsTheory.n2w_w2n],
              (`ms1.REG 1w = n2w (w2n (ms1.REG 1w))` by simp [] >> pop_assum SUBST1_TAC >> simp [])])
   >> FIRST [(strip_tac >> fs []),
             metis_tac [wordsTheory.w2n_eq_0, DECIDE ``~(1 <= 0n)``]]) g;
val CLOSE_OK = thmA "close_returning_calls_have_valid_lengths" CLOSE_OK_goal
  [(rpt gen_tac >> strip_tac >> match_mp_tac G >> conj_tac >- first_assum ACCEPT_TAC >>
    rpt gen_tac >> strip_tac >> simp [] >> strip_tac >> rveq >> fs [] >> close_regs_tac),
   (rpt gen_tac >> strip_tac >> irule G >> conj_tac >- metis_tac [] >>
    rpt gen_tac >> strip_tac >> BETA_TAC >> strip_tac >> rveq >> rfs [] >> close_regs_tac)];
(* ================= the refund record ================= *)
val _ = pr "MARK REFUND";
val EXT3 = thmA "three_names_are_ExtCall"
  ``!i. i < 3 ==> ?nm. EL i [ExtCall «read»; ExtCall «write»; ExtCall «close»] = ExtCall nm``
  [(rpt strip_tac >> `EVERY (\x. ?nm. x = ExtCall nm) [ExtCall «read»; ExtCall «write»; ExtCall «close»]` by simp [] >>
    fs [listTheory.EVERY_EL]),
   (rpt strip_tac >> `i = 0 \/ i = 1 \/ i = 2` by decide_tac >> pop_assum (REPEAT_TCL DISJ_CASES_THEN SUBST1_TAC) >>
    simp [rich_listTheory.EL_CONS, listTheory.EL]),
   (Cases >> simp [] >> Cases_on `n` >> simp [] >> Cases_on `n'` >> simp [])];
val EXT4 = thmA "refund_names_are_ExtCall"
  ``!i. i < 4 ==> ?nm. EL i [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»] = ExtCall nm``
  [(rpt strip_tac >>
    `EVERY (\x. ?nm. x = ExtCall nm) [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»]` by simp [] >>
    fs [listTheory.EVERY_EL]),
   (rpt strip_tac >> `i = 0 \/ i = 1 \/ i = 2 \/ i = 3` by decide_tac >>
    pop_assum (REPEAT_TCL DISJ_CASES_THEN SUBST1_TAC) >> simp [rich_listTheory.EL_CONS, listTheory.EL])];
val RMF = thmA "refund_mc_close_fields"
  ``!b envmc. (refund_mc b envmc).target = arm8_target /\ (refund_mc b envmc).len_reg = 1 /\
              (refund_mc b envmc).len2_reg = 3 /\
              (refund_mc b envmc).ffi_names = [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»] /\
              LENGTH (refund_mc b envmc).ffi_entry_pcs = 4``
  [(simp [mc_def, fix_def, NM]),
   (simp [mc_def, fix_def, NM, listTheory.LENGTH_GENLIST] >> TRY EVAL_TAC)];
val RC = thmA "refund_ffi_calls_ok_close"
  ``!b envmc ext ffi k ms. ffi.oracle = basis_ffi_oracle ext ==> ffi_calls_ok ^closeP (refund_mc b envmc) ffi k ms``
  [(rpt strip_tac >> match_mp_tac CLOSE_OK >> qexists_tac `ext` >> fs [RMF, EXT4] >> TRY EVAL_TAC),
   (rpt strip_tac >> irule CLOSE_OK >> qexists_tac `ext` >> rpt conj_tac >> fs [RMF, EXT4] >> EVAL_TAC)];
val RCT = thmA "refund_ffi_calls_ok_close_totalised"
  ``!sl envmc Vok ext cl fs k ms.
      ffi_calls_ok ^closeP (refund_mc (sl + 0x1000040D0w) (envmc with ffi_interfer := refund_ffi_tot Vok envmc.ffi_interfer))
                   (basis_ffi ext cl fs) k ms``
  [(rpt gen_tac >> match_mp_tac RC >> qexists_tac `ext` >> simp [basis_ffi_def]),
   (rpt gen_tac >> irule RC >> qexists_tac `ext` >> simp [basis_ffi_def])];
(* ================= controls ================= *)
val _ = pr "MARK CONTROLS";
(* NV-A (non-vacuity of the premises): every premise of close_returning_calls_have_valid_lengths holds for the refund
   record and the basis oracle record, for all b envmc ext cl fs. *)
val NVA = thmA "refund_close_premises_hold"
  ``!b envmc ext cl fs.
      (basis_ffi ext cl fs).oracle = basis_ffi_oracle ext /\ (refund_mc b envmc).target = arm8_target /\
      (refund_mc b envmc).len_reg = 1 /\ (refund_mc b envmc).len2_reg = 3 /\
      (!i. i < LENGTH (refund_mc b envmc).ffi_entry_pcs ==> ?nm. EL i (refund_mc b envmc).ffi_names = ExtCall nm) /\
      EL 2 (refund_mc b envmc).ffi_names = ExtCall «close»``
  [(rpt gen_tac >> simp [basis_ffi_def, RMF, EXT4] >> TRY EVAL_TAC),
   (rpt gen_tac >> rpt conj_tac >> simp [basis_ffi_def, RMF, EXT4] >> EVAL_TAC)];
(* Concrete records. The pc 0w is the third FFI entry (index 2, name close); x1 = 8; conf at 0w; array at 0w. *)
val MCB = ``<| prog_addresses := UNIV; shared_addresses := {}; ffi_entry_pcs := [16w; 32w; 0w];
               ffi_names := [ExtCall «read»; ExtCall «write»; ExtCall «close»];
               ptr_reg := 0; len_reg := 1; ptr2_reg := 2; len2_reg := 3; ffi_interfer := ARB; callee_saved_regs := [];
               next_interfer := ARB; halt_pc := 4w; install_pc := 8w; install_interfer := ARB; target := arm8_target;
               mmio_info := [] |>``;
val FSB = ``<| inode_tbl := []; files := []; infds := []; numchars := LNIL; maxFD := 0 |> : IO_fs``;
val FFIB = ``basis_ffi no_ext [] ^FSB``;
val MSB = ``(ARB:arm8_state) with <| PC := 0w; REG := (\r. if r = 1w then 8w else if r = 3w then 1w else 0w);
                                     MEM := (\a. 0w) |>``;
val MSZ = ``(ARB:arm8_state) with <| PC := 0w; REG := (\r. if r = 1w then 8w else 0w); MEM := (\a. 0w) |>``;
val FFIR = ``<| oracle := (\s st c b. Oracle_return st b); ffi_state := (); io_events := [] |> : unit ffi_state``;
val Pne2 = ``\i (nb:word8 list) (s:arm8_state). i <> 2``;
val conc_tacs =
  [(simp [calls_def, arm8_target_def, find_index_def, read_ffi_bytearrays_def, read_ffi_bytearray_def,
          read_bytearray_def, call_FFI_def] >> TRY EVAL_TAC),
   (rewrite_tac [calls_def] >> EVAL_TAC),
   (simp [calls_def, arm8_target_def, find_index_def, read_ffi_bytearrays_def, read_ffi_bytearray_def, call_FFI_def,
          basis_ffi_def, basis_ffi_oracle_def, ffi_close_def, closeFD_def] >> EVAL_TAC)];
(* NV-B (non-vacuity of the checked call): under the basis oracle a close call with x1 = 8, x3 = 1 RETURNS (closeFD fails on
   the empty fd table; ffi_close answers 1w), so ffi_calls_ok really evaluates its predicate at index 2. *)
val NVB = thmA "basis_close_call_returns_at_a_concrete_state"
  ``~ffi_calls_ok ^Pne2 ^MCB ^FFIB (SUC 0) ^MSB`` conc_tacs;
(* N2 (negative): under an oracle that always returns, a close call with x3 = 0 returns and the close predicate fails. *)
val NZ = thmA "close_predicate_fails_for_a_returning_zero_length_call"
  ``~ffi_calls_ok ^closeP ^MCB ^FFIR (SUC 0) ^MSZ`` conc_tacs;
(* N1 (negative): without the returning-call premise, the conclusion of G fails (P = (\i nb s. i <> 2), witness NV-B). *)
val mcv = mk_var ("mc", type_of MCB);
val ffiBv = mk_var ("ffi", type_of FFIB);
val msv = mk_var ("ms", ``:arm8_state``);
val Pv = mk_var ("P", type_of Pne2);
val N1 = thmA "returning_call_premise_is_needed"
  ``~!^Pv k ^mcv ^ffiBv ^msv. (!i. i < LENGTH (^mcv).ffi_entry_pcs ==> ?nm. EL i (^mcv).ffi_names = ExtCall nm) ==>
                             ffi_calls_ok ^Pv ^mcv ^ffiBv k ^msv``
  [(strip_tac >> first_x_assum (mp_tac o SPECL [Pne2, ``SUC 0``, MCB, FFIB, MSB]) >>
    impl_tac >- (simp [EXT3] >> TRY EVAL_TAC) >>
    FIRST [rewrite_tac [NVB], metis_tac [NVB]]),
   (CCONTR_TAC >> fs [] >> mp_tac NVB >> simp [] >> first_x_assum match_mp_tac >> simp [EXT3])];
(* N2' (negative): the oracle premise of close_returning_calls_have_valid_lengths cannot be dropped. *)
val ffiRv = mk_var ("ffi", type_of FFIR);
val N2' = thmA "close_instance_needs_the_basis_oracle"
  ``~!^mcv ^ffiRv k ^msv. (^mcv).target = arm8_target /\ (^mcv).len_reg = 1 /\ (^mcv).len2_reg = 3 /\
                         (!i. i < LENGTH (^mcv).ffi_entry_pcs ==> ?nm. EL i (^mcv).ffi_names = ExtCall nm) /\
                         EL 2 (^mcv).ffi_names = ExtCall «close» ==> ffi_calls_ok ^closeP ^mcv ^ffiRv k ^msv``
  [(strip_tac >> first_x_assum (mp_tac o SPECL [MCB, FFIR, ``SUC 0``, MSZ]) >>
    impl_tac >- (simp [EXT3] >> TRY EVAL_TAC) >>
    FIRST [rewrite_tac [NZ], metis_tac [NZ]]),
   (CCONTR_TAC >> fs [] >> mp_tac NZ >> simp [] >> first_x_assum match_mp_tac >> simp [EXT3] >> EVAL_TAC)];
(* N3 (negative, structural): the close predicate rejects the zero-length state at index 2 and accepts index 0. *)
val N3 = thm "close_predicate_rejects_zero_alen"
  ``~(^closeP) 2 nb ^MSZ /\ (^closeP) 0 nb ^MSZ`` (simp [] >> TRY EVAL_TAC);
(* ================= OPTIONAL: monotonicity, conjunction, events bridge ================= *)
val _ = pr "MARK OPTIONAL";
fun split_tac IH = rpt (IF_CASES_TAC >> simp []) >> rpt (TOP_CASE_TAC >> simp []) >> rpt strip_tac >> fs [] >>
                   TRY (metis_tac [IH]);
val MONO = thmO "ffi_calls_ok_mono"
  ``!P Q k (mc:('a,'b,'c) machine_config) (ffi:'ffi ffi_state) (ms:'b).
      (!i nb s. P i nb s ==> Q i nb s) /\ ffi_calls_ok P mc ffi k ms ==> ffi_calls_ok Q mc ffi k ms``
  [(gen_tac >> gen_tac >> Induct >- simp [calls_def] >>
    pop_assum (fn IH => rpt gen_tac >> strip_tac >> pop_assum mp_tac >> once_rewrite_tac [calls_def] >>
                        simp [apply_oracle_def] >> split_tac IH)),
   (gen_tac >> gen_tac >> Induct >- simp [calls_def] >>
    pop_assum (fn IH => rpt gen_tac >> strip_tac >> pop_assum mp_tac >> once_rewrite_tac [calls_def] >>
                        simp_tac (srw_ss()) [apply_oracle_def, LET_THM] >> every_case_tac >> fs [] >> rpt strip_tac >>
                        fs [] >> metis_tac [IH]))];
val CONJ = thmO "ffi_calls_ok_conj"
  ``!P Q k (mc:('a,'b,'c) machine_config) (ffi:'ffi ffi_state) (ms:'b).
      ffi_calls_ok P mc ffi k ms /\ ffi_calls_ok Q mc ffi k ms ==>
      ffi_calls_ok (\i nb s. P i nb s /\ Q i nb s) mc ffi k ms``
  [(gen_tac >> gen_tac >> Induct >- simp [calls_def] >>
    pop_assum (fn IH => rpt gen_tac >> strip_tac >> rpt (qpat_x_assum `ffi_calls_ok _ _ _ _ _` mp_tac) >>
                        once_rewrite_tac [calls_def] >> simp [apply_oracle_def] >> split_tac IH)),
   (gen_tac >> gen_tac >> Induct >- simp [calls_def] >>
    pop_assum (fn IH => rpt gen_tac >> strip_tac >> rpt (qpat_x_assum `ffi_calls_ok _ _ _ _ _` mp_tac) >>
                        once_rewrite_tac [calls_def] >> simp_tac (srw_ss()) [apply_oracle_def, LET_THM] >>
                        every_case_tac >> fs [] >> rpt strip_tac >> fs [] >> metis_tac [IH]))];
val EV0 = thmO "evaluate_clock_zero"
  ``!(mc:('a,'b,'c) machine_config) (ffi:'ffi ffi_state) (ms:'b). evaluate mc ffi 0 ms = (TimeOut,ms,ffi)``
  [(simp [Once evaluate_def]), (rpt gen_tac >> once_rewrite_tac [evaluate_def] >> simp [])];
val CALLEV = thmO "call_FFI_return_appends_its_event"
  ``!(st:'ffi ffi_state) nm c ab st' nb. call_FFI st (ExtCall nm) c ab = FFI_return st' nb /\ nm <> «» ==>
      st'.io_events = st.io_events ++ [IO_event (ExtCall nm) c (ZIP (ab,nb))] /\ st'.oracle = st.oracle``
  [(rw [call_FFI_def] >> gvs [AllCaseEqs()]),
   (rw [call_FFI_def] >> every_case_tac >> fs [] >> rw [])];
val GEV_goal_opt = (SOME
  ``!P E k (mc:('a,'b,'c) machine_config) (ffi:'ffi ffi_state) (ms:'b).
      (!i. i < LENGTH mc.ffi_entry_pcs ==> ?nm. EL i mc.ffi_names = ExtCall nm /\ nm <> «») /\
      (!j. EVERY E (SND (SND (evaluate mc ffi j ms))).io_events) /\
      (!ffi1 ms1 i c ab ffi2 nb. ffi1.oracle = ffi.oracle /\ i < LENGTH mc.ffi_entry_pcs /\
         read_ffi_bytearrays mc ms1 = (SOME c, SOME ab) /\
         call_FFI ffi1 (EL i mc.ffi_names) c ab = FFI_return ffi2 nb /\
         E (IO_event (EL i mc.ffi_names) c (ZIP (ab,nb))) ==> P i nb ms1) ==>
      ffi_calls_ok P mc ffi k ms``)
  handle e => (pr ("STATEMENT_PARSE_FAILED GEV_goal " ^ General.exnMessage e); stmt_bad := "GEV_goal" :: !stmt_bad; NONE);
val GEV =
  case (EV0, CALLEV, GEV_goal_opt) of
    (SOME ev0, SOME callev, SOME GEV_goal) =>
      let fun leafE IH =
            rpt strip_tac >>
            TRY (imp_res_tac find_index_LESS_LENGTH) >> TRY (imp_res_tac CALLO) >>
            fs [RFBN, RFBI, RFBF] >>
            FIRST [(res_tac >> fs [] >> NO_TAC),
                   (match_mp_tac IH >> simp [RFBN, RFBI, RFBF] >> rpt conj_tac >> TRY (first_assum ACCEPT_TAC) >>
                    metis_tac []),
                   (rpt (qpat_x_assum `!j. EVERY E _` (assume_tac o SPEC ``0:num``)) >> fs [ev0] >>
                    res_tac >> fs [] >> imp_res_tac callev >> fs [listTheory.EVERY_APPEND] >> rfs [] >>
                    first_x_assum match_mp_tac >> metis_tac []),
                   (show_tac "GEV-leaf" >> NO_TAC)]
      in thmO "ffi_calls_ok_of_valid_events" GEV_goal
           [(gen_tac >> gen_tac >> Induct >- simp [calls_def] >>
             pop_assum (fn IH =>
               rpt gen_tac >> strip_tac >>
               qpat_assum `!j. EVERY E _` (fn EVA =>
                 assume_tac (GEN ``j:num`` (SIMP_RULE (srw_ss()) [Once evaluate_def, apply_oracle_def] (SPEC ``SUC j`` EVA)))) >>
               once_rewrite_tac [calls_def] >>
               simp [apply_oracle_def, RFBN, RFBI, RFBF] >>
               rpt strip_tac >> every_case_tac >> fs [RFBN, RFBI, RFBF] >> rpt strip_tac >>
               leafE IH))]
      end
  | _ => (pr "OPTIONAL_FAILED ffi_calls_ok_of_valid_events (helper missing)"; NONE);
(* Y3's event predicate (Y3-L3-analysis.md lines 79-82) without LENGTH nb = LENGTH ab. HOL ZIP truncates (listScript.sml
   1784-1790), so it admits a read event whose array has 2 bytes (the conclusion of the bridge would then be false). *)
val N4 = (let val EVweak = ``\e. (?ab nb. e = IO_event (ExtCall «read») (n2w8 0) (ZIP (ab,nb)) /\ LENGTH ab = 4100 /\
                            TAKE 2 ab = n2w2 4096 /\ HD nb = (0w:word8)) \/
                   (?ab nb. e = IO_event (ExtCall «write») (n2w8 1) (ZIP (ab,nb)) /\ LENGTH ab = 2052 /\
                            w22n [EL 0 ab; EL 1 ab] + w22n [EL 2 ab; EL 3 ab] <= 2048 /\ HD nb = (0w:word8))``
  in thmO "y3_event_predicate_admits_a_two_byte_read_array"
  ``(^EVweak) (IO_event (ExtCall «read») (n2w8 0) (ZIP (n2w2 4096, [0w;0w])))``
  [(CONV_TAC (DEPTH_CONV BETA_CONV) >> disj1_tac >>
    qexists_tac `n2w2 4096 ++ REPLICATE 4098 0w` >> qexists_tac `[0w;0w]` >> EVAL_TAC),
   (simp [] >> disj1_tac >> qexists_tac `n2w2 4096 ++ REPLICATE 4098 0w` >> qexists_tac `[0w;0w]` >>
    simp [MarshallingTheory.n2w2_def, listTheory.ZIP_def] >> EVAL_TAC)] end)
  handle e => (pr ("OPTIONAL_FAILED y3_event_predicate_admits_a_two_byte_read_array " ^ General.exnMessage e); NONE);
(* ================= R: what remains, as STATEMENTS ONLY (nothing below is proved) ================= *)
val _ = pr "MARK R";
val EVc = (``\e. (?ab nb. e = IO_event (ExtCall «read») (n2w8 0) (ZIP (ab,nb)) /\ LENGTH ab = 4100 /\ LENGTH nb = LENGTH ab /\
                         TAKE 2 ab = n2w2 4096 /\ HD nb = (0w:word8)) \/
                (?ab nb. e = IO_event (ExtCall «write») (n2w8 1) (ZIP (ab,nb)) /\ LENGTH ab = 2052 /\ LENGTH nb = LENGTH ab /\
                         w22n [EL 0 ab; EL 1 ab] + w22n [EL 2 ab; EL 3 ab] <= 2048 /\ HD nb = (0w:word8))``)
  handle e => (pr ("STATEMENT_PARSE_FAILED EVc " ^ General.exnMessage e); stmt_bad := "EVc" :: !stmt_bad; ``\e:io_event. F``);
val VokY3 = (
  ``\i (nb:word8 list) (s:arm8_state).
      (i = 0 ==> s.REG 1w = 8w /\ (!j. j < 8 ==> s.MEM (s.REG 0w + n2w j) = EL j (n2w8 0)) /\
                 w22n [s.MEM (s.REG 2w); s.MEM (s.REG 2w + 1w)] + 4 <= w2n (s.REG 3w) /\ ~word_msb (s.REG 3w)) /\
      (i = 1 ==> s.REG 1w = 8w /\ (!j. j < 8 ==> s.MEM (s.REG 0w + n2w j) = EL j (n2w8 1)) /\
                 w22n [s.MEM (s.REG 2w); s.MEM (s.REG 2w + 1w)] + w22n [s.MEM (s.REG 2w + 2w); s.MEM (s.REG 2w + 3w)] + 4
                   <= w2n (s.REG 3w) /\ ~word_msb (s.REG 3w)) /\
      (i = 2 ==> F) /\ (i = 3 ==> F)``)
  handle e => (pr ("STATEMENT_PARSE_FAILED VokY3 " ^ General.exnMessage e); stmt_bad := "VokY3" :: !stmt_bad;
               ``\i (nb:word8 list) (s:arm8_state). F``);
(* R1 ORACLE ALONE (provable like CLOSE_OK; read/write success layer and the >= 4 array bound at every returning call). *)
val _ = stmt "R1_rw_returning_calls_oracle_only" (fn () =>
  ``!ext k mc (ffi:(mlstring list # IO_fs) ffi_state) ms.
      mc.target = arm8_target /\ mc.len_reg = 1 /\ mc.len2_reg = 3 /\
      (!i. i < LENGTH mc.ffi_entry_pcs ==> ?nm. EL i mc.ffi_names = ExtCall nm) /\
      EL 0 mc.ffi_names = ExtCall «read» /\ EL 1 mc.ffi_names = ExtCall «write» /\ ffi.oracle = basis_ffi_oracle ext ==>
      ffi_calls_ok (\i nb (s:arm8_state). (i = 0 \/ i = 1) ==> 4 <= w2n (s.REG 3w) /\ (HD nb = 0w ==> s.REG 1w = 8w))
                   mc ffi k ms``);
(* R2 ORACLE ALONE: a returning open_in call has a non-empty array (NOT the C condition 9 <= alen; gap O-a). *)
val _ = stmt "R2_open_in_returning_calls_oracle_only" (fn () =>
  ``!ext k mc (ffi:(mlstring list # IO_fs) ffi_state) ms.
      mc.target = arm8_target /\ mc.len2_reg = 3 /\
      (!i. i < LENGTH mc.ffi_entry_pcs ==> ?nm. EL i mc.ffi_names = ExtCall nm) /\
      EL 3 mc.ffi_names = ExtCall «open_in» /\ ffi.oracle = basis_ffi_oracle ext ==>
      ffi_calls_ok (\i nb (s:arm8_state). i = 3 ==> s.REG 3w <> 0w) mc ffi k ms``);
(* R3 MACHINE RECORD ALONE (no oracle, no program): the signed bound from the size of the memory domain. *)
val _ = stmt "R3_signed_alen_from_domain_size" (fn () =>
  ``!mc (ms:arm8_state) c ab. mc.target = arm8_target /\ mc.len2_reg = 3 /\ FINITE mc.prog_addresses /\
       CARD mc.prog_addresses < 2 ** 63 /\ read_ffi_bytearrays mc ms = (SOME c, SOME ab) ==> ~word_msb (ms.REG 3w)``);
(* R4 BRIDGE (arrays alone; no oracle, no program): a returning call whose event satisfies EVc meets VokY3. *)
val _ = stmt "R4_valid_event_gives_Vok" (fn () =>
  ``!mc (ffi1:(mlstring list # IO_fs) ffi_state) ms1 i c ab ffi2 nb.
      mc.target = arm8_target /\ mc.ptr_reg = 0 /\ mc.len_reg = 1 /\ mc.ptr2_reg = 2 /\ mc.len2_reg = 3 /\
      mc.ffi_names = [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»] /\ i < 4 /\
      read_ffi_bytearrays mc ms1 = (SOME c, SOME ab) /\ call_FFI ffi1 (EL i mc.ffi_names) c ab = FFI_return ffi2 nb /\
      ^EVc (IO_event (EL i mc.ffi_names) c (ZIP (ab,nb))) ==> ^VokY3 i nb ms1``);
(* R5 BRIDGE (attempted above as OPTIONAL ffi_calls_ok_of_valid_events): events at every clock give ffi_calls_ok. *)
val _ = stmt "R5_events_give_ffi_calls_ok" (fn () => valOf GEV_goal_opt);
(* R6 PROGRAM BEHAVIOUR (L3; the hard part): under the stored premises of refund_profile_a_sl, every event of every
   finite run is a valid read or write event. Needs the source-level event invariant (route W-a'); NOT derivable from
   the stored extract_fs equation. Stated for a generic envmc; it is used with envmc := the totalised record. *)
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val envmc = mk_var ("envmc", mcty);
val B = ``sl + 0x1000040D0w:word64``;
val (ta_ante, ta_conc) = dest_imp (concl TA);
val _ = stmt "R6_refund_run_events_are_valid" (fn () =>
  ``^ta_ante ==>
    !ms k r ms' ffi'. forge_refundCmlMainStep$arm8_run 27 s = SOME ms /\
      evaluate (refund_mc ^B ^envmc) (basis_ffi ext cl fs) k ms = (r,ms',ffi') ==> EVERY ^EVc ffi'.io_events``);
(* R7 TARGET of L3 (the third premise of L2R, with Vok := VokY3). R6 (at envmc := envT, via L1C), R5, R4, RMF give it. *)
val okp = ``refund_env_ok_sl sl ^envmc``;
val _ = if List.exists (aconv okp) (strip_conj ta_ante) then pr "PREMISE_FOUND refund_env_ok_sl sl envmc"
        else pr "NOTE premise refund_env_ok_sl sl envmc not found (R7 not built)";
val _ = stmt "R7_L3_target_for_VokY3" (fn () =>
  let val envT = ``^envmc with ffi_interfer := refund_ffi_tot ^VokY3 (^envmc).ffi_interfer``
      val prems = List.concat (map (fn t => if aconv t okp then
            [``interference_ok (^envmc).next_interfer (arm8_target.proj (^envmc).prog_addresses)``,
             ``refund_ffi_contract_on ^B (^envmc).prog_addresses ^VokY3 (^envmc).ffi_interfer``]
            else [t]) (strip_conj ta_ante))
  in ``^(list_mk_conj prems) ==>
       !ms k. forge_refundCmlMainStep$arm8_run 27 s = SOME ms ==>
              ffi_calls_ok ^VokY3 (refund_mc ^B ^envT) (basis_ffi ext cl fs) k ms`` end);
val _ = stmt "as_proposed_with_free_P" (fn () =>
  ``!k mc ffi ms. (!i. i < LENGTH mc.ffi_entry_pcs ==> ?nm. EL i mc.ffi_names = ExtCall nm) /\
      (!ffi1 ms1 i c ab ffi2 nb. ffi1.oracle = ffi.oracle /\ i < LENGTH mc.ffi_entry_pcs /\
         read_ffi_bytearrays mc ms1 = (SOME c, SOME ab) /\
         call_FFI ffi1 (EL i mc.ffi_names) c ab = FFI_return ffi2 nb ==> P i nb ms1) ==> ffi_calls_ok P mc ffi k ms``);
(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = if aconv (concl G) G_goal then pr "CONTROL_OK G statement is the literal statement of this file" else bad "G-literal";
val _ = if not (has_const "basis_ffi_oracle" (concl G)) then pr "CONTROL_OK G does not mention the basis oracle" else bad "G-oracle";
val _ = if aconv (concl CLOSE_OK) CLOSE_OK_goal andalso not (has_const "word_msb" (concl CLOSE_OK))
        then pr "CONTROL_OK close instance is literal and does not claim the signed bound (word_msb)" else bad "CLOSE-scope";
val _ = if length (strip_conj (fst (dest_imp (snd (strip_forall (concl RC)))))) = 1
        then pr "CONTROL_OK refund close instance has the oracle equation as its only premise" else bad "RC-premises";
val _ = if List.all is_neg (map concl [NVB, NZ, N1, N2'])
        then pr "CONTROL_OK NV-B, N2, N1, N2' are negations" else bad "negations";
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = pr ("STATEMENTS_BAD " ^ Int.toString (length (!stmt_bad)) ^ " " ^ String.concatWith " " (rev (!stmt_bad)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundRouteA2b" @ DB.definitions "forge_refundRouteA2b");
val closure = "forge_refundRouteA2b" :: Theory.ancestry "forge_refundRouteA2b";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundRouteA2b")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundRouteA2b")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
