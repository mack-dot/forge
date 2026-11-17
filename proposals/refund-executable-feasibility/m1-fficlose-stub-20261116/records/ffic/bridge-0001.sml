(* U393: the instruction words of cake_fficlose, fficlose and the close import stub are the bytes of the executable file;
   the ARMv8 step theorems stated on the image predicate; the stub against the FFI contract.
   Three separate things: (1) abstract FFI correctness (U392 model), (2) exact stub and C-function steps (here),
   (3) external effects of the libSystem call (NOT modelled, NOT proved). Slide 0. *)
open preamble targetSemTheory asmPropsTheory lab_to_targetTheory arm8Theory arm8_targetTheory arm8_stepTheory alignmentTheory miscTheory
     forge_refundArm8CompileTheory forge_refundStartupBridgeTheory forge_refundCmlMainStepTheory forge_loaderMemLemmasTheory
     forge_refundImageTheory forge_refundResidualTheory forge_refundEnvModelTheory forge_refundFficloseStepTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2000, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundFficloseBridge";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
val file_def = DB.fetch "forge_refundImage" "refund_file_def";
val file_c = lhs (concl file_def);
val len_file = DB.fetch "forge_refundImage" "refund_file_length";
val image_def = DB.fetch "forge_refundImage" "refund_image_mem_def";
fun F n = DB.fetch "forge_refundFficloseStep" n;
val [code_def, user_def, pre1_def, pre2_def, pre3_def] = map F ["fficlose_code_bytes_def", "arm8_user_def", "fficlose_stub_pre_def",
      "fficlose_entry_pre_def", "fficlose_return_pre_def"];
val [stub_thm, prefix_thm, suffix_thm] = map F ["cake_fficlose_stub_run", "fficlose_prefix_run", "fficlose_suffix_run"];
val run_def = DB.fetch "forge_refundCmlMainStep" "arm8_run_def";
(* ---- 1. The words in the file constant (kernel evaluation). ---- *)
fun slice (off, n) = (RAND_CONV (RAND_CONV (REWR_CONV file_def)) THENC EVAL)
      ``TAKE ^(numSyntax.term_of_int n) (DROP ^(numSyntax.term_of_int off) ^file_c)``;
val sl_stub = slice (0x4080, 4); val sl_body = slice (0x25260, 68); val sl_imp = slice (0x258EC, 12);
val words_thm = save_thm ("refund_file_fficlose_words", LIST_CONJ [sl_stub, sl_body, sl_imp]);
val _ = chk "refund_file_fficlose_words" words_thm;
val SL = thm "bytes_in_memory_slice"
  ``!(f:word8 list) (a:word64) m N off n. bytes_in_memory a (TAKE N f) m UNIV /\ off + n <= N /\ N <= LENGTH f ==>
      bytes_in_memory (a + n2w off) (TAKE n (DROP off f)) m UNIV``
  (rw [bytes_in_memory_univ_EL, LENGTH_TAKE_EQ] >> first_x_assum (qspec_then `off + i` mp_tac) >>
   simp [EL_TAKE, EL_DROP, GSYM word_add_n2w] >> show_tac "SL");
val img_code = thm "refund_image_fficlose_code" ``!m. refund_image_mem 0w m ==> fficlose_code_bytes m``
  (rw [image_def] >>
   map_every (fn (off, n) => mp_tac (Q.SPECL [`refund_file`, `0x100000000w`, `m`, `163840`, off, n] SL))
      [(`16512`, `4`), (`152160`, `68`), (`153836`, `12`)] >>
   asm_simp_tac std_ss [len_file] >> simp [sl_stub, sl_body, sl_imp, bytes_in_memory_def] >> rpt strip_tac >>
   asm_simp_tac std_ss [code_def] >> show_tac "IMGCODE");
(* ---- 2. The stub, exactly, on the image. ---- *)
val stub_exact = thm "cake_fficlose_stub_exact"
  ``arm8_user s /\ s.PC = 0x100004080w /\ refund_image_mem 0w s.MEM ==>
    ?s1. arm8_run 1 s = SOME s1 /\ s1.PC = 0x100025260w /\ s1.REG = s.REG /\ s1.MEM = s.MEM /\ s1.SP_EL0 = s.SP_EL0 /\
         s1.PSTATE = s.PSTATE /\ s1.SCTLR_EL1 = s.SCTLR_EL1 /\ s1.TCR_EL1 = s.TCR_EL1 /\ s1.exception = s.exception``
  (strip_tac >> match_mp_tac stub_thm >> asm_rewrite_tac [pre1_def] >> match_mp_tac img_code >> first_assum ACCEPT_TAC);
val run_add = thm "arm8_run_add"
  ``!n1 n2 s s1 s2. arm8_run n1 s = SOME s1 /\ arm8_run n2 s1 = SOME s2 ==> arm8_run (n1 + n2) s = SOME s2``
  (Induct >> simp [run_def] >> rpt gen_tac >> simp [ADD_CLAUSES, run_def] >> CASE_TAC >> simp [] >> metis_tac []);
(* ---- 3. From the entry address to the branch that leaves the image: 15 steps. ---- *)
val b = ``b:word64``; val c = ``c:word64``; val g = ``g:word64``;
val entry_conds = ``s.SP_EL0 = ^b + 32w /\ aligned 3 ^b /\ s.REG 0w = ^c /\ aligned 2 ^c /\ s.REG 1w = 8w /\ ~word_msb (s.REG 3w) /\ s.REG 3w <> 0w /\
      mem_dword s.MEM 0x100028020w = ^g /\
      (!i (a:word64). i < 32 /\ 0x100000000w <=+ a /\ a <+ 0x100030F30w ==> ^b + n2w i <> a) /\
      (!i j. i < 32 /\ j < 8 ==> ^b + n2w i <> ^c + n2w j)``;
val (_, pbody) = dest_exists (snd (dest_imp (concl prefix_thm)));
val pconj = tl (strip_conj pbody);
val exit_goal = ``arm8_user s /\ s.PC = 0x100004080w /\ refund_image_mem 0w s.MEM /\ ^entry_conds ==>
                  ?s1. arm8_run 15 s = SOME s1 /\ ^(list_mk_conj pconj)``;
val exit_thm = thm "cake_fficlose_to_import_branch" exit_goal
  (strip_tac >> mp_tac stub_exact >> (impl_tac >- asm_rewrite_tac []) >> disch_then (qx_choose_then `s0` strip_assume_tac) >>
   mp_tac (Q.INST [`s` |-> `s0`] prefix_thm) >>
   (impl_tac >- (fs [pre2_def, user_def] >> match_mp_tac img_code >> first_assum ACCEPT_TAC)) >>
   disch_then (qx_choose_then `s1` strip_assume_tac) >> qexists_tac `s1` >>
   `arm8_run (1 + 14) s = SOME s1` by (match_mp_tac run_add >> qexists_tac `s0` >> asm_rewrite_tac []) >>
   fs [] >> show_tac "EXIT");
(* ---- 4. The stub against the contract. ---- *)
val WIT = DB.fetch "forge_refundEnvModel" "refund_ffi_contract_at_witness";
val FC = DB.fetch "forge_refundEnvModel" "ffi_interfer_ok_iff_contract";
val msw_def = DB.fetch "forge_refundEnvModel" "refund_ffi_witness_state_def";
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val envmc = mk_var ("envmc", mcty);
val stub_ffi_def = new_definition ("refund_stub_only_ffi_def",
  ``refund_stub_only_ffi (k:num) (x:num # word8 list # arm8_state) = (SND (SND x)) with PC := 0x100025260w``);
val n_stub = thm "stub_only_ffi_rejected"
  ``~ffi_interfer_ok 0x1000040D0w (refund_mc 0x1000040D0w (^envmc with ffi_interfer := refund_stub_only_ffi))``
  (rewrite_tac [CONV_RULE (RAND_CONV (SIMP_CONV (srw_ss()) [])) (INST [envmc |-> ``^envmc with ffi_interfer := refund_stub_only_ffi``] FC)] >>
   strip_tac >> drule WIT >> disch_then (qspec_then `0` mp_tac) >> simp [stub_ffi_def]);
val n_byte = thm "altered_stub_byte_rejected" ``!m. m 0x100004080w <> 0x78w ==> ~refund_image_mem 0w m``
  (rpt strip_tac >> imp_res_tac img_code >> fs [code_def]);
val n_word = save_thm ("altered_stub_word_not_in_file",
  EQF_ELIM ((LAND_CONV (K sl_stub) THENC EVAL) ``TAKE 4 (DROP 16512 ^file_c) = [0x79w; 0x84w; 0w; 0x14w:word8]``));
val _ = chk "altered_stub_word_not_in_file" n_word;
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val closure = "forge_refundFficloseBridge" :: Theory.ancestry "forge_refundFficloseBridge";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
