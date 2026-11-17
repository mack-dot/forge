(* U400 check: (1) a constructed model state and basis-oracle state where a write call succeeds, so the premises of
   successful_write_call_state_has_valid_arguments are satisfiable (NOT a refund execution, NOT a real execution);
   (2) exact-statement import of the main U400 theorems and of preserved U399 theorems; (3) scope controls. *)
open preamble targetSemTheory ffiTheory semanticsPropsTheory fsFFITheory basis_ffiTheory TextIOProofTheory MarshallingTheory llistTheory
     arm8Theory arm8_targetTheory forge_refundCallSiteTheory forge_refundFfiwriteSuccessTheory forge_refundWriteReachTheory forge_refundWriteArgsTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundWriteArgsCheck";
fun same a b = aconv a b;
fun has_const n tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;
fun A n = DB.fetch "forge_refundWriteArgs" n;
fun R n = DB.fetch "forge_refundWriteReach" n;
val static_def = DB.fetch "forge_refundCallSite" "refund_static_def";
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val mc = mk_var ("mc", mcty); val mc1 = mk_var ("mc1", mcty);
val names4 = ``[«read»; «write»; «close»; «open_in»]``;
val bty = type_of ``basis_ffi ext cl fs``;
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
(* ---- 1. Constructed state: the write call succeeds. ---- *)
val dmw = ``UNIV DIFF {0x100004080w:word64}``;
val mcw = ``(ARB:^(ty_antiq mcty)) with <| ffi_names := [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»];
     ffi_entry_pcs := [0x1000040A0w; 0x100004090w; 0x100004080w; 0x100004070w]; halt_pc := 0x1000040C0w; install_pc := 0x1000040B0w;
     mmio_info := []; prog_addresses := ^dmw; target := arm8_target; ptr_reg := 0; len_reg := 1; ptr2_reg := 2; len2_reg := 3 |>``;
val msw = ``(ARB:arm8_state) with <| PC := 0x100004090w; REG := (\r. if r = 1w then 8w else if r = 3w then 4w else 0w); MEM := K 0w |>``;
val fsw = ``<| inode_tbl := [(UStream «o», [])]; files := []; infds := [(0, (UStream «o», WriteMode, 0))]; numchars := LCONS 1 LNIL; maxFD := 0 |>``;
val ffiw = ``<| oracle := basis_ffi_oracle ext; ffi_state := (cl, ^fsw); io_events := [] |> : ^(ty_antiq bty)``;
val c8 = ``[0w;0w;0w;0w;0w;0w;0w;0w] : word8 list``; val a4 = ``[0w;0w;0w;0w] : word8 list``;
val wit = (let
  val rd = prove (``read_ffi_bytearrays ^mcw ^msw = (SOME ^c8, SOME ^a4)``,
     simp [read_ffi_bytearrays_def, read_ffi_bytearray_def, arm8_target_def] >>
     CONV_TAC (DEPTH_CONV (REWR_CONV (EVAL ``8:num = SUC (SUC (SUC (SUC (SUC (SUC (SUC (SUC 0)))))))`` |> EQT_ELIM))) >>
     rewrite_tac [EVAL ``4:num = SUC (SUC (SUC (SUC 0)))`` |> EQT_ELIM] >> show_tac "RD-0" >>
     simp [read_bytearray_def] >> show_tac "RD");
  val fw = prove (``?fs'. ffi_write ^c8 ^a4 ^fsw = SOME (FFIreturn ^a4 fs')``,
     simp [ffi_write_def, write_def, w82n_def, w22n_def, n2w2_def, LHD_THM, OPTION_CHOICE_EQUALS_OPTION] >> EVAL_TAC >> simp [LHD_THM] >> show_tac "FW");
  val th = store_thm ("constructed_successful_write_call_state",
  ``?mc dm (ffi:^(ty_antiq bty)) ext ms c ab ffi2 rest. refund_static ^mc dm /\ ffi.oracle = basis_ffi_oracle ext /\ ms.PC = 0x100004090w /\
       read_ffi_bytearrays mc ms = (SOME c, SOME ab) /\ call_FFI ffi (ExtCall «write») c ab = FFI_return ffi2 (0w :: rest)``,
  strip_assume_tac fw >>
  map_every exists_tac [mcw, dmw, ffiw, ``ext : ffiname -> mlstring list # IO_fs -> word8 list -> word8 list -> (mlstring list # IO_fs) oracle_result``, msw, c8, a4] >>
  simp [static_def, rd, call_FFI_def, basis_ffi_oracle_def] >> show_tac "W-END")
  in tags "constructed_successful_write_call_state" th; pr ("CHECKED constructed_successful_write_call_state\n" ^ thm_to_string th); pr "WITNESS_OK"; th end)
  handle e => (pr ("WITNESS_FAILED " ^ General.exnMessage e); problems := "witness" :: !problems; TRUTH);
(* ---- 2. Exact statements. ---- *)
val ok_args = ``(ms1:arm8_state).REG 1w = 8w /\
    w22n [ms1.MEM (ms1.REG 2w); ms1.MEM (ms1.REG 2w + 1w)] + w22n [ms1.MEM (ms1.REG 2w + 2w); ms1.MEM (ms1.REG 2w + 3w)] + 4 <= w2n (ms1.REG 3w)``;
val n = ref 0;
fun imp fetch thy (nm, tm) =
  let val th = fetch nm in
    if same tm (concl th) then () else (pr ("STORED " ^ nm ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ nm));
    tags nm th; n := !n + 1; pr ("IMPORTED " ^ thy ^ "." ^ nm ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end;
val _ = List.app (imp A "forge_refundWriteArgs")
  [("refund_render_fields_not_empty", ``refund_render_fields flds <> «»``),
   ("write_ok_event_def", ``!e. write_ok_event e <=> ?c (x:word8) bs. e = IO_event (ExtCall «write») c ((x, 0w) :: bs)``),
   ("ffi_write_return_cases",
      ``ffi_write c bytes fs = SOME (FFIreturn bytes' fs') ==>
        (bytes' = LUPDATE 1w 0 bytes /\ fs' = fs) \/
        (LENGTH c = 8 /\ ?n1 n0 o1 o0 tll rest. bytes = n1::n0::o1::o0::tll /\ bytes' = 0w :: rest /\
            w22n [n1; n0] + w22n [o1; o0] + 4 <= LENGTH bytes)``),
   ("nonempty_output_needs_successful_write_event",
      ``extract_fs ext (cl, fs) io = SOME (add_stdout (fastForwardFD fs 0) out) /\ STD_streams fs /\ EVERY refund_event io /\ out <> «» ==>
        EXISTS write_ok_event io``),
   ("evaluate_trace_write_events_have_call_states",
      ``!k mc ffi ms r ms' ffi'. refund_static ^mc dm /\ targetSem$evaluate mc (ffi:'ffi ffi_state) k ms = (r, ms', ffi') ==>
          ?l. ffi'.io_events = ffi.io_events ++ l /\
              !c bs. MEM (IO_event (ExtCall «write») c bs) l ==> ?ab nb. bs = ZIP (ab, nb) /\
                ?mcw ffiw msw ffix. machine_reach mc ffi ms mcw ffiw msw /\ msw.PC = 0x100004090w /\
                   read_ffi_bytearrays mcw msw = (SOME c, SOME ab) /\ call_FFI ffiw (ExtCall «write») c ab = FFI_return ffix nb``),
   ("successful_write_call_state_has_valid_arguments",
      ``refund_static ^mc1 dm /\ (ffi1:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\ read_ffi_bytearrays mc1 ms1 = (SOME c, SOME ab) /\
        call_FFI ffi1 (ExtCall «write») c ab = FFI_return ffi2 (0w :: rest) ==> ^ok_args``),
   ("successful_write_events_have_valid_call_states",
      ``!k mc ffi ms r ms' ffi'. refund_static ^mc dm /\ (ffi:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\
          targetSem$evaluate mc ffi k ms = (r, ms', ffi') ==>
          ?l. ffi'.io_events = ffi.io_events ++ l /\
              !e. MEM e l /\ write_ok_event e ==> ?mc1 ffi1 ms1. machine_reach mc ffi ms mc1 ffi1 ms1 /\ ms1.PC = 0x100004090w /\ ^ok_args``),
   ("wrong_clen_write_never_succeeds",
      ``LENGTH (c:word8 list) <> 8 /\ ffi_write c bytes fs = SOME (FFIreturn bytes' fs') ==> bytes' = LUPDATE 1w 0 bytes /\ fs' = fs``),
   ("short_array_write_is_rejected", ``LENGTH (bytes:word8 list) < 4 ==> ffi_write c bytes fs = NONE``),
   ("wrong_clen_register_gives_no_successful_write",
      ``refund_static ^mc1 dm /\ (ffi1:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\ read_ffi_bytearrays mc1 ms1 = (SOME c, SOME ab) /\
        ms1.REG 1w <> 8w /\ call_FFI ffi1 (ExtCall «write») c ab = FFI_return ffi2 nb ==> !rest. nb <> 0w :: rest``)];
(* Preserved U399 statements. *)
val reach_tm = ``?mc1 ffi1 ms1. machine_reach ^mc (ffi:'ffi ffi_state) ms mc1 ffi1 ms1 /\ ms1.PC = 0x100004090w``;
val _ = List.app (imp R "forge_refundWriteReach")
  [("evaluate_trace_events",
      ``!k mc ffi ms r ms' ffi'. refund_static ^mc dm /\ targetSem$evaluate mc (ffi:'ffi ffi_state) k ms = (r, ms', ffi') ==>
          ?l. ffi'.io_events = ffi.io_events ++ l /\ EVERY refund_event l /\ (EXISTS write_event l ==> ^reach_tm)``),
   ("nonempty_output_needs_write_event",
      ``extract_fs ext (cl, fs) io = SOME (add_stdout (fastForwardFD fs 0) out) /\ STD_streams fs /\ EVERY refund_event io /\ out <> «» ==>
        EXISTS write_event io``),
   ("ffi_write_wrong_clen_is_a_silent_failure",
      ``LENGTH (c:word8 list) <> 8 /\ 4 <= LENGTH (bytes:word8 list) ==> ffi_write c bytes fs = SOME (FFIreturn (LUPDATE 1w 0 bytes) fs)``),
   ("replay_ignores_wrong_clen_write_event",
      ``LENGTH (c:word8 list) <> 8 /\ 4 <= LENGTH (bytes:word8 list) ==>
        extract_fs_with_numchars ext st (IO_event (ExtCall «write») c (ZIP (bytes, LUPDATE 1w 0 bytes)) :: l) = extract_fs_with_numchars ext st l``)];
val _ = pr ("IMPORTED_COUNT " ^ Int.toString (!n));
(* ---- 3. Scope controls. ---- *)
val thms = DB.theorems "forge_refundWriteArgs";
fun f nm = concl (valOf (Option.map #2 (List.find (fn (m, _) => m = nm) thms)));
val _ = List.app (fn (nm, th) => tags nm th) (thms @ DB.definitions "forge_refundWriteArgs");
val _ = pr ("STORED_THEOREMS forge_refundWriteArgs " ^ Int.toString (length thms) ^ " AXIOMS " ^ Int.toString (length (DB.axioms "forge_refundWriteArgs")));
val t3 = f "refund_terminating_run_reaches_valid_write_call"; val t4 = f "refund_reached_valid_write_call_and_path";
val emp = fn t => is_neg t andalso is_eq (dest_neg t) andalso same (rhs (dest_neg t)) ``«»``;
val _ = if List.all (fn c => has_const "machine_sem" (fst (dest_imp c)) andalso has_const "refund_static" (fst (dest_imp c)) andalso
                             has_const "refund_installed_no_handler" (fst (dest_imp c)) andalso
                             can (find_term (same ``Terminate Success (io':io_event list)``)) (fst (dest_imp c)) andalso
                             not (can (find_term emp) (fst (dest_imp c)))) [t3, t4]
        then pr "CONTROL_OK both U400 refund theorems keep as premises: installed state, refund_static, a run that terminates with Success; the non-empty-output premise is gone"
        else bad "refund-premises";
val u3 = concl (R "refund_terminating_run_reaches_write_call");
val _ = if can (find_term emp) (fst (dest_imp u3)) then pr "CONTROL_OK the U399 refund theorem is unchanged (it still has the non-empty-output premise)" else bad "u399-changed";
val _ = if List.all (fn (nm, th) => not (has_const "machine_reach" (concl th)) orelse is_imp (snd (strip_forall (concl th)))) thms
        then pr "CONTROL_OK no theorem asserts a reachable call state unconditionally"
        else bad "unconditional-reach";
val reg8 = ``(ms1:arm8_state).REG 1w = 8w``;
val with8 = List.filter (fn (_, th) => can (find_term (same reg8)) (concl th)) thms;
val _ = if List.all (fn (_, th) => let val c = snd (strip_forall (concl th)) in is_imp c andalso not (can (find_term (same reg8)) (fst (dest_imp c))) andalso
                       (has_const "basis_ffi_oracle" (fst (dest_imp c)) orelse has_const "basis_ffi" (fst (dest_imp c))) end) with8 andalso length with8 = 4
        then pr "CONTROL_OK clen = 8 occurs in 4 theorems, only as a conclusion, and only under the basis oracle (premise); it is never a premise"
        else bad ("reg8 " ^ String.concatWith " " (map fst with8));
val a1 = snd (dest_imp (snd (strip_forall (f "successful_write_events_have_valid_call_states"))));
val _ = if can (find_term (fn t => is_imp t andalso has_const "write_ok_event" (fst (dest_imp t)) andalso can (find_term (same reg8)) (snd (dest_imp t)))) a1 andalso
           not (can (find_term (fn t => is_imp t andalso has_const "write_event" (fst (dest_imp t)))) a1)
        then pr "CONTROL_OK argument facts are given only for successful write events (result byte 0); failed write events give nothing"
        else bad "ok-event-scope";
val wr = Lib.sort (fn x => fn y => x <= y) (map fst (List.filter (fn (_, th) => has_const "write_call_rel" (concl th) orelse has_const "ffiwrite_call_pre" (concl th)) thms));
val _ = if wr = ["refund_reached_valid_write_call_and_path"] andalso
           can (find_term (fn t => is_imp t andalso has_const "ffiwrite_call_pre" (fst (dest_imp t)))) (snd (dest_imp t4)) andalso
           can (find_term (fn t => is_imp t andalso has_const "write_call_rel" (fst (dest_imp t)))) (snd (dest_imp t4))
        then pr "CONTROL_OK ffiwrite_call_pre and write_call_rel occur only in the composition theorem, and only as premises (the other conjuncts are NOT derived)"
        else bad ("pre-scope " ^ String.concatWith " " wr);
val _ = if not (List.exists (fn (_, th) => has_const "semantics_prog" (concl th) orelse has_const "semantics_dec_list" (concl th) orelse
                                             has_const "aligned" (concl th)) thms)
        then pr "CONTROL_OK no theorem states source-level semantics; no theorem states alignment"
        else bad "source-or-alignment";
val ret = concl (DB.fetch "forge_refundFfiwriteSuccess" "cake_ffiwrite_path_returns");
val _ = if has_const "write_call_rel" ret andalso same (fst (dest_imp ret)) ``ffiwrite_call_pre dm s b c a g`` then pr "CONTROL_OK cake_ffiwrite_path_returns (U398) is loaded with its premise unchanged"
        else bad "returns-changed";
val closure = "forge_refundWriteArgsCheck" :: Theory.ancestry "forge_refundWriteArgsCheck";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = pr ("CLOSURE_HAS_COMPILE_CORRECT_CONTROL " ^ Bool.toString (Lib.mem "forge_compileCorrectControl" closure));
val _ = pr ("CLOSURE_HAS_U399 " ^ Bool.toString (Lib.mem "forge_refundWriteReach" closure));
val _ = List.app (fn nd => List.app (fn (ax,_) => pr ("CLOSURE_AXIOM " ^ nd ^ "." ^ ax)) (DB.axioms nd)) closure;
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = export_theory ();
val _ = pr "AFTER_POSITIVE_AUDIT";
val _ = pr "P3_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
