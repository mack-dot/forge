(* L2dx-0001.sml: worker A24 (Night-Shift Orchestrator A). Route A, step L2d, EXPLORATION ONLY. NOT RUN. Every tactic
   UNCHECKED. No export_theory. No save_thm: nothing is stored (lemmas are proved by pv = TAC_PROOF without saving, or
   ASSUMEd). Ends with EXPLORE_COMPLETE.
   Parts: (1) harness of routeA-L2d.sml (= L2b-0003.sml lines 51-120) with thmA/thmO replaced by pv, ALT_SECS 60,
   metis 20 s, scratch theory forge_refundRouteA2dExplore; (2) stepper copied from
   orch-A/lout-explore/LOx-0001.sml lines 421-525 (it compiled and ran), NAMED_CONSTS changed; (3) body: every statement
   of routeA-L2d.sml (same text), each explored as named steps (goals printed after each step) and then pv'd.
   Deps: deps-L2c.txt (deps-L2 + forge_refundRouteA2 (L2-0003) + forge_refundRouteA2b (L2b-0003)). *)
open preamble targetSemTheory targetPropsTheory ffiTheory semanticsPropsTheory fsFFITheory basis_ffiTheory TextIOProofTheory
     backendTheory asmPropsTheory lab_to_targetTheory arm8Theory arm8_targetTheory alignmentTheory miscTheory set_sepTheory
     backendProofTheory arm8_configProofTheory wordsLib blastLib forge_refundArm8CompileTheory forge_refundExclusionRealTheory
     forge_refundStartupClauseTheory forge_refundStartupBridgeTheory forge_refundInstalledDomainsTheory forge_refundInstalledAssemblyTheory
     forge_refundFfiFactsTheory forge_refundResidualTheory forge_refundEnvModelTheory forge_refundSourceNonFailTheory
     forge_refundProfileATheory forge_refundSlideEntryTheory forge_refundSlideDomainsTheory forge_refundSlideInstalledTheory
     forge_refundSlideSatTheory forge_refundSlideProfileATheory forge_refundRouteA1Theory;
val _ = Globals.max_print_depth := 60;
(* ===== harness (copied from L2b-0003.sml lines 51-120; names A8 -> A24 only) ===== *)
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
val _ = (load "Timeout"; pr "TIMEOUT_HELPER Timeout.apply loaded")
  handle e => (pr ("TIMEOUT_LOAD_FAILED " ^ General.exnMessage e); raise e);
val _ = metisTools.limit := {time = SOME 20.0, infs = NONE};
val ALT_SECS = 60;
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun trunc n s = if size s <= n then s else String.substring (s, 0, n) ^ " ...";
fun showg tag ((asl, w) : goal) = (pr ("SHOW " ^ tag);
   List.app (fn a => pr ("  ASM " ^ trunc 600 (term_to_string a))) asl;
   pr ("  GOAL " ^ trunc 2500 (term_to_string w)));
fun show_tac tag (g : goal) (ctxt : Context.t) = (showg tag g; ALL_TAC g ctxt);
fun ST tag (tac : tactic) (g : goal) (ctxt : Context.t) = tac g ctxt
  handle e => (showg ("STAGE_FAILED " ^ tag ^ " : " ^ trunc 300 (General.exnMessage e)) g; raise e);
fun CL tag (tac : tactic) (g : goal) (ctxt : Context.t) =
  let val r as (gs, _) = ST tag tac g ctxt in
    if null gs then r
    else (List.app (showg ("UNSOLVED " ^ tag)) gs; raise mk_HOL_ERR "A24" "CL" ("unsolved goals at " ^ tag))
  end;
fun tlim secs (tac : tactic) (g : goal) (ctxt : Context.t) =
  Timeout.apply (Time.fromSeconds (Int.toLarge secs)) (fn () => tac g ctxt) ()
  handle Timeout.TIMEOUT _ => (pr ("TIMEOUT_ALT after " ^ Int.toString secs ^ " s");
                               raise mk_HOL_ERR "A24" "tlim" "time limit");
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundRouteA2dExplore";   (* scratch; never exported *)
val failed = ref ([] : string list);
val problems = ref ([] : string list);
val stmt_bad = ref ([] : string list);
val failed_stmts = ref ([] : (string * term) list);
val diag = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun has_const n tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;
fun names_of_hyps th = map (fn h => case List.find (fn (_, t) => aconv t h) (!failed_stmts) of
                                      SOME (n, _) => n | NONE => "?" ^ trunc 80 (term_to_string h)) (hyp th);
fun tryall name goal tacs =
  let fun go _ [] = raise Fail "all listed tactics failed"
        | go i (t :: ts) =
            (let val th = Tactical.TAC_PROOF (([], goal), tlim ALT_SECS t) in pr ("TACTIC_USED " ^ name ^ " " ^ Int.toString i); th end
             handle e => (pr ("TACTIC_ATTEMPT_FAILED " ^ name ^ " " ^ Int.toString i ^ " " ^ General.exnMessage e); go (i + 1) ts))
  in go 1 tacs end;
(* pv: proves WITHOUT storing (no save_thm). On failure: ASSUME of the statement (printed PV_ASSUMED); a later result
   that needs it carries a hypothesis (printed PV_UNDER_ASSUMED / VALIDATION ... hyps N). *)
fun pv name (goalf : unit -> term) tacs =
  let val goal = goalf () in
    (pr ("PV_BEGIN " ^ name);
     let val th = tryall name goal tacs in
       if null (hyp th) then (pr ("PV_PROVED " ^ name ^ " (not stored)\n" ^ thm_to_string th); th)
       else (pr ("PV_UNDER_ASSUMED " ^ name ^ " " ^ String.concatWith " " (names_of_hyps th)); th) end)
    handle e => (pr ("PV_ASSUMED " ^ name ^ " " ^ General.exnMessage e);
                 failed := name :: !failed; failed_stmts := (name, goal) :: !failed_stmts; ASSUME goal)
  end
  handle e => (pr ("PV_STATEMENT_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
(* forward proof as a tactic (L2c-0001.sml): f builds the theorem; ACCEPT_TAC checks it against the goal *)
fun fwd (f : unit -> thm) (g : goal) (ctxt : Context.t) = ACCEPT_TAC (f ()) g ctxt;
val _ = metisTools.limit := {time = SOME 20.0, infs = NONE};
val STEP_SECS = 60;
type step = string * tactic * tactic list;

(* ---------- printing ---------- *)
val NAMED_CONSTS = ["arm8_run", "ffi_calls_ok", "basis_ffi_oracle", "refund_ffi_contract_on"];
fun named_consts (tms : term list) : term list =
  op_mk_set aconv
    (List.concat (map (find_terms (fn t => is_const t andalso Lib.mem (fst (dest_const t)) NAMED_CONSTS)) tms));
fun const_line (loc : string) (c : term) : string =
  let val {Thy = thy, Name = nm, Ty = ty} = dest_thy_const c
  in "    CONST_IN_" ^ loc ^ " " ^ thy ^ "$" ^ nm ^ " " ^ trunc 300 (type_to_string ty) end;
fun var_line (v : term) : string =
  let val (n, ty) = dest_var v in n ^ trunc 200 (type_to_string ty) end;
fun show_goal (lemma : string) (k : int) ((asl, w) : goal) : unit =
  let
    fun asm_loop _ [] = ()
      | asm_loop j (a :: rest) =
          (pr ("    ASM " ^ Int.toString j ^ " " ^ trunc 1500 (term_to_string a));
           List.app (fn c => pr (const_line ("ASM_" ^ Int.toString j) c)) (named_consts [a]);
           asm_loop (j + 1) rest)
  in
    pr ("  GOAL_BEGIN " ^ lemma ^ " #" ^ Int.toString k ^ " assumptions " ^ Int.toString (length asl) ^
        " (ASM 0 = newest)");
    asm_loop 0 asl;
    pr ("    CONCL " ^ trunc 4000 (term_to_string w));
    List.app (fn c => pr (const_line "CONCL" c)) (named_consts [w]);
    pr ("    FREE_VARS " ^ trunc 1500 (String.concatWith ", " (map var_line (free_varsl (w :: asl)))));
    pr ("  GOAL_END " ^ lemma ^ " #" ^ Int.toString k)
  end;
fun show_goals (lemma : string) (gs : goal list) : unit =
  let
    fun loop _ [] = ()
      | loop k (g :: rest) = (show_goal lemma k g; loop (k + 1) rest)
  in
    pr ("  GOAL_COUNT " ^ Int.toString (length gs));
    loop 1 gs
  end;

(* ---------- the stepper ---------- *)
fun prefix_of (ts : tactic list) : tactic = List.foldl (fn (t, acc) => acc \\ t) ALL_TAC ts;
fun run_ts (ts : tactic list) (g : goal) : goal list * (thm list -> thm) =
  let val ctxt = Context.snapshot ()
  in Timeout.apply (Time.fromSeconds (Int.toLarge STEP_SECS)) (fn () => prefix_of ts g ctxt) () end;
fun check_validation (lemma : string) (gt : term) (v : thm list -> thm) : unit =
  (let val th = v [] in
     pr ("VALIDATION " ^ lemma ^ " concl_aconv_goal " ^ Bool.toString (aconv (concl th) gt) ^
         " hyps " ^ Int.toString (length (hyp th)));
     List.app (fn h => pr ("  VALIDATION_HYP " ^ trunc 400 (term_to_string h))) (hyp th)
   end)
  handle e => pr ("VALIDATION_FAILED " ^ lemma ^ " " ^ trunc 600 (General.exnMessage e));
fun explore0 (lemma : string) (gt : term) (steps : step list) : unit =
  let
    val g0 : goal = ([], gt)
    fun attempt (ts : tactic list) : (goal list * (thm list -> thm)) option * string =
      (SOME (run_ts ts g0), "")
      handle Timeout.TIMEOUT _ => (NONE, "TIMEOUT after " ^ Int.toString STEP_SECS ^ " s")
           | e => (NONE, General.exnMessage e)
    fun finish (n : int) (gs : goal list) (v : thm list -> thm) : unit =
      if null gs then
        (pr ("EXPLORE_CLOSED " ^ lemma ^ " after_steps " ^ Int.toString n);
         check_validation lemma gt v)
      else pr ("EXPLORE_OPEN " ^ lemma ^ " goals " ^ Int.toString (length gs))
    fun loop (i : int) (chosen : tactic list) (gs : goal list) (v : thm list -> thm) (rest : step list) : unit =
      case rest of
        [] => finish (i - 1) gs v
      | ((label, tac, alts) :: more) =>
          (case attempt (chosen @ [tac]) of
             (SOME (gs1, v1), _) =>
               (pr ("STEP " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " goals " ^ Int.toString (length gs1));
                show_goals lemma gs1;
                loop (i + 1) (chosen @ [tac]) gs1 v1 more)
           | (NONE, msg) =>
               (pr ("STEP_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " " ^ trunc 800 msg);
                pr ("GOALS_BEFORE_STEP " ^ lemma ^ " " ^ Int.toString i ^ " count " ^ Int.toString (length gs));
                show_goals lemma gs;
                alt_loop i label chosen more 1 alts))
    and alt_loop (i : int) (label : string) (chosen : tactic list) (more : step list) (k : int)
                 (alts : tactic list) : unit =
      case alts of
        [] => pr ("STEP_STUCK " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label)
      | (a :: others) =>
          (case attempt (chosen @ [a]) of
             (SOME (gs1, v1), _) =>
               (pr ("ALT_WORKS " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " alt " ^ Int.toString k);
                pr ("STEP " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " goals " ^ Int.toString (length gs1) ^
                    " (alt " ^ Int.toString k ^ ")");
                show_goals lemma gs1;
                loop (i + 1) (chosen @ [a]) gs1 v1 more)
           | (NONE, msg) =>
               (pr ("ALT_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " alt " ^ Int.toString k ^ " " ^
                    trunc 800 msg);
                alt_loop i label chosen more (k + 1) others))
    val v0 = (fn (_ : thm list) => raise mk_HOL_ERR "L2dx" "explore" "no step was run") : thm list -> thm
  in
    pr ("EXPLORE_BEGIN " ^ lemma ^ " steps " ^ Int.toString (length steps));
    show_goals lemma [g0];
    loop 1 [] [g0] v0 steps;
    pr ("EXPLORE_END " ^ lemma)
  end;
(* explore : string -> (unit -> term) -> (unit -> step list) -> unit. A parse error or any other exception in
   one exploration prints EXPLORE_ERROR and the script goes on with the next one. *)
fun explore (lemma : string) (goalf : unit -> term) (stepsf : unit -> step list) : unit =
  explore0 lemma (goalf ()) (stepsf ())
  handle e => pr ("EXPLORE_ERROR " ^ lemma ^ " " ^ trunc 800 (General.exnMessage e));
(* ===================================================================================================
   L2dx-0001 BODY (worker A24). EXPLORATION ONLY. Nothing is stored (no save_thm, no export_theory).
   For each lemma of routeA-L2d.sml: (1) explore = named steps, goals printed after each step, alternatives on failure;
   (2) pv = the draft's alternatives under TAC_PROOF, NOT stored; the result (or ASSUME) feeds later lemmas.
   Statements are those of routeA-L2d.sml (same text). Every tactic UNCHECKED. *)
fun fwd (f : unit -> thm) (g : goal) (ctxt : Context.t) = ACCEPT_TAC (f ()) g ctxt;
val _ = pr "MARK INPUTS";
fun A2b n = DB.fetch "forge_refundRouteA2b" n;
val G = A2b "ffi_calls_ok_of_returning_calls";
val CLOSE_RET = A2b "basis_close_return_lengths";
val RMF = A2b "refund_mc_close_fields";
val EXT4 = A2b "refund_names_are_ExtCall";
val RCH = DB.fetch "forge_refundRouteA2" "refund_profile_a_sl_reach";
val calls_def = DB.fetch "forge_refundRouteA2" "ffi_calls_ok_def";
val on_def = DB.fetch "forge_refundRouteA1" "refund_ffi_contract_on_def";
val contract_at_def = DB.fetch "forge_refundSlideProfileA" "refund_ffi_contract_at_def";
val AB = DB.fetch "forge_refundSlideProfileA" "refund_abs_ffi_contract_at";
val _ = List.app (fn (n, th) => pr ("INPUT " ^ n ^ "\n" ^ thm_to_string th))
  [("ffi_calls_ok_of_returning_calls", G), ("basis_close_return_lengths", CLOSE_RET), ("refund_mc_close_fields", RMF),
   ("refund_names_are_ExtCall", EXT4), ("refund_ffi_contract_on_def", on_def)];
val _ = pr "MARK VOK";
val iV = mk_var ("i", ``:num``);
val nbV = mk_var ("nb", ``:word8 list``);
val sV = mk_var ("s", ``:arm8_state``);
fun vok_body i s =
  ``((^i = 0 \/ ^i = 1) ==> 4 <= w2n ((^s).REG 3w)) /\
    (^i = 2 ==> (^s).REG 1w = 8w /\ (^s).REG 3w <> 0w) /\
    (^i = 3 ==> (^s).REG 3w <> 0w)``;
val VokS = list_mk_abs ([iV, nbV, sV], vok_body iV sV);
val _ = pr ("VOK_SHAPE " ^ term_to_string VokS);
(* ---------- statements (text identical to routeA-L2d.sml) ---------- *)
fun rd_len_tm () = ``!c ab fsys nb fsys'. ffi_read c ab fsys = SOME (FFIreturn nb fsys') ==> 4 <= LENGTH ab``;
fun wr_len_tm () = ``!c ab fsys nb fsys'. ffi_write c ab fsys = SOME (FFIreturn nb fsys') ==> 4 <= LENGTH ab``;
fun oi_len_tm () = ``!c ab fsys nb fsys'. ffi_open_in c ab fsys = SOME (FFIreturn nb fsys') ==> 1 <= LENGTH ab``;
fun rd_ret_tm () = ``!ext (st:(mlstring list # IO_fs) ffi_state) c ab st' nb.
      st.oracle = basis_ffi_oracle ext /\ call_FFI st (ExtCall «read») c ab = FFI_return st' nb ==> 4 <= LENGTH ab``;
fun wr_ret_tm () = ``!ext (st:(mlstring list # IO_fs) ffi_state) c ab st' nb.
      st.oracle = basis_ffi_oracle ext /\ call_FFI st (ExtCall «write») c ab = FFI_return st' nb ==> 4 <= LENGTH ab``;
fun oi_ret_tm () = ``!ext (st:(mlstring list # IO_fs) ffi_state) c ab st' nb.
      st.oracle = basis_ffi_oracle ext /\ call_FFI st (ExtCall «open_in») c ab = FFI_return st' nb ==> 1 <= LENGTH ab``;
fun lens_tm () = ``!mc ms1 c ab. mc.target = arm8_target /\ mc.len_reg = 1 /\ mc.len2_reg = 3 /\
                  read_ffi_bytearrays mc ms1 = (SOME c, SOME ab) ==>
                  LENGTH c = w2n (ms1.REG 1w) /\ LENGTH ab = w2n (ms1.REG 3w)``;
fun shape_call_tm () =
  ``!ext mc (ffi1:(mlstring list # IO_fs) ffi_state) ms1 i c ab ffi2 nb.
      mc.target = arm8_target /\ mc.len_reg = 1 /\ mc.len2_reg = 3 /\
      EL 0 mc.ffi_names = ExtCall «read» /\ EL 1 mc.ffi_names = ExtCall «write» /\
      EL 2 mc.ffi_names = ExtCall «close» /\ EL 3 mc.ffi_names = ExtCall «open_in» /\
      ffi1.oracle = basis_ffi_oracle ext /\ read_ffi_bytearrays mc ms1 = (SOME c, SOME ab) /\
      call_FFI ffi1 (EL i mc.ffi_names) c ab = FFI_return ffi2 nb ==>
      ^VokS i nb ms1``;
fun shape_ok_tm () =
  ``!ext k mc (ffi:(mlstring list # IO_fs) ffi_state) ms.
      mc.target = arm8_target /\ mc.len_reg = 1 /\ mc.len2_reg = 3 /\
      (!i. i < LENGTH mc.ffi_entry_pcs ==> ?nm. EL i mc.ffi_names = ExtCall nm) /\
      EL 0 mc.ffi_names = ExtCall «read» /\ EL 1 mc.ffi_names = ExtCall «write» /\
      EL 2 mc.ffi_names = ExtCall «close» /\ EL 3 mc.ffi_names = ExtCall «open_in» /\
      ffi.oracle = basis_ffi_oracle ext ==>
      ffi_calls_ok ^VokS mc ffi k ms``;
fun refs_tm () =
  ``!b envmc ext ffi k ms. ffi.oracle = basis_ffi_oracle ext ==> ffi_calls_ok ^VokS (refund_mc b envmc) ffi k ms``;
fun refst_tm () =
  ``!sl envmc Vok ext cl fs k ms.
      ffi_calls_ok ^VokS (refund_mc (sl + 0x1000040D0w) (envmc with ffi_interfer := refund_ffi_tot Vok envmc.ffi_interfer))
                   (basis_ffi ext cl fs) k ms``;
(* ---------- (1) model facts ---------- *)
val _ = pr "MARK MODEL";
val _ = explore "ffi_read_return_length/A_gvs" rd_len_tm (fn () =>
  [("gen", rpt gen_tac, []),
   ("unfold", simp [ffi_read_def], [rewrite_tac [ffi_read_def]]),
   ("strip", strip_tac, []),
   ("cases", gvs [AllCaseEqs()], [BasicProvers.every_case_tac \\ fs [], fs [AllCaseEqs()]])]);
val _ = explore "ffi_read_return_length/C_lengths" rd_len_tm (fn () =>
  [("gen", rpt gen_tac, []),
   ("split", Cases_on `4 <= LENGTH ab` \\ simp [], []),
   ("four", `LENGTH ab = 0 \/ LENGTH ab = 1 \/ LENGTH ab = 2 \/ LENGTH ab = 3` by decide_tac, []),
   ("lists", gvs [listTheory.LENGTH_EQ_NUM_compute, ffi_read_def],
      [fs [listTheory.LENGTH_EQ_NUM_compute] \\ rveq \\ fs [ffi_read_def]])]);
val RD_LEN = pv "ffi_read_return_length" rd_len_tm
  [(rpt gen_tac >> simp [ffi_read_def] >> strip_tac >> gvs [AllCaseEqs()]),
   (rpt gen_tac >> simp [ffi_read_def] >> BasicProvers.every_case_tac >> simp []),
   (rpt gen_tac >> Cases_on `4 <= LENGTH ab` >> simp [] >>
    `LENGTH ab = 0 \/ LENGTH ab = 1 \/ LENGTH ab = 2 \/ LENGTH ab = 3` by decide_tac >>
    gvs [listTheory.LENGTH_EQ_NUM_compute, ffi_read_def])];
val _ = explore "ffi_write_return_length/A_gvs" wr_len_tm (fn () =>
  [("gen", rpt gen_tac, []),
   ("unfold", simp [ffi_write_def], [rewrite_tac [ffi_write_def]]),
   ("strip", strip_tac, []),
   ("cases", gvs [AllCaseEqs()], [BasicProvers.every_case_tac \\ fs [], fs [AllCaseEqs()]])]);
val WR_LEN = pv "ffi_write_return_length" wr_len_tm
  [(rpt gen_tac >> simp [ffi_write_def] >> strip_tac >> gvs [AllCaseEqs()]),
   (rpt gen_tac >> simp [ffi_write_def] >> BasicProvers.every_case_tac >> simp []),
   (rpt gen_tac >> Cases_on `4 <= LENGTH ab` >> simp [] >>
    `LENGTH ab = 0 \/ LENGTH ab = 1 \/ LENGTH ab = 2 \/ LENGTH ab = 3` by decide_tac >>
    gvs [listTheory.LENGTH_EQ_NUM_compute, ffi_write_def])];
val _ = explore "ffi_open_in_return_length/A_cases" oi_len_tm (fn () =>
  [("gen", rpt gen_tac, []),
   ("cases", Cases_on `ab`, []),
   ("simp", simp [ffi_open_in_def],
      [simp [ffi_open_in_def, optionTheory.OPTION_GUARD_def, optionTheory.OPTION_CHOICE_def],
       rw [ffi_open_in_def]])]);
val _ = explore "ffi_open_in_return_length/B_close_pattern" oi_len_tm (fn () =>
  [("rw", rw [ffi_open_in_def], []),
   ("choice", gvs [OPTION_CHOICE_EQUALS_OPTION], []),
   ("pairs", rpt (pairarg_tac \\ gvs []), []),
   ("arith", TRY decide_tac, [])]);
val OI_LEN = pv "ffi_open_in_return_length" oi_len_tm
  [(rpt gen_tac >> Cases_on `ab` >> simp [ffi_open_in_def]),
   (rw [ffi_open_in_def] >> gvs [OPTION_CHOICE_EQUALS_OPTION] >> rpt (pairarg_tac >> gvs []) >> TRY decide_tac),
   (rpt gen_tac >> Cases_on `ab` >>
    simp [ffi_open_in_def, optionTheory.OPTION_GUARD_def, optionTheory.OPTION_CHOICE_def])];
fun ret_steps lenTh =
  [("intro", rpt gen_tac \\ strip_tac, []),
   ("gvs", gvs [call_FFI_def, basis_ffi_oracle_def, pairTheory.UNCURRY, AllCaseEqs()],
      [fs [call_FFI_def] \\ Cases_on `st.ffi_state` \\ fs [basis_ffi_oracle_def] \\ BasicProvers.every_case_tac \\ fs []]),
   ("len", imp_res_tac lenTh, []),
   ("fs", fs [], [])];
fun ret_tacs lenTh =
  [(rpt gen_tac >> strip_tac >> gvs [call_FFI_def, basis_ffi_oracle_def, pairTheory.UNCURRY, AllCaseEqs()] >>
    imp_res_tac lenTh >> fs []),
   (rpt gen_tac >> strip_tac >> fs [call_FFI_def] >> Cases_on `st.ffi_state` >> fs [basis_ffi_oracle_def] >>
    BasicProvers.every_case_tac >> fs [] >> imp_res_tac lenTh >> fs [])];
val _ = explore "basis_read_return_length" rd_ret_tm (fn () => ret_steps RD_LEN);
val RD_RET = pv "basis_read_return_length" rd_ret_tm (ret_tacs RD_LEN);
val WR_RET = pv "basis_write_return_length" wr_ret_tm (ret_tacs WR_LEN);
val _ = explore "basis_open_in_return_length" oi_ret_tm (fn () => ret_steps OI_LEN);
val OI_RET = pv "basis_open_in_return_length" oi_ret_tm (ret_tacs OI_LEN);
(* ---------- (2) registers ---------- *)
val _ = pr "MARK REGS";
val _ = explore "arm8_ffi_bytearrays_lengths" lens_tm (fn () =>
  [("intro", rpt gen_tac \\ strip_tac, []),
   ("mp", qpat_x_assum `read_ffi_bytearrays _ _ = _` mp_tac, []),
   ("simp", asm_simp_tac (srw_ss()) [read_ffi_bytearrays_def, read_ffi_bytearray_def, arm8_target_def],
      [simp [read_ffi_bytearrays_def, read_ffi_bytearray_def, arm8_target_def]]),
   ("strip", strip_tac, []),
   ("len", imp_res_tac read_bytearray_LENGTH, []),
   ("fs", fs [], [gvs [], simp []])]);
val LENS = pv "arm8_ffi_bytearrays_lengths" lens_tm
  [(rpt gen_tac >> strip_tac >> qpat_x_assum `read_ffi_bytearrays _ _ = _` mp_tac >>
    asm_simp_tac (srw_ss()) [read_ffi_bytearrays_def, read_ffi_bytearray_def, arm8_target_def] >>
    strip_tac >> imp_res_tac read_bytearray_LENGTH >> fs []),
   (rw [read_ffi_bytearrays_def, read_ffi_bytearray_def] >> gvs [arm8_target_def] >>
    imp_res_tac read_bytearray_LENGTH >> gvs [])];
val fin_rw = FIRST [(fs [] >> NO_TAC), decide_tac, metis_tac []];
val fin_close =
  `w2n (ms1.REG 1w) = 8 /\ 1 <= w2n (ms1.REG 3w)` by (FIRST [decide_tac, metis_tac []]) >>
  conj_tac
  >- FIRST [metis_tac [wordsTheory.n2w_w2n],
            (`ms1.REG 1w = n2w (w2n (ms1.REG 1w))` by simp [] >> pop_assum SUBST1_TAC >> asm_simp_tac (srw_ss()) [])]
  >> FIRST [(strip_tac >> fs [] >> NO_TAC), metis_tac [wordsTheory.w2n_eq_0, DECIDE ``~(1 <= 0n)``]];
val fin_oi =
  `1 <= w2n (ms1.REG 3w)` by (FIRST [decide_tac, metis_tac []]) >>
  FIRST [(strip_tac >> fs [] >> NO_TAC), metis_tac [wordsTheory.w2n_eq_0, DECIDE ``~(1 <= 0n)``]];
fun fin_any (g as (_, w) : goal) (ctxt : Context.t) =
  (if is_conj w then fin_close else if is_neg w then fin_oi else fin_rw) g ctxt;
val ret_any = FIRST [drule_all RD_RET >> strip_tac >> fin_rw,
                     drule_all WR_RET >> strip_tac >> fin_rw,
                     drule_all CLOSE_RET >> strip_tac >> fin_close,
                     drule_all OI_RET >> strip_tac >> fin_oi];
val _ = explore "basis_returning_call_has_valid_shape" shape_call_tm (fn () =>
  [("intro", rpt gen_tac \\ strip_tac, []),
   ("beta", BETA_TAC, [ALL_TAC]),
   ("lens", `LENGTH c = w2n (ms1.REG 1w) /\ LENGTH ab = w2n (ms1.REG 3w)` by metis_tac [LENS],
      [drule_all LENS \\ strip_tac]),
   ("split", rpt conj_tac, []),
   ("case", strip_tac, []),
   ("rveq", rveq, [rpt BasicProvers.VAR_EQ_TAC]),
   ("name", qpat_x_assum `call_FFI _ _ _ _ = _` mp_tac \\ asm_rewrite_tac [] \\ strip_tac, [fs []]),
   ("ret", FIRST [drule_all RD_RET \\ strip_tac, drule_all WR_RET \\ strip_tac,
                  drule_all CLOSE_RET \\ strip_tac, drule_all OI_RET \\ strip_tac],
      [FIRST [imp_res_tac RD_RET, imp_res_tac WR_RET, imp_res_tac CLOSE_RET, imp_res_tac OI_RET]]),
   ("finish", fin_any, [FIRST [fin_close, fin_oi, fin_rw]])]);
val SHAPE_CALL = pv "basis_returning_call_has_valid_shape" shape_call_tm
  [(rpt gen_tac >> strip_tac >> BETA_TAC >>
    `LENGTH c = w2n (ms1.REG 1w) /\ LENGTH ab = w2n (ms1.REG 3w)` by metis_tac [LENS] >>
    rpt conj_tac >> strip_tac >> rveq >>
    qpat_x_assum `call_FFI _ _ _ _ = _` mp_tac >> asm_rewrite_tac [] >> strip_tac >>
    CL "shape-call-1" ret_any),
   (rpt gen_tac >> strip_tac >> BETA_TAC >> drule_all LENS >> strip_tac >>
    rpt conj_tac >> strip_tac >> rveq >> fs [] >>
    CL "shape-call-2" ret_any)];
(* ---------- (3) premise 3 from the oracle alone ---------- *)
val _ = pr "MARK CALLS";
val _ = explore "basis_returning_calls_have_valid_shapes" shape_ok_tm (fn () =>
  [("intro", rpt gen_tac \\ strip_tac, []),
   ("G", match_mp_tac G, [irule G]),
   ("names", conj_tac >- first_assum ACCEPT_TAC, [conj_tac >- metis_tac []]),
   ("leaf", rpt gen_tac \\ strip_tac, []),
   ("beta", BETA_TAC, [ALL_TAC]),
   ("spec", qspecl_then [`ext`, `mc`, `ffi1`, `ms1`, `i`, `c`, `ab`, `ffi2`, `nb`] mp_tac SHAPE_CALL, []),
   ("impl", impl_tac >- (rpt conj_tac \\ FIRST [first_assum ACCEPT_TAC, metis_tac []]), []),
   ("accept", disch_then (ACCEPT_TAC o BETA_RULE), [simp [], metis_tac []])]);
val SHAPE_OK = pv "basis_returning_calls_have_valid_shapes" shape_ok_tm
  [(rpt gen_tac >> strip_tac >> match_mp_tac G >> conj_tac >- first_assum ACCEPT_TAC >>
    rpt gen_tac >> strip_tac >> BETA_TAC >>
    qspecl_then [`ext`, `mc`, `ffi1`, `ms1`, `i`, `c`, `ab`, `ffi2`, `nb`] mp_tac SHAPE_CALL >>
    impl_tac >- (rpt conj_tac >> FIRST [first_assum ACCEPT_TAC, metis_tac []]) >>
    disch_then (ACCEPT_TAC o BETA_RULE)),
   (rpt gen_tac >> strip_tac >> match_mp_tac G >> conj_tac >- first_assum ACCEPT_TAC >>
    rpt gen_tac >> strip_tac >> irule SHAPE_CALL >> metis_tac []),
   (rpt gen_tac >> strip_tac >> irule G >> conj_tac >- metis_tac [] >>
    rpt gen_tac >> strip_tac >> BETA_TAC >> metis_tac [BETA_RULE SHAPE_CALL])];
val _ = explore "refund_ffi_calls_ok_shape" refs_tm (fn () =>
  [("intro", rpt strip_tac, []),
   ("mmp", match_mp_tac SHAPE_OK, [irule SHAPE_OK]),
   ("ex", qexists_tac `ext`, [ALL_TAC]),
   ("fs", fs [RMF, EXT4], [rpt conj_tac \\ fs [RMF, EXT4]]),
   ("eval", TRY EVAL_TAC, [])]);
val REFS = pv "refund_ffi_calls_ok_shape" refs_tm
  [(rpt strip_tac >> match_mp_tac SHAPE_OK >> qexists_tac `ext` >> fs [RMF, EXT4] >> TRY EVAL_TAC),
   (rpt strip_tac >> irule SHAPE_OK >> qexists_tac `ext` >> rpt conj_tac >> fs [RMF, EXT4] >> EVAL_TAC)];
val _ = explore "refund_ffi_calls_ok_shape_totalised" refst_tm (fn () =>
  [("gen", rpt gen_tac, []),
   ("mmp", match_mp_tac REFS, [irule REFS]),
   ("ex", qexists_tac `ext`, [ALL_TAC]),
   ("simp", simp [basis_ffi_def], [])]);
val REFST = pv "refund_ffi_calls_ok_shape_totalised" refst_tm
  [(rpt gen_tac >> match_mp_tac REFS >> qexists_tac `ext` >> simp [basis_ffi_def]),
   (rpt gen_tac >> irule REFS >> qexists_tac `ext` >> simp [basis_ffi_def])];
(* ---------- (4) structure and assembly (terms from the stored theorem) ---------- *)
val _ = pr "MARK STRUCT";
val VokV = (case List.find (fn v => fst (dest_var v) = "Vok") (free_vars (concl RCH)) of
              SOME v => v | NONE => raise Fail "Vok is not free in refund_profile_a_sl_reach")
  handle e => (pr ("STRUCT_FAILED Vok " ^ General.exnMessage e); raise e);
val _ = if type_of VokV = type_of VokS then pr "CONTROL_OK VokS has the type of Vok"
        else (pr "STRUCT_FAILED type of VokS"; raise Fail "VokS type");
val RCHS = INST [VokV |-> VokS] RCH;
val (rAnte, rConc) = dest_imp (concl RCHS);
val oldPrems = strip_conj rAnte;
val p3 = (case List.filter (has_const "ffi_calls_ok") oldPrems of
            [p] => p | ps => raise Fail ("premise-3 count " ^ Int.toString (length ps)))
  handle e => (pr ("STRUCT_FAILED p3 " ^ General.exnMessage e); raise e);
val _ = pr ("L2R_THIRD_PREMISE_WITH_VOKS " ^ term_to_string p3);
val p3fv = free_vars p3;
fun p3s_tm () = list_mk_forall (p3fv, p3);
val _ = explore "refund_l2r_third_premise_shape" p3s_tm (fn () =>
  [("gen", rpt gen_tac \\ rpt strip_tac, []),
   ("close", match_mp_tac REFS \\ qexists_tac `ext` \\ simp [basis_ffi_def],
      [MATCH_ACCEPT_TAC REFST, irule REFS \\ simp [basis_ffi_def]])]);
val P3S = pv "refund_l2r_third_premise_shape" p3s_tm
  [(rpt gen_tac >> rpt strip_tac >> match_mp_tac REFS >> qexists_tac `ext` >> simp [basis_ffi_def]),
   (rpt gen_tac >> rpt strip_tac >> MATCH_ACCEPT_TAC REFST),
   (rpt gen_tac >> rpt strip_tac >> irule REFS >> simp [basis_ffi_def])];
fun strip_n 0 t = t | strip_n n t = strip_n (n - 1) (snd (dest_forall t));
val _ = (if aconv (strip_n (length p3fv) (concl P3S)) p3
         then pr "CONTROL_OK P3S is premise 3 of refund_profile_a_sl_reach with Vok := VokS" else bad "P3S-not-the-premise")
        handle e => bad ("P3S-check " ^ General.exnMessage e);
val _ = pr "MARK ASSEMBLY";
val newPrems = List.filter (fn p => not (aconv p p3)) oldPrems;
fun asm_tm () = mk_imp (list_mk_conj newPrems, rConc);
fun build_asm () =
  let val na = list_mk_conj newPrems
      val cs = CONJUNCTS (ASSUME na)
      fun find p = (case List.find (fn th => aconv (concl th) p) cs of
                      SOME th => th | NONE => raise Fail "assembly: premise not found")
      val th3 = SPECL p3fv P3S
      val olds = map (fn p => if aconv p p3 then th3 else find p) oldPrems
  in DISCH na (MP RCHS (LIST_CONJ olds)) end;
val _ = explore "refund_profile_a_sl_shape" asm_tm (fn () =>
  [("fwd", fwd build_asm,
      [strip_tac \\ mp_tac RCHS \\ impl_tac
       >- (rpt conj_tac \\ FIRST [first_assum ACCEPT_TAC, MATCH_ACCEPT_TAC (SPECL p3fv P3S)])
       \\ disch_then ACCEPT_TAC])]);
val ASM = pv "refund_profile_a_sl_shape" asm_tm
  [fwd build_asm,
   (strip_tac >> mp_tac RCHS >> impl_tac
    >- (rpt conj_tac >> FIRST [first_assum ACCEPT_TAC, MATCH_ACCEPT_TAC (SPECL p3fv P3S),
                               (rpt gen_tac >> strip_tac >> MATCH_ACCEPT_TAC REFST)])
    >> disch_then ACCEPT_TAC)];
(* ---------- (5) controls ---------- *)
val _ = pr "MARK CONTROLS";
val MC4 = ``<| prog_addresses := UNIV; shared_addresses := {}; ffi_entry_pcs := [0w; 16w; 32w; 48w];
               ffi_names := [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»];
               ptr_reg := 0; len_reg := 1; ptr2_reg := 2; len2_reg := 3; ffi_interfer := ARB; callee_saved_regs := [];
               next_interfer := ARB; halt_pc := 4w; install_pc := 8w; install_interfer := ARB; target := arm8_target;
               mmio_info := [] |>``;
val FSB = ``<| inode_tbl := []; files := []; infds := []; numchars := LNIL; maxFD := 0 |> : IO_fs``;
val FFIB = ``basis_ffi no_ext [] ^FSB``;
val FFIR = ``<| oracle := (\s st c b. Oracle_return st b); ffi_state := (); io_events := [] |> : unit ffi_state``;
val MSR = ``(ARB:arm8_state) with <| PC := 0w; REG := (\r. if r = 1w then 8w else if r = 3w then 4w else 0w);
                                     MEM := (\a. 0w) |>``;
val MSW = ``(ARB:arm8_state) with <| PC := 16w; REG := (\r. if r = 1w then 8w else if r = 3w then 4w else 0w);
                                     MEM := (\a. 0w) |>``;
val MSR0 = ``(ARB:arm8_state) with <| PC := 0w; REG := (\r. if r = 3w then 4w else 0w); MEM := (\a. 0w) |>``;
val MSU = ``(ARB:arm8_state) with <| PC := 0w; REG := (\r. 0w); MEM := (\a. 0w) |>``;
val MSUc = ``(ARB:arm8_state) with <| PC := 32w; REG := (\r. 0w); MEM := (\a. 0w) |>``;
val Pne0 = ``\i (nb:word8 list) (s:arm8_state). i <> 0``;
val Pne1 = ``\i (nb:word8 list) (s:arm8_state). i <> 1``;
val PF = ``\i (nb:word8 list) (s:arm8_state). F``;
val conc_simp = simp [calls_def, arm8_target_def, find_index_def, read_ffi_bytearrays_def, read_ffi_bytearray_def,
                      read_bytearray_def, call_FFI_def];
val conc_tacs =
  [(conc_simp >> TRY EVAL_TAC),
   (rewrite_tac [calls_def] >> EVAL_TAC),
   (simp [calls_def, arm8_target_def, find_index_def, read_ffi_bytearrays_def, read_ffi_bytearray_def, call_FFI_def,
          basis_ffi_def, basis_ffi_oracle_def, ffi_read_def, ffi_write_def, ffi_close_def] >> EVAL_TAC)];
fun conc_steps () =
  [("simp", conc_simp, [rewrite_tac [calls_def]]),
   ("eval", TRY EVAL_TAC, [])];
fun nvr_tm () = ``~ffi_calls_ok ^Pne0 ^MC4 ^FFIB (SUC 0) ^MSR``;
fun nvrok_tm () = ``ffi_calls_ok ^VokS ^MC4 ^FFIB (SUC 0) ^MSR``;
fun nvw_tm () = ``~ffi_calls_ok ^Pne1 ^MC4 ^FFIB (SUC 0) ^MSW``;
fun nvwok_tm () = ``ffi_calls_ok ^VokS ^MC4 ^FFIB (SUC 0) ^MSW``;
fun nvr0_tm () = ``~ffi_calls_ok ^Pne0 ^MC4 ^FFIB (SUC 0) ^MSR0``;
fun neg_tm () = ``~(^VokS) 2 nb ^MSU /\ ~(^VokS) 0 nb ^MSU /\ ~(^VokS) 1 nb ^MSU /\ ~(^VokS) 3 nb ^MSU /\
                  (^VokS) 0 nb ^MSR /\ (^VokS) 0 nb ^MSR0``;
fun nego_tm () = ``~ffi_calls_ok ^VokS ^MC4 ^FFIR (SUC 0) ^MSU``;
fun nfail_tm () = ``ffi_calls_ok ^PF ^MC4 ^FFIB (SUC 0) ^MSU /\ ffi_calls_ok ^PF ^MC4 ^FFIB (SUC 0) ^MSUc``;
val _ = explore "basis_read_call_returns_at_a_concrete_state" nvr_tm conc_steps;
val _ = explore "shape_predicate_holds_at_the_concrete_read_call" nvrok_tm conc_steps;
val _ = explore "basis_write_call_returns_at_a_concrete_state" nvw_tm conc_steps;
val _ = explore "shape_predicate_holds_at_the_concrete_write_call" nvwok_tm conc_steps;
val _ = explore "basis_read_call_with_conf_length_0_returns" nvr0_tm conc_steps;
val _ = explore "shape_predicate_rejects_u393_and_zero_length_states" neg_tm (fn () =>
  [("simp", simp [], [CONV_TAC (DEPTH_CONV BETA_CONV)]),
   ("eval", TRY EVAL_TAC, [])]);
val _ = explore "shape_predicate_needs_the_basis_oracle" nego_tm conc_steps;
val _ = explore "basis_oracle_fails_at_zero_length_read_and_u393_close" nfail_tm (fn () =>
  [("conj", rpt conj_tac, []), ("simp", conc_simp, [rewrite_tac [calls_def]]), ("eval", TRY EVAL_TAC, [])]);
(* error-byte answers (OPTIONAL in the draft) *)
fun err1_tm () = ``!fsys. ffi_read [] [0w;0w;0w;0w] fsys = SOME (FFIreturn [1w;0w;0w;0w] fsys)``;
fun err2_tm () = ``!fsys. ffi_read [0w;0w;0w;0w;0w;0w;0w;0w] [0w;16w;0w;0w] fsys = SOME (FFIreturn [1w;16w;0w;0w] fsys)``;
fun err3_tm () = ``!fsys. ffi_write [] [0w;0w;0w;0w] fsys = SOME (FFIreturn [1w;0w;0w;0w] fsys)``;
fun err4_tm () = ``!c fsys. ffi_open_in c [0w] fsys = SOME (FFIreturn [1w] fsys)``;
fun err_steps () =
  [("simp", simp [ffi_read_def, ffi_write_def, ffi_open_in_def], [rpt gen_tac \\ EVAL_TAC]),
   ("eval", TRY EVAL_TAC, [])];
val _ = explore "ffi_read_conf_length_0_returns_error_byte" err1_tm err_steps;
val _ = explore "ffi_read_short_array_returns_error_byte" err2_tm err_steps;
val _ = explore "ffi_write_conf_length_0_returns_error_byte" err3_tm err_steps;
val _ = explore "ffi_open_in_one_byte_array_returns_error_byte" err4_tm err_steps;
fun sat_tm () = ``!b dm. refund_ffi_contract_on b dm ^VokS refund_abs_ffi``;
val _ = explore "remaining_premise_met_by_the_abstract_effect" sat_tm (fn () =>
  [("unfold", rpt gen_tac \\ rewrite_tac [on_def] \\ rpt gen_tac \\ strip_tac, []),
   ("ab", mp_tac (Q.SPECL [`b`, `dm`] AB) \\ rewrite_tac [contract_at_def], []),
   ("spec", disch_then (qspecl_then [`k`, `index`, `new_bytes`, `ms2`, `t1`, `bytes`, `bytes2`] mp_tac), []),
   ("impl", impl_tac >- (rpt conj_tac \\ first_assum ACCEPT_TAC), [impl_tac >- metis_tac []]),
   ("accept", disch_then ACCEPT_TAC, [metis_tac []])]);
(* ---------- (6) structural checks and the remaining premise (printed; nothing stored) ---------- *)
val _ = pr "MARK REMAINING";
val _ = (let
  val (asmAnte, asmConc) = dest_imp (concl ASM)
  val newA = strip_conj asmAnte
  val origConc = snd (dest_imp (concl RCH))
  val _ = pr ("ASM_HYPS " ^ Int.toString (length (hyp ASM)))
  val _ = if aconv asmConc origConc then pr "CONTROL_OK ASSEMBLY conclusion is term-identical to the stored conclusion"
          else bad "ASSEMBLY-conclusion"
  val _ = if not (has_const "ffi_calls_ok" asmAnte) then pr "CONTROL_OK ASSEMBLY premises do not mention ffi_calls_ok"
          else bad "ASSEMBLY-ffi_calls_ok"
  val _ = if not (free_in VokV (concl ASM)) then pr "CONTROL_OK ASSEMBLY does not mention the variable Vok"
          else bad "ASSEMBLY-Vok-free"
  val _ = pr ("ASSEMBLY_PREMISES " ^ Int.toString (length newA) ^ " of stored " ^ Int.toString (length oldPrems))
  val contractPs = List.filter (has_const "refund_ffi_contract_on") newA
  val interfPs = List.filter (has_const "interference_ok") newA
  val _ = List.app (fn t => pr ("REMAINING_NATIVE_PREMISE " ^ term_to_string t)) contractPs
  val _ = List.app (fn t => pr ("REMAINING_INTERFERENCE_PREMISE " ^ term_to_string t)) interfPs
  val _ = List.app (fn t => pr ("REMAINING_NATIVE_PREMISE_UNFOLDED " ^
            term_to_string (rhs (concl ((REWRITE_CONV [on_def] THENC DEPTH_CONV BETA_CONV) t))))) contractPs
  val _ = pr ("ASSEMBLY_FREE_VARS " ^ String.concatWith " " (map (fst o dest_var) (free_vars (concl ASM))))
  in () end) handle e => pr ("REMAINING_PRINT_FAILED " ^ General.exnMessage e);
val _ = pr ("PV_FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = pr ("PROBLEMS " ^ String.concatWith " " (rev (!problems)));
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
