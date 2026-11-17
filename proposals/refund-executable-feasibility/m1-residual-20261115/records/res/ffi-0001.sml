(* U391: FFI names and shmem_extra of the exact lab configuration refund_lab_conf2, by in-logic evaluation of the published
   compiler with the recorded allocation oracle (the method of U345). The stored code, data, ffis and conf constants must be
   syntactically the recomputed values. *)
open preamble cv_transLib backendTheory backend_asmTheory lab_to_targetTheory targetSemTheory backendProofTheory
     forge_refundArm8CompileTheory forge_refundLabClosureTheory forge_refundCompileFactsTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (300, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundFfiFacts";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
(* ---- 1. Recompute the compile with the recorded oracle. ---- *)
val prog_def = DB.fetch "forge_refundWholeProg" "refund_prog_def";
val _ = Feedback.trace ("Theory.allow_rebinds", 1) (cv_trans_deep_embedding EVAL) prog_def;
val c = EVAL ``arm8_config$arm8_backend_config``;
val conf_tm = rhs (concl c);
val c_oracle_tm = ``set_oracle ^conf_tm refund_alloc_oracle``;
val th1 = cv_eval_raw ``compile_cake_arm8 ^c_oracle_tm refund_prog``;
val to_option_some = cv_typeTheory.to_option_def |> cj 2;
val to_pair = cv_typeTheory.to_pair_def |> cj 1;
val c2n_Num = cvTheory.c2n_def |> cj 1;
val th3 = th1 |> CONV_RULE (PATH_CONV "lr" (REWRITE_CONV [GSYM c]))
              |> CONV_RULE (PATH_CONV "r" (REWR_CONV to_option_some))
              |> CONV_RULE (PATH_CONV "rr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrrrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrrrrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrrrrrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrlr" (REWR_CONV c2n_Num)
                        THENC PATH_CONV "rrrrrlr" (REWR_CONV c2n_Num)
                        THENC PATH_CONV "rrrrrrrlr" (REWR_CONV c2n_Num));
fun fold name path def th = CONV_RULE (PATH_CONV path (REWR_CONV (SYM def))) th
   handle _ => raise Fail ("Recomputed " ^ name ^ " differs from the stored constant");
val th4 = th3 |> fold "code" "rrlr" forge_refundArm8CompileTheory.code_def
              |> fold "data" "rrrrlr" forge_refundArm8CompileTheory.data_def
              |> fold "ffis" "rrrrrrlr" forge_refundArm8CompileTheory.ffis_def
              |> fold "conf" "rrrrrrrrr" forge_refundArm8CompileTheory.conf_def;
val _ = pr "SAME_AS_STORED code data ffis conf";
val compiled_full = MATCH_MP backend_arm8Theory.compile_cake_arm8_thm th4 |> REWRITE_RULE [LENGTH_NIL];
val _ = tags "compiled_full" compiled_full;
val _ = pr ("COMPILED_FULL " ^ thm_to_string compiled_full);
(* ---- 2. The configuration of the recomputed compile is refund_lab_conf2. ---- *)
val lab_compile = DB.fetch "forge_refundCompileFacts" "refund_lab_compile";
val ffis_c = ``forge_refundArm8Compile$ffis``;
val conf2 = thm "refund_lab_conf2_ffis"
  ``refund_lab_conf2.shmem_extra = [] /\ ^ffis_c = ffinames_to_string_list (the [] refund_lab_conf2.ffi_names)``
  (strip_assume_tac compiled_full >> qpat_x_assum `backend$compile _ _ _ = _` mp_tac >>
   simp [compile_eq_to_target, to_target_def, UNCURRY] >> strip_tac >> drule attach_bitmaps_SOME >>
   rewrite_tac [lab_compile] >> strip_tac >> show_tac "CONF2" >> gvs []);
(* ---- 3. The names: all are external calls; their count is the count of the evaluated string list. ---- *)
val ffis_lit = (REWR_CONV forge_refundArm8CompileTheory.ffis_def THENC EVAL) ffis_c;
val _ = pr ("FFIS " ^ thm_to_string ffis_lit);
val n_ffis = length (fst (listSyntax.dest_list (rhs (concl ffis_lit))));
val _ = pr ("FFI_NAME_COUNT " ^ Int.toString n_ffis);
val all_ext = thm "mmio_index_LENGTH_all_ExtCall"
  ``!names. mmio_pcs_min_index names = SOME (LENGTH names) ==> !j. j < LENGTH names ==> ?s. EL j names = ExtCall s``
  (gen_tac >> rewrite_tac [mmio_pcs_min_index_def] >> DEEP_INTRO_TAC some_intro >> simp [] >> show_tac "ALLEXT");
val len_ext = thm "ffinames_to_string_list_LENGTH"
  ``!l. (!j. j < LENGTH l ==> ?s. EL j l = ExtCall s) ==> LENGTH (ffinames_to_string_list l) = LENGTH l``
  (Induct >> simp [ffinames_to_string_list_def] >> rpt strip_tac >>
   first_assum (qspec_then `0` mp_tac) >> simp_tac (srw_ss()) [] >> strip_tac >> asm_simp_tac (srw_ss()) [ffinames_to_string_list_def] >>
   first_x_assum match_mp_tac >> rpt strip_tac >> first_x_assum (qspec_then `SUC j` mp_tac) >> simp []);
val lab_names = DB.fetch "forge_refundCompileFacts" "refund_lab_ffi_names";
val N = numSyntax.term_of_int n_ffis;
val names_thm = thm "refund_ffi_names"
  ``?names. refund_lab_conf2.ffi_names = SOME names /\ LENGTH names = ^N /\ mmio_pcs_min_index names = SOME ^N /\
            ffinames_to_string_list names = ^(rhs (concl ffis_lit)) /\ refund_lab_conf2.shmem_extra = []``
  (strip_assume_tac lab_names >> qexists_tac `ffi_names` >> strip_assume_tac conf2 >>
   `ffinames_to_string_list ffi_names = ^(rhs (concl ffis_lit))` by
      (qpat_x_assum `^ffis_c = _` mp_tac >> asm_rewrite_tac [ffis_lit] >> simp [miscTheory.the_def]) >>
   `LENGTH (ffinames_to_string_list ffi_names) = LENGTH ffi_names` by (match_mp_tac len_ext >> match_mp_tac all_ext >> first_assum ACCEPT_TAC) >>
   `LENGTH ffi_names = ^N` by (pop_assum (SUBST1_TAC o SYM) >> asm_rewrite_tac [] >> EVAL_TAC) >>
   fs [] >> show_tac "NAMES");
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val closure = "forge_refundFfiFacts" :: Theory.ancestry "forge_refundFfiFacts";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
