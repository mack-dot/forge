(* U388: absent-input characterisation; concrete machine record; bridge from the cml_main step proof to the U387 start-up clause. *)
open preamble backendTheory targetSemTheory targetPropsTheory asmPropsTheory arm8_targetTheory alignmentTheory arm8_stepTheory
     backendProofTheory arm8_configProofTheory fsFFIPropsTheory TextIOProofTheory forge_refundArm8CompileTheory forge_refundCompileFactsTheory
     forge_refundExclusionRealTheory forge_refundStartupClauseTheory forge_refundRejectNonFailTheory forge_refundCmlMainStepTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundStartupBridge";
fun fvn tm n = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars tm));
fun chk n th = (tags n th; pr ("CHECKED " ^ n ^ "\n" ^ thm_to_string th));
(* A. Absent input under STD_streams is exactly a non-zero standard-input offset. *)
val absent = store_thm ("stdin_absent_characterised",
  ``STD_streams fs ==> (stdin_content fs = NONE <=> ?off. off <> 0 /\ ALOOKUP fs.infds 0 = SOME (UStream «stdin»,ReadMode,off))``,
  strip_tac >> fs [STD_streams_def] >>
  `ALOOKUP fs.infds 0 = SOME (UStream «stdin»,ReadMode,inp)` by metis_tac [] >>
  simp [stdin_content_def] >> Cases_on `inp = 0` >> simp []);
val _ = chk "stdin_absent_characterised" absent;
(* C. Bridge: the ARMv8-level post-condition of cml_main gives the U387 start-up clause. *)
val red = DB.fetch "forge_refundStartupClause" "refund_startup_clause_arm8";
val rc = concl red;
val mc0 = fvn rc "mc0"; val ms = fvn rc "ms"; val t = fvn rc "t"; val mv = fvn rc "m";
val mwit = ``\a:word64. (Word (mem_dword (^ms).MEM a)) : 64 word_loc``;
val red_i = INST [mv |-> mwit, fvn rc "bitmap_ptr" |-> ``0x10002C018w:word64``, fvn rc "cbspace" |-> ``428:num``, fvn rc "data_sp" |-> ``0:num``] red;
val (rel, eqn) = dest_imp (concl red_i);
val clause_i = lhs eqn;
val bridge = store_thm ("refund_startup_from_cml_main", ``^rel /\ cml_main_post ^ms ==> ^clause_i``,
  strip_tac >> mp_tac red_i >> impl_tac >- asm_rewrite_tac [] >>
  disch_then (fn eq => rewrite_tac [eq]) >> fs [cml_main_post_def] >> show_tac "BRIDGE");
val _ = chk "refund_startup_from_cml_main" bridge;
val run = DB.fetch "forge_refundCmlMainStep" "cml_main_startup_conditions";
val (rpre, rpost) = dest_imp (concl run);
val (s1, rbody) = dest_exists rpost;
val est_goal = mk_imp (rpre, mk_exists (ms, list_mk_conj [
   subst [s1 |-> ms] (el 1 (strip_conj rbody)), subst [s1 |-> ms] (el 2 (strip_conj rbody)),
   list_mk_forall ([mc0, t], mk_imp (rel, clause_i))]));
val est = store_thm ("refund_startup_established", est_goal,
  strip_tac >> mp_tac run >> impl_tac >- asm_rewrite_tac [] >> strip_tac >>
  exists_tac s1 >> asm_rewrite_tac [] >> rpt strip_tac >>
  match_mp_tac (INST [ms |-> s1] bridge) >> asm_rewrite_tac []);
val _ = chk "refund_startup_established" est;
(* B. Concrete machine record. Physical parts (program addresses, interference functions) stay parameters. *)
val envmc = mk_var ("envmc", type_of mc0);
val base0 = ``base0:word64``;
val mc_def = new_definition ("refund_mc_def",
  ``refund_mc ^base0 ^envmc = arm8_fix (^envmc with <| ffi_names := THE refund_lab_conf2.ffi_names;
       ffi_entry_pcs := GENLIST (\i. ^base0 - n2w ((3 + i) * ffi_offset)) (LENGTH (THE refund_lab_conf2.ffi_names));
       halt_pc := ^base0 - n2w ffi_offset; install_pc := ^base0 - n2w (2 * ffi_offset);
       mmio_info := []; shared_addresses := {} |>)``);
val _ = pr ("DEFINITION " ^ thm_to_string mc_def);
val rmc = ``refund_mc ^base0 ^envmc``;
val fixth = DB.fetch "forge_refundStartupClause" "arm8_fix_is_arm8";
val fixdef = DB.fetch "forge_refundStartupClause" "arm8_fix_def";
val M1 = store_thm ("refund_mc_is_arm8", ``is_arm8_machine_config ^rmc``, rewrite_tac [mc_def] >> MATCH_ACCEPT_TAC fixth);
val _ = chk "refund_mc_is_arm8" M1;
val M2 = store_thm ("refund_mc_fields",
  ``refund_lab_conf2.ffi_names = SOME (^rmc).ffi_names /\ (^rmc).target = arm8_target /\
    (^rmc).halt_pc = ^base0 - n2w ffi_offset /\ (^rmc).install_pc = ^base0 - n2w (2 * ffi_offset) /\
    (^rmc).mmio_info = [] /\ (^rmc).shared_addresses = {} /\ (^rmc).prog_addresses = (^envmc).prog_addresses /\
    (^rmc).next_interfer = (^envmc).next_interfer /\ (^rmc).ffi_interfer = (^envmc).ffi_interfer /\
    (^rmc).install_interfer = (^envmc).install_interfer /\
    mmio_pcs_min_index (^rmc).ffi_names = SOME (LENGTH (^rmc).ffi_names) /\ LENGTH (^rmc).ffi_entry_pcs = LENGTH (^rmc).ffi_names``,
  strip_assume_tac refund_lab_ffi_names >> simp [mc_def, fixdef]);
val _ = chk "refund_mc_fields" M2;
(* Final theorems at the concrete record: is_arm8_machine_config is no longer a premise. *)
fun at_mc name new = let val th = DB.fetch "forge_refundRejectNonFail" name
     val th_i = INST [fvn (concl th) "mc0" |-> rmc] th
     val (ant, c) = dest_imp (concl th_i)
     val res = store_thm (new, mk_imp (list_mk_conj (tl (strip_conj ant)), c),
        strip_tac >> match_mp_tac th_i >> asm_rewrite_tac [M1])
  in chk new res; res end;
val U = at_mc "refund_u298_exclusion_stdin" "refund_mc_u298_exclusion_stdin";
val Bh = at_mc "refund_behavior_stdin_no_handler" "refund_mc_behavior_stdin_no_handler";
val _ = pr ("SHMEM " ^ thm_to_string (EVAL ``refund_lab_conf2.shmem_extra``) handle _ => "SHMEM not evaluated");
val closure = "forge_refundStartupBridge" :: Theory.ancestry "forge_refundStartupBridge";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
