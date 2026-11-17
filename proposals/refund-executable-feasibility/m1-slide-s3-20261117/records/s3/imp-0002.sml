(* U407: exact-statement import check for the U405 theories (forge_refundCmlMainSlide, forge_refundSlideEntry) and the U407 theories
   (forge_refundCmlMainFrameSlide, forge_refundSlideDomains, forge_refundSlideInstalled, forge_refundSlideSat).
   Each expected statement is written here, independently of the proof scripts, and compared with the stored theorem by aconv.
   No theorem is proved or stored. Same machine, same toolchain, cached parent theories: this is NOT a clean or independent replay. *)
open preamble wordsLib alignmentTheory arm8Theory arm8_stepTheory targetSemTheory forge_refundArm8CompileTheory forge_refundImageTheory
     forge_refundLoaderMemoryTheory forge_refundInstalledDomainsTheory forge_refundInstalledAssemblyTheory forge_refundResidualTheory
     forge_refundStartupBridgeTheory forge_refundExclusionRealTheory
     forge_refundCmlMainSlideTheory forge_refundSlideEntryTheory forge_refundCmlMainFrameSlideTheory forge_refundSlideDomainsTheory
     forge_refundSlideInstalledTheory forge_refundSlideSatTheory;
val _ = Globals.max_print_depth := 40;
fun pr s = print (s ^ "\n");
val bad = ref 0; val good = ref 0;
fun clean th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors end;
fun same thy name tm = let val th = DB.fetch thy name in aconv (concl th) tm andalso clean th end handle _ => false;
fun check thy name tm = if same thy name tm then (good := !good + 1; pr ("IMPORTED " ^ thy ^ "." ^ name))
                        else (bad := !bad + 1; pr ("IMPORT_MISMATCH " ^ thy ^ "." ^ name));
val code_tm = ``forge_refundArm8Compile$code``;
val A = "forge_refundCmlMainSlide"; val B = "forge_refundSlideEntry"; val C = "forge_refundCmlMainFrameSlide";
val D = "forge_refundSlideDomains"; val E = "forge_refundSlideInstalled"; val F = "forge_refundSlideSat";
val posts = ``s1.PC = sl + 0x1000040D0w /\ s1.REG 0w = sl + 0x1000040D0w /\ s1.REG 1w = (h:word64) /\ s1.REG 2w = (stk:word64) /\
              s1.REG 3w = (e:word64) /\ mem_dword s1.MEM h = sl + 0x10002C018w /\ mem_dword s1.MEM (h + 8w) = sl + 0x100030F30w /\
              mem_dword s1.MEM (h + 16w) = sl + 0x100030F30w /\ mem_dword s1.MEM (h + 24w) = sl + 0x100023E54w /\
              mem_dword s1.MEM (h + 32w) = sl + 0x100024000w``;
val frame = ``(!a. (!i. i < 40 ==> a <> (h:word64) + n2w i) ==> s1.MEM a = (s:arm8_state).MEM a) /\ s1.PSTATE = s.PSTATE /\
              s1.SCTLR_EL1 = s.SCTLR_EL1 /\ s1.TCR_EL1 = s.TCR_EL1 /\ s1.exception = s.exception``;
val sep = ``!i j. i < 40 /\ j < 200496 ==> (h:word64) + n2w i <> 0x100000000w + sl + (n2w j : word64)``;
(* ---- U405 ---- *)
val _ = check A "cml_main_run_sl" ``cml_main_pre_sl sl s h stk e ==> ?s1. forge_refundCmlMainSlide$arm8_run 27 s = SOME s1 /\ ^posts``;
val _ = check A "page_of_relocated_address" ``aligned 12 (sl:word64) ==> ((a + sl) && 0xFFFFFFFFFFFFF000w = (a && 0xFFFFFFFFFFFFF000w) + sl)``;
val _ = check A "misaligned_slide_not_covered" ``~aligned 12 (sl:word64) ==> ~cml_main_pre_sl sl s h stk e``;
val _ = check A "cml_main_sl_unrelocated_target_refuted"
  ``cml_main_pre_sl sl s h stk e /\ sl <> 0w ==> ~(?s1. forge_refundCmlMainSlide$arm8_run 27 s = SOME s1 /\ s1.PC = 0x1000040D0w)``;
val pre_def = DB.fetch A "cml_main_pre_sl_def";
val pre_cs = strip_conj (rhs (snd (strip_forall (concl pre_def))));
val _ = if length pre_cs = 13 + 108 andalso aconv (el 7 pre_cs) ``(s:arm8_state).PC = sl + 0x100004000w`` andalso aconv (el 13 pre_cs) ``aligned 12 (sl:word64)``
           andalso aconv (el 14 pre_cs) ``(s:arm8_state).MEM (sl + 0x100004000w) = 0w`` andalso aconv (el 17 pre_cs) ``(s:arm8_state).MEM (sl + 0x100004003w) = 0x90w``
        then (good := !good + 1; pr "IMPORTED forge_refundCmlMainSlide.cml_main_pre_sl_def (121 conjuncts; PC, alignment and first instruction word checked)")
        else (bad := !bad + 1; pr "IMPORT_MISMATCH forge_refundCmlMainSlide.cml_main_pre_sl_def");
val _ = check B "slide_ok_def" ``!sl:word64. slide_ok sl <=> aligned 12 sl /\ sl <=+ 0xFFFFFFFEFFFCF0CFw``;
val _ = check B "refund_entry_pre_sl_def" ``!sl s h stk e. refund_entry_pre_sl sl s h stk e <=>
     ~s.SCTLR_EL1.E0E /\ ~s.SCTLR_EL1.SA0 /\ ~s.TCR_EL1.TBI0 /\ ~s.TCR_EL1.TBI1 /\ s.PSTATE.EL = 0w /\ s.exception = NoException /\
     s.PC = sl + 0x100004000w /\ mem_dword s.MEM (sl + 0x10002C000w) = h /\ mem_dword s.MEM (sl + 0x10002C008w) = stk /\
     mem_dword s.MEM (sl + 0x10002C010w) = e /\ aligned 3 h /\ ^sep /\ refund_image_mem sl s.MEM /\ slide_ok sl``;
val _ = check B "refund_entry_pre_sl_IMP_cml_main_pre_sl" ``refund_entry_pre_sl sl s h stk e ==> cml_main_pre_sl sl s h stk e``;
val _ = check B "refund_entry_run_sl" ``refund_entry_pre_sl sl s h stk e ==> ?s1. forge_refundCmlMainStep$arm8_run 27 s = SOME s1 /\ ^posts``;
val _ = check B "arm8_run_constants_agree" ``!n s. forge_refundCmlMainSlide$arm8_run n s = forge_refundCmlMainStep$arm8_run n s``;
val _ = check B "refund_code_dm_sl_def" ``!sl:word64. refund_code_dm_sl sl = {a | a - sl IN refund_code_dm}``;
val _ = check B "refund_bitmaps_dm_sl_def" ``!sl:word64. refund_bitmaps_dm_sl sl = {a | a - sl IN refund_bitmaps_dm}``;
val _ = check B "refund_mem_dm_sl_def" ``!sl h e. refund_mem_dm_sl sl h e = refund_code_dm_sl sl UNION {w | h <=+ w /\ w <+ e} UNION refund_bitmaps_dm_sl sl``;
val _ = check B "refund_heap_clear_sl_def" ``!sl h e. refund_heap_clear_sl sl h e <=>
     !a. h <=+ a /\ a <+ e ==> ~(0x100000000w <=+ a - sl /\ a - sl <+ 0x100030F30w)``;
val _ = check B "refund_code_dm_sl_range" ``slide_ok sl ==> !a. a IN refund_code_dm_sl sl <=> 0x1000040D0w + sl <=+ a /\ a <+ 0x100024000w + sl``;
val _ = check B "refund_shifted_domains_disjoint" ``DISJOINT (refund_code_dm_sl sl) (refund_bitmaps_dm_sl sl)``;
val _ = check B "shifted_domains_at_slide_zero" ``refund_code_dm_sl 0w = refund_code_dm /\ refund_bitmaps_dm_sl 0w = refund_bitmaps_dm /\
     refund_mem_dm_sl 0w h e = refund_mem_dm h e /\ (refund_heap_clear_sl 0w h e <=> refund_heap_clear h e)``;
val _ = check B "slide_zero_entry_is_the_old_entry" ``refund_entry_pre s h stk e ==> refund_entry_pre_sl 0w s h stk e``;
val _ = check B "misaligned_or_wrapping_slide_not_covered" ``(~aligned 12 sl \/ 0xFFFFFFFEFFFCF0CFw <+ sl) ==> ~refund_entry_pre_sl sl s h stk e``;
(* ---- U407 ---- *)
val _ = check C "cml_main_run_frame_sl" (mk_imp (``cml_main_pre_sl sl s h stk e``, mk_exists (``s1:arm8_state``,
     list_mk_conj (``forge_refundCmlMainSlide$arm8_run 27 (s:arm8_state) = SOME s1`` :: strip_conj posts @ strip_conj frame))));
val _ = check D "refund_image_preserved_sl" ``!m m' h sl. refund_image_mem sl m /\ ^sep /\ (!a. (!i. i < 40 ==> a <> h + n2w i) ==> m' a = m a) ==>
     refund_image_mem sl m'``;
val _ = check D "refund_end_state_sl_def" ``!sl ms. refund_end_state_sl sl ms <=> slide_ok sl /\
   ms.PSTATE.EL = 0w /\ ~ms.SCTLR_EL1.E0E /\ ~ms.SCTLR_EL1.SA0 /\ ~ms.TCR_EL1.TBI1 /\ ~ms.TCR_EL1.TBI0 /\ ms.exception = NoException /\
   ms.PC = sl + 0x1000040D0w /\ aligned 3 (ms.REG 1w) /\ aligned 3 (ms.REG 3w) /\ ms.REG 1w <=+ ms.REG 3w /\ 8192w <=+ ms.REG 3w - ms.REG 1w /\
   refund_heap_clear_sl sl (ms.REG 1w) (ms.REG 3w) /\ refund_image_mem sl ms.MEM /\
   mem_dword ms.MEM (ms.REG 1w) = sl + 0x10002C018w /\ mem_dword ms.MEM (ms.REG 1w + 8w) = sl + 0x100030F30w /\
   mem_dword ms.MEM (ms.REG 1w + 16w) = sl + 0x100030F30w /\ mem_dword ms.MEM (ms.REG 1w + 24w) = sl + 0x100023E54w /\
   mem_dword ms.MEM (ms.REG 1w + 32w) = sl + 0x100024000w``;
val _ = check D "refund_end_state_sl_established"
  ``refund_entry_pre_sl sl s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear_sl sl h e ==>
    ?ms. forge_refundCmlMainStep$arm8_run 27 s = SOME ms /\ ms.REG 1w = h /\ ms.REG 3w = e /\ refund_end_state_sl sl ms``;
val _ = check D "refund_t_sl_target_state_rel" ``!ms. refund_end_state_sl sl ms ==> target_state_rel arm8_target (refund_t_sl sl ms) ms``;
val _ = check D "refund_code_bytes_in_mem_sl" ``!m h e. refund_heap_clear_sl sl h e /\ refund_image_mem sl m ==>
      bytes_in_mem (sl + 0x1000040D0w) ^code_tm m (refund_mem_dm_sl sl h e) ({w | h <=+ w /\ w <+ e} UNION refund_bitmaps_dm_sl sl)``;
val _ = check D "refund_heap_bitmaps_disjoint_sl" ``refund_heap_clear_sl sl h e ==> DISJOINT {w | h <=+ w /\ w <+ e} (refund_bitmaps_dm_sl sl)``;
val _ = check D "slide_zero_end_state_is_the_old_one" ``refund_end_state_sl 0w ms <=> refund_end_state ms``;
val _ = check D "end_state_fixes_one_slide" ``refund_end_state_sl sl ms /\ refund_end_state_sl sl' ms ==> sl = sl'``;
val mcT = ``:(64, arm8_state, 'c) machine_config``;
val RMC = ``refund_mc (sl + 0x1000040D0w) (envmc : ^(ty_antiq (type_of (hd (List.filter (fn v => fst (dest_var v) = "envmc")
                 (free_vars (concl (DB.fetch E "refund_installed_from_entry_reduced_sl"))))))))``;
val envmc = el 2 (snd (strip_comb RMC));
val _ = check E "refund_installed_from_end_state_sl"
  ``is_arm8_machine_config mc0 /\ mc0.prog_addresses = refund_mem_dm_sl sl (ms.REG 1w) (ms.REG 3w) /\ refund_end_state_sl sl ms /\
    refund_installed_rest mc0 ms ==> refund_installed_no_handler mc0 ms 428 0``;
val _ = check E "refund_installed_rest_reduced_sl"
  ``refund_heap_clear_sl sl h e /\ (^envmc).prog_addresses = refund_mem_dm_sl sl h e /\ (ms:arm8_state).PC = sl + 0x1000040D0w /\ slide_ok sl /\
    refund_installed_rest2 ^RMC ms ==> refund_installed_rest ^RMC ms``;
val _ = check E "refund_installed_from_entry_reduced_sl"
  ``refund_entry_pre_sl sl s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear_sl sl h e /\
    (^envmc).prog_addresses = refund_mem_dm_sl sl h e ==>
    ?ms. forge_refundCmlMainStep$arm8_run 27 s = SOME ms /\ ms.PC = sl + 0x1000040D0w /\
         (refund_installed_rest2 ^RMC ms ==> refund_installed_no_handler ^RMC ms 428 0)``;
val _ = check E "unrelocated_record_rejected_at_nonzero_slide" ``sl <> 0w ==> ~start_pc_ok (refund_mc 0x1000040D0w ^envmc) (sl + 0x1000040D0w)``;
val _ = check F "refund_entry_sl_premises_satisfiable_at_0x4000"
  ``?s h stk e (envmc : ^(ty_antiq (type_of envmc))). refund_entry_pre_sl 0x4000w s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\
       refund_heap_clear_sl 0x4000w h e /\ envmc.prog_addresses = refund_mem_dm_sl 0x4000w h e``;
(* The residual constants are the stored U390/U391 ones: both environment clauses are still in rest2. *)
val r2 = DB.fetch "forge_refundResidual" "refund_installed_rest2_def";
val r2c = strip_conj (rhs (snd (strip_forall (concl r2))));
fun has n tm = can (find_term (fn x => is_const x andalso fst (dest_const x) = n)) tm;
val _ = if length r2c = 2 andalso has "interference_ok" (el 1 r2c) andalso has "ffi_interfer_ok" (el 2 r2c)
        then (good := !good + 1; pr "IMPORTED forge_refundResidual.refund_installed_rest2_def (two unproved environment clauses)")
        else (bad := !bad + 1; pr "IMPORT_MISMATCH refund_installed_rest2_def");
(* Tags of every theorem and definition in the six theories; theorem counts. *)
val _ = List.app (fn thy => let val ths = DB.theorems thy @ DB.definitions thy
                                val dirty = List.filter (fn (_, th) => not (clean th)) ths
                            in pr ("THEORY " ^ thy ^ " theorems " ^ Int.toString (length (DB.theorems thy)) ^ " definitions " ^
                                   Int.toString (length (DB.definitions thy)) ^ " unclean " ^ Int.toString (length dirty));
                               if null dirty then () else bad := !bad + 1 end) [A, B, C, D, E, F];
(* Negative controls of this checker. *)
fun ctl name ok = if ok then pr ("CONTROL_OK " ^ name) else (bad := !bad + 1; pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ name));
val _ = ctl "slide_ok with aligned 3 is not the stored definition"
          (not (same B "slide_ok_def" ``!sl:word64. slide_ok sl <=> aligned 3 sl /\ sl <=+ 0xFFFFFFFEFFFCF0CFw``));
val _ = ctl "entry-reduced theorem without the heap-clear premise is not the stored theorem"
          (not (same E "refund_installed_from_entry_reduced_sl"
            ``refund_entry_pre_sl sl s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\
              (^envmc).prog_addresses = refund_mem_dm_sl sl h e ==>
              ?ms. forge_refundCmlMainStep$arm8_run 27 s = SOME ms /\ ms.PC = sl + 0x1000040D0w /\
                   (refund_installed_rest2 ^RMC ms ==> refund_installed_no_handler ^RMC ms 428 0)``));
val _ = ctl "entry-reduced theorem without the rest2 premise is not the stored theorem"
          (not (same E "refund_installed_from_entry_reduced_sl"
            ``refund_entry_pre_sl sl s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\ refund_heap_clear_sl sl h e /\
              (^envmc).prog_addresses = refund_mem_dm_sl sl h e ==>
              ?ms. forge_refundCmlMainStep$arm8_run 27 s = SOME ms /\ ms.PC = sl + 0x1000040D0w /\
                   refund_installed_no_handler ^RMC ms 428 0``));
val _ = ctl "a missing theorem name is rejected" (not (same E "refund_behavior_from_entry_sl" ``T``));
val closure = Theory.ancestry F;
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) (F :: closure));
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else bad := !bad + 1;
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure + 1));
val _ = pr ("IMPORTED_COUNT " ^ Int.toString (!good) ^ " MISMATCH_COUNT " ^ Int.toString (!bad));
val _ = if !bad = 0 then () else raise Fail "import check failed";
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
