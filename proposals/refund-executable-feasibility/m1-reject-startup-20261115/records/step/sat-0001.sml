(* Non-vacuity: one explicit ARMv8 state satisfies cml_main_pre. *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory wordsTheory wordsLib combinTheory alignmentTheory forge_refundCmlMainStepTheory;
fun pr s = print (s ^ "\n");
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_NATIVE_STEP_OUT"));
val _ = new_theory "forge_refundCmlMainSat";
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val pre_def = DB.fetch "forge_refundCmlMainStep" "cml_main_pre_def";
val body = rhs (snd (strip_forall (concl pre_def)));
val code = List.filter (fn c => is_eq c andalso (let val (f, a) = dest_comb (lhs c) in null (free_vars a) andalso type_of (rhs c) = ``:word8`` end handle _ => false))
             (strip_conj body);
val _ = pr ("CODE_BYTES " ^ Int.toString (length code));
fun w64 n = wordsSyntax.mk_wordii (n, 64);
fun le n = List.tabulate (8, fn k => wordsSyntax.mk_wordii ((n div (IntInf.toInt (IntInf.pow (256, k)))) mod 256, 8));
val h0 = 0x200000000; val stk0 = 0x200010000; val e0 = 0x200020000;
val slots = List.concat (map (fn (a, v) => ListPair.zip (List.tabulate (8, fn k => w64 (a + k)), le v))
              [(0x10002C000, h0), (0x10002C008, stk0), (0x10002C010, e0)]);
val pairs = map (fn c => (rand (lhs c), rhs c)) code @ slots;
val mem0 = List.foldl (fn ((a, b), m) => ``(^a =+ ^b) ^m``) ``(K 0w):word64 -> word8`` pairs;
val s0 = ``(ARB:arm8_state) with <| MEM := ^mem0; PC := 0x100004000w; PSTATE := (ARB with EL := 0w); exception := NoException;
            SCTLR_EL1 := (ARB with <| E0E := F; SA0 := F |>); TCR_EL1 := (ARB with <| TBI0 := F; TBI1 := F |>) |>``;
val goal = ``cml_main_pre ^s0 ^(w64 h0) ^(w64 stk0) ^(w64 e0)``;
val sat = prove (goal,
  PURE_ONCE_REWRITE_TAC [pre_def] >> rpt conj_tac >> TRY (EVAL_TAC >> NO_TAC) >>
  rpt strip_tac >> gvs [word_add_n2w, WORD_LO, WORD_LS]);
val ex = store_thm ("cml_main_pre_satisfiable", ``?s h stk e. cml_main_pre s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h``,
  map_every exists_tac [s0, w64 h0, w64 stk0, w64 e0] >> conj_tac >- ACCEPT_TAC sat >> EVAL_TAC);
val _ = (tags "cml_main_pre_satisfiable" ex; pr ("CHECKED cml_main_pre_satisfiable\n" ^ thm_to_string ex));
val _ = export_theory ();
val _ = pr "NATIVE_STEP_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
