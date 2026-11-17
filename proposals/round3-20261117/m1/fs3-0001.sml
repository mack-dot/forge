(* U427 (Round 3, M1 step A): the input premises of the refund theorems are satisfiable.
   For EVERY text inp there is a model file system and a command line with
     stdin_content fs = SOME inp, wfcl cl, wfFS fs, STD_streams fs.
   Uses only HOL and the CakeML basis (rebuilt 2026-11-17). It does not use any Forge M1 theory.
   A statement about the HOL model of the file system. NOT evidence about macOS. NOT a native execution witness. *)
open preamble llistTheory fsFFITheory fsFFIPropsTheory clFFITheory CommandLineProofTheory TextIOProofTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_OUT"));
val _ = new_theory "forge_inputPremiseSat";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
(* mk_thm is used ONLY to let later lemmas be explored after a failure; the run raises Fail before export if any lemma failed,
   and every stored theorem is tag-checked. *)
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; mk_thm ([], goal));
val _ = pr ("USED always_coind\n" ^ thm_to_string always_coind);
val unf = thm "LREPEAT_one_unfold" ``LREPEAT [1n] = 1 ::: LREPEAT [1]``
  (CONV_TAC (LAND_CONV (ONCE_REWRITE_CONV [LREPEAT_thm])) >> simp []);
val notfin = thm "LFINITE_not_LREPEAT_one" ``!ll. LFINITE ll ==> ll <> LREPEAT [1n]``
  (ho_match_mp_tac LFINITE_INDUCTION >> conj_tac >- simp [] >> rpt gen_tac >> strip_tac >>
   once_rewrite_tac [unf] >> rewrite_tac [LCONS_11] >> asm_rewrite_tac [] >> show_tac "NOTFIN");
val alw = thm "always_eventually_LREPEAT_one"
  ``!ll. ll = LREPEAT [1n] ==> always (eventually (\ll. ?k. LHD ll = SOME k /\ k <> 0n)) ll``
  (ho_match_mp_tac always_coind >> rpt strip_tac >> qexistsl_tac [`1`, `LREPEAT [1]`] >> rpt conj_tac
   >- (asm_rewrite_tac [] >> MATCH_ACCEPT_TAC unf)
   >- (simp [] >> show_tac "ALW2")
   >- (simp [] >> show_tac "ALW3"));
val live = thm "live_numchars_LREPEAT_one" ``live_numchars (LREPEAT [1n])``
  (rewrite_tac [live_numchars_def] >> conj_tac
   >- (strip_tac >> imp_res_tac notfin >> fs [])
   >- (mp_tac (Q.SPEC `LREPEAT [1]` alw) >> simp []));
val fs_def = new_definition ("sat_fs_def", ``sat_fs (inp:string) =
   <| inode_tbl := [(UStream (strlit "stdin"), inp); (UStream (strlit "stdout"), ""); (UStream (strlit "stderr"), "")];
      files := [];
      infds := [(0, (UStream (strlit "stdin"), ReadMode, 0)); (1, (UStream (strlit "stdout"), WriteMode, 0));
                (2, (UStream (strlit "stderr"), WriteMode, 0))];
      numchars := LREPEAT [1]; maxFD := 2 |>``);
val _ = pr ("DEFINITION " ^ thm_to_string fs_def);
val F1 = thm "sat_fs_wfFS" ``!inp. wfFS (sat_fs inp)``
  (rw [wfFS_def, fs_def, consistentFS_def, liveFS_def, live] >> simp [] >> show_tac "F1");
val F2 = thm "sat_fs_STD_streams" ``!inp. STD_streams (sat_fs inp)``
  (gen_tac >> rewrite_tac [STD_streams_def] >> qexistsl_tac [`0`, `""`, `""`] >> simp [fs_def] >> rw [] >> EQ_TAC >> rw [] >>
   show_tac "F2");
val F3 = thm "sat_fs_stdin_content" ``!inp. stdin_content (sat_fs inp) = SOME inp``
  (rw [stdin_content_def, fs_def] >> show_tac "F3");
val F4 = thm "sat_cl_wfcl" ``wfcl [strlit "refund"]``
  (simp [wfcl_def, validArg_def] >> EVAL_TAC >> show_tac "F4");
val F5 = thm "refund_input_premises_satisfiable"
  ``!inp. ?fs cl. stdin_content fs = SOME inp /\ wfcl cl /\ wfFS fs /\ STD_streams fs``
  (gen_tac >> qexistsl_tac [`sat_fs inp`, `[strlit "refund"]`] >> rewrite_tac [F1, F2, F3, F4]);
(* Negative controls. *)
val K1 = thm "consumed_stdin_has_no_content"
  ``!inp. stdin_content (sat_fs inp with infds := [(0, (UStream (strlit "stdin"), ReadMode, 1)); (1, (UStream (strlit "stdout"), WriteMode, 0));
                                                   (2, (UStream (strlit "stderr"), WriteMode, 0))]) = NONE``
  (rw [stdin_content_def, fs_def]);
val K2 = thm "finite_numchars_is_not_live" ``~live_numchars [||]`` (simp [live_numchars_def]);
val K3 = thm "empty_command_line_is_not_wfcl" ``~wfcl []`` (simp [wfcl_def]);
val K4 = thm "finite_numchars_file_system_is_not_wfFS" ``!inp. ~wfFS (sat_fs inp with numchars := [||])``
  (rw [wfFS_def, liveFS_def, live_numchars_def]);
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_inputPremiseSat" @ DB.definitions "forge_inputPremiseSat");
val closure = "forge_inputPremiseSat" :: Theory.ancestry "forge_inputPremiseSat";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_inputPremiseSat")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
