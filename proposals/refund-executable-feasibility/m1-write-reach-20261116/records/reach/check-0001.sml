(* U399: (1) a constructed model execution with a write event, so the trace theorem's premises are satisfiable (NOT a refund execution,
   NOT a real execution); (2) exact-statement import of the main U399 theorems; (3) scope controls. *)
open preamble targetSemTheory ffiTheory semanticsPropsTheory fsFFITheory basis_ffiTheory TextIOProofTheory arm8Theory arm8_targetTheory
     forge_refundCallSiteTheory forge_refundFfiwriteSuccessTheory forge_refundWriteReachTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundWriteReachCheck";
fun same a b = aconv a b;
fun has_const n tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;
fun R n = DB.fetch "forge_refundWriteReach" n;
val static_def = DB.fetch "forge_refundCallSite" "refund_static_def";
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val mc = mk_var ("mc", mcty);
val names4 = ``[«read»; «write»; «close»; «open_in»]``;
(* ---- 1. Constructed model execution. ---- *)
val mcw = ``(ARB:^(ty_antiq mcty)) with <| ffi_names := [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»];
     ffi_entry_pcs := [0x1000040A0w; 0x100004090w; 0x100004080w; 0x100004070w]; halt_pc := 0x1000040C0w; install_pc := 0x1000040B0w;
     mmio_info := []; prog_addresses := {}; target := arm8_target; ptr_reg := 0; len_reg := 1; ptr2_reg := 2; len2_reg := 3 |>``;
val msw = ``(ARB:arm8_state) with <| PC := 0x100004090w; REG := K 0w |>``;
val ffiw = ``<| oracle := (\n s c b. Oracle_return s b); ffi_state := (); io_events := [] |> : unit ffi_state``;
val wit = (let val th = store_thm ("constructed_model_run_has_write_event",
  ``?mc dm (ffi:unit ffi_state) ms k r ms' ffi'. refund_static ^mc dm /\ ffi.io_events = [] /\ ms.PC = 0x100004090w /\
       targetSem$evaluate mc ffi k ms = (r, ms', ffi') /\ EXISTS write_event ffi'.io_events``,
  map_every exists_tac [mcw, ``{}:word64 set``, ffiw, msw, ``1n``] >>
  `refund_static ^mcw {}` by simp [static_def] >>
  `(^msw).PC = 0x100004090w` by simp [] >>
  `read_ffi_bytearrays ^mcw ^msw = (SOME [], SOME [])` by
     (simp [read_ffi_bytearrays_def, read_ffi_bytearray_def, arm8_target_def] >> EVAL_TAC >> show_tac "W-READ") >>
  `?new_ffi nb. call_FFI ^ffiw (ExtCall «write») [] [] = FFI_return new_ffi nb` by (simp [call_FFI_def] >> EVAL_TAC >> show_tac "W-CALL") >>
  drule_all (R "write_call_step_appends_write_event") >> strip_tac >>
  qexistsl_tac [`TimeOut`, `ms2`, `new_ffi`] >> asm_simp_tac (srw_ss()) [R "write_event_def"] >> show_tac "W-END")
  in tags "constructed_model_run_has_write_event" th; pr ("CHECKED constructed_model_run_has_write_event\n" ^ thm_to_string th); pr "WITNESS_OK"; th end)
  handle e => (pr ("WITNESS_FAILED " ^ General.exnMessage e); TRUTH);
(* ---- 2. Exact statements. ---- *)
val reach_tm = ``?mc1 ffi1 ms1. machine_reach ^mc (ffi:'ffi ffi_state) ms mc1 ffi1 ms1 /\ ms1.PC = 0x100004090w``;
val n = ref 0;
val _ = List.app (fn (nm, tm) =>
  let val th = R nm in
    if same tm (concl th) then () else (pr ("STORED " ^ nm ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ nm));
    tags nm th; n := !n + 1; pr ("IMPORTED forge_refundWriteReach." ^ nm ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end)
  [("write_event_def", ``!e. write_event e <=> ?c b. e = IO_event (ExtCall «write») c b``),
   ("refund_event_def", ``!e. refund_event e <=> ?n c b. e = IO_event (ExtCall n) c b /\ MEM n ^names4``),
   ("evaluate_trace_events",
      ``!k mc ffi ms r ms' ffi'. refund_static ^mc dm /\ targetSem$evaluate mc (ffi:'ffi ffi_state) k ms = (r, ms', ffi') ==>
          ?l. ffi'.io_events = ffi.io_events ++ l /\ EVERY refund_event l /\ (EXISTS write_event l ==> ^reach_tm)``),
   ("terminating_trace_with_write_event_reaches_write_call",
      ``refund_static ^mc dm /\ machine_sem mc (ffi:'ffi ffi_state) ms (Terminate t io) /\ ffi.io_events = [] ==>
        EVERY refund_event io /\ (EXISTS write_event io ==> ^reach_tm)``),
   ("replay_without_write_event_keeps_inodes",
      ``!l st st'. extract_fs_with_numchars ext st l = SOME st' /\ EVERY refund_event l /\ ~EXISTS write_event l ==>
                   (SND st').inode_tbl = (SND st).inode_tbl``),
   ("nonempty_output_needs_write_event",
      ``extract_fs ext (cl, fs) io = SOME (add_stdout (fastForwardFD fs 0) out) /\ STD_streams fs /\ EVERY refund_event io /\ out <> «» ==>
        EXISTS write_event io``),
   ("run_with_output_reaches_write_call",
      ``refund_static ^mc dm /\ machine_sem mc (basis_ffi ext cl fs) ms (Terminate t io) /\
        extract_fs ext (cl, fs) io = SOME (add_stdout (fastForwardFD fs 0) out) /\ STD_streams fs /\ out <> «» ==>
        EXISTS write_event io /\
        ?mc1 ffi1 ms1. machine_reach mc (basis_ffi ext cl fs) ms mc1 ffi1 ms1 /\ ms1.PC = 0x100004090w``),
   ("no_step_no_event", ``targetSem$evaluate ^mc (ffi:'ffi ffi_state) 0 ms = (TimeOut, ms, ffi)``),
   ("ffi_write_wrong_clen_is_a_silent_failure",
      ``LENGTH (c:word8 list) <> 8 /\ 4 <= LENGTH (bytes:word8 list) ==> ffi_write c bytes fs = SOME (FFIreturn (LUPDATE 1w 0 bytes) fs)``),
   ("replay_ignores_wrong_clen_write_event",
      ``LENGTH (c:word8 list) <> 8 /\ 4 <= LENGTH (bytes:word8 list) ==>
        extract_fs_with_numchars ext st (IO_event (ExtCall «write») c (ZIP (bytes, LUPDATE 1w 0 bytes)) :: l) = extract_fs_with_numchars ext st l``)];
val _ = pr ("IMPORTED_COUNT " ^ Int.toString (!n));
(* ---- 3. Scope controls. ---- *)
val thms = DB.theorems "forge_refundWriteReach";
fun f nm = concl (valOf (Option.map #2 (List.find (fn (m, _) => m = nm) thms)));
val _ = List.app (fn (nm, th) => tags nm th) (thms @ DB.definitions "forge_refundWriteReach");
val _ = pr ("STORED_THEOREMS forge_refundWriteReach " ^ Int.toString (length thms) ^ " AXIOMS " ^ Int.toString (length (DB.axioms "forge_refundWriteReach")));
val t3 = f "refund_terminating_run_reaches_write_call"; val t4 = f "refund_reached_write_call_facts_and_path";
val _ = if List.all (fn c => has_const "machine_sem" (fst (dest_imp c)) andalso has_const "refund_static" (fst (dest_imp c)) andalso
                             has_const "refund_installed_no_handler" (fst (dest_imp c)) andalso
                             can (find_term (same ``Terminate Success (io':io_event list)``)) (fst (dest_imp c)) andalso
                             can (find_term (fn t => is_neg t andalso is_eq (dest_neg t) andalso same (rhs (dest_neg t)) ``«»``)) (fst (dest_imp c))) [t3, t4]
        then pr "CONTROL_OK both refund theorems keep as premises: installed state, refund_static, a run that terminates with Success, non-empty output"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = if List.all (fn (nm, th) => not (has_const "machine_reach" (concl th)) orelse is_imp (snd (strip_forall (concl th)))) thms
        then pr "CONTROL_OK no theorem asserts a reachable call state unconditionally; every machine_reach conclusion is under an implication"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val (_, mb) = dest_imp (snd (strip_forall (f "evaluate_trace_events")));
val _ = if can (find_term (fn t => is_imp t andalso same (fst (dest_imp t)) ``EXISTS write_event (l:io_event list)`` andalso has_const "machine_reach" (snd (dest_imp t)))) mb
        then pr "CONTROL_OK in the trace theorem the call state is asserted only under EXISTS write_event on the appended events (absent or unrelated events give nothing)"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val wr = Lib.sort (fn x => fn y => x <= y) (map fst (List.filter (fn (_, th) => has_const "write_call_rel" (concl th) orelse has_const "ffiwrite_call_pre" (concl th)) thms));
val _ = if wr = ["refund_reached_write_call_facts_and_path"] andalso
           can (find_term (fn t => is_imp t andalso has_const "ffiwrite_call_pre" (fst (dest_imp t)))) (snd (dest_imp t4)) andalso
           can (find_term (fn t => is_imp t andalso has_const "write_call_rel" (fst (dest_imp t)))) (snd (dest_imp t4))
        then pr "CONTROL_OK ffiwrite_call_pre and write_call_rel occur only in the composition theorem, and only as premises: clen = 8, the buffer bound and the separations are NOT derived"
        else pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ String.concatWith " " wr);
val _ = if not (List.exists (fn (_, th) => can (find_term (same ``(ms1:arm8_state).REG 1w = 8w``)) (concl th)) thms) andalso
           not (List.exists (fn (_, th) => has_const "semantics_prog" (concl th) orelse has_const "semantics_dec_list" (concl th)) thms)
        then pr "CONTROL_OK no theorem concludes clen = 8; no theorem states source-level semantics (no source-level reachability claim)"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val ret = concl (DB.fetch "forge_refundFfiwriteSuccess" "cake_ffiwrite_path_returns");
val _ = if has_const "write_call_rel" ret andalso same (fst (dest_imp ret)) ``ffiwrite_call_pre dm s b c a g`` then pr "CONTROL_OK cake_ffiwrite_path_returns (U398) is loaded with its premise unchanged"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val closure = "forge_refundWriteReachCheck" :: Theory.ancestry "forge_refundWriteReachCheck";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = pr ("CLOSURE_HAS_COMPILE_CORRECT_CONTROL " ^ Bool.toString (Lib.mem "forge_compileCorrectControl" closure));
val _ = List.app (fn nd => List.app (fn (ax,_) => pr ("CLOSURE_AXIOM " ^ nd ^ "." ^ ax)) (DB.axioms nd)) closure;
val _ = export_theory ();
val _ = pr "AFTER_POSITIVE_AUDIT";
val _ = pr "P3_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
