(* routeA-L2d.sml: worker A24 (Night-Shift Orchestrator A). Route A, step L2d. DRAFT. NOT RUN. Every tactic UNCHECKED.
   It will be finalised as a faithful replay of the exploration L2dx-0001 (same statements; the step sequences that
   the exploration log shows to close).
   Theory forge_refundRouteA2d. Parents (by loading, deps-L2c.txt): forge_refundRouteA1, forge_refundRouteA2 (L2-0003),
   forge_refundRouteA2b (L2b-0003).
   Idea. The basis oracle (basis_ffiScript.sml 19-59; fsFFIScript.sml 265-277, 307-362) RETURNS at the four refund FFI
   names only at argument shapes that pass its own checks; elsewhere it gives Oracle_final FFI_failed. Read from the
   definitions, a RETURNING call has exactly (no more):
     read     (fsFFIScript 307-327): returns iff 4 <= LENGTH bytes (any conf; LENGTH conf <> 8 gives the error byte)
     write    (333-348):             returns iff 4 <= LENGTH bytes (any conf; error byte as for read)
     close    (351-362):             returns iff 1 <= LENGTH bytes /\ LENGTH conf = 8
     open_in  (265-277):             returns iff 0 < LENGTH bytes (1..8 bytes, or no NUL in conf: error byte)
   With LENGTH conf = w2n x1 and LENGTH bytes = w2n x3 (read_ffi_bytearray, read_bytearray_LENGTH), the shape predicate
     VokS = \i nb s. ((i = 0 \/ i = 1) ==> 4 <= w2n (s.REG 3w)) /\ (i = 2 ==> s.REG 1w = 8w /\ s.REG 3w <> 0w) /\
                     (i = 3 ==> s.REG 3w <> 0w)
   meets premise 3 of refund_profile_a_sl_reach FROM THE ORACLE ALONE, for every ext cl fs (the four names are
   dispatched before the ext fall-through, basis_ffiScript.sml 22-55; no premise on ext). No program behaviour (no L3).
   Assembly refund_profile_a_sl_shape: refund_profile_a_sl_reach with Vok := VokS and premise 3 discharged.
   Harness: the one of L2b-0003.sml (sha256 cb6efb52...af95), lines 51-120, copied; fwd from L2c-0001.sml.
   FINAL (case L2d-0001): FAITHFUL REPLAY of exploration L2dx-0001 (actual exit 0, EXPLORE_COMPLETE; source sha256
   183b8ded...3ae9). Each required lemma keeps exactly the alternative printed TACTIC_USED <name> 1 (pv) or the step
   sequence printed EXPLORE_CLOSED ... hyps 0. Changes against L2dx: none in statements; PF typed (i:num);
   ERR2 and NFAIL OPTIONAL (not closed / not explored); new OPTIONAL section MODEL_FRAME (MG-0001 construction).
   Deps: deps-MG.txt (superset of deps-L2c.txt). NOT RUN. UNCHECKED. *)
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
val _ = metisTools.limit := {time = SOME 30.0, infs = NONE};
val ALT_SECS = 180;
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
val _ = new_theory "forge_refundRouteA2d";
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
fun thmA name goal tacs =
  let val _ = pr ("BEGIN " ^ name)
      fun fail_with msg = (pr ("LEMMA_FAILED " ^ name ^ " " ^ msg); failed := name :: !failed;
                           failed_stmts := (name, goal) :: !failed_stmts; ASSUME goal)
  in (let val th0 = tryall name goal tacs in
        if null (hyp th0) then (let val th = save_thm (name, th0) in chk name th; th end)
        else (pr ("DIAG_OK_UNDER " ^ name ^ " assumed: " ^ String.concatWith " " (names_of_hyps th0));
              diag := name :: !diag; fail_with "(diagnostic only: proved only under failed lemmas)") end)
     handle e => fail_with (General.exnMessage e)
  end;
fun thmO name goal tacs =
  (pr ("BEGIN " ^ name);
   let val th0 = tryall name goal tacs in
     if null (hyp th0) then (let val th = save_thm (name, th0) in chk name th; SOME th end)
     else (pr ("OPTIONAL_FAILED " ^ name ^ " DIAG_OK_UNDER " ^ String.concatWith " " (names_of_hyps th0)); NONE) end)
  handle e => (pr ("OPTIONAL_FAILED " ^ name ^ " " ^ General.exnMessage e); NONE);
(* forward proof as a tactic (L2c-0001.sml): f builds the theorem; ACCEPT_TAC checks it against the goal *)
fun fwd (f : unit -> thm) (g : goal) (ctxt : Context.t) = ACCEPT_TAC (f ()) g ctxt;
(* ================= stored inputs ================= *)
val _ = pr "MARK INPUTS";
fun A2b n = DB.fetch "forge_refundRouteA2b" n;
val G = A2b "ffi_calls_ok_of_returning_calls";
val CLOSE_RET = A2b "basis_close_return_lengths";          (* LENGTH c = 8 /\ 1 <= LENGTH ab *)
val RMF = A2b "refund_mc_close_fields";
val EXT4 = A2b "refund_names_are_ExtCall";
val RCH = DB.fetch "forge_refundRouteA2" "refund_profile_a_sl_reach";
val calls_def = DB.fetch "forge_refundRouteA2" "ffi_calls_ok_def";
val on_def = DB.fetch "forge_refundRouteA1" "refund_ffi_contract_on_def";
val contract_at_def = DB.fetch "forge_refundSlideProfileA" "refund_ffi_contract_at_def";
val AB = DB.fetch "forge_refundSlideProfileA" "refund_abs_ffi_contract_at";
val _ = List.app (fn (n, th) => pr ("INPUT " ^ n ^ "\n" ^ thm_to_string th))
  [("ffi_calls_ok_of_returning_calls", G), ("basis_close_return_lengths", CLOSE_RET), ("refund_mc_close_fields", RMF),
   ("refund_ffi_contract_on_def", on_def)];
(* ================= the shape predicate (a lambda; no definition) ================= *)
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
(* ================= per-name facts of the model (fsFFIScript.sml) ================= *)
val _ = pr "MARK MODEL";
val RD_LEN = thmA "ffi_read_return_length"
  ``!c ab fsys nb fsys'. ffi_read c ab fsys = SOME (FFIreturn nb fsys') ==> 4 <= LENGTH ab``
  [(rpt gen_tac >> simp [ffi_read_def] >> strip_tac >> gvs [AllCaseEqs()])];
val WR_LEN = thmA "ffi_write_return_length"
  ``!c ab fsys nb fsys'. ffi_write c ab fsys = SOME (FFIreturn nb fsys') ==> 4 <= LENGTH ab``
  [(rpt gen_tac >> simp [ffi_write_def] >> strip_tac >> gvs [AllCaseEqs()])];
val OI_LEN = thmA "ffi_open_in_return_length"
  ``!c ab fsys nb fsys'. ffi_open_in c ab fsys = SOME (FFIreturn nb fsys') ==> 1 <= LENGTH ab``
  [(rpt gen_tac >> Cases_on `ab` >> simp [ffi_open_in_def])];
(* basis oracle: a returning call at name N has the length fact (pattern: L2b basis_close_return_lengths, passed) *)
fun ret_tacs lenTh =
  [(rpt gen_tac >> strip_tac >> gvs [call_FFI_def, basis_ffi_oracle_def, pairTheory.UNCURRY, AllCaseEqs()] >>
    imp_res_tac lenTh >> fs [])];
val RD_RET = thmA "basis_read_return_length"
  ``!ext (st:(mlstring list # IO_fs) ffi_state) c ab st' nb.
      st.oracle = basis_ffi_oracle ext /\ call_FFI st (ExtCall «read») c ab = FFI_return st' nb ==> 4 <= LENGTH ab``
  (ret_tacs RD_LEN);
val WR_RET = thmA "basis_write_return_length"
  ``!ext (st:(mlstring list # IO_fs) ffi_state) c ab st' nb.
      st.oracle = basis_ffi_oracle ext /\ call_FFI st (ExtCall «write») c ab = FFI_return st' nb ==> 4 <= LENGTH ab``
  (ret_tacs WR_LEN);
val OI_RET = thmA "basis_open_in_return_length"
  ``!ext (st:(mlstring list # IO_fs) ffi_state) c ab st' nb.
      st.oracle = basis_ffi_oracle ext /\ call_FFI st (ExtCall «open_in») c ab = FFI_return st' nb ==> 1 <= LENGTH ab``
  (ret_tacs OI_LEN);
(* ================= registers ================= *)
val _ = pr "MARK REGS";
val LENS = thmA "arm8_ffi_bytearrays_lengths"
  ``!mc ms1 c ab. mc.target = arm8_target /\ mc.len_reg = 1 /\ mc.len2_reg = 3 /\
                  read_ffi_bytearrays mc ms1 = (SOME c, SOME ab) ==>
                  LENGTH c = w2n (ms1.REG 1w) /\ LENGTH ab = w2n (ms1.REG 3w)``
  [(rpt gen_tac >> strip_tac >> qpat_x_assum `read_ffi_bytearrays _ _ = _` mp_tac >>
    asm_simp_tac (srw_ss()) [read_ffi_bytearrays_def, read_ffi_bytearray_def, arm8_target_def] >>
    strip_tac >> imp_res_tac read_bytearray_LENGTH >> fs [])];
(* the four case endings *)
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
(* dispatch by goal shape: conjunction = close, negation = open_in, else read/write *)
fun fin_any (g as (_, w) : goal) (ctxt : Context.t) =
  (if is_conj w then fin_close else if is_neg w then fin_oi else fin_rw) g ctxt;
val ret_any = FIRST [drule_all RD_RET >> strip_tac >> fin_rw,
                     drule_all WR_RET >> strip_tac >> fin_rw,
                     drule_all CLOSE_RET >> strip_tac >> fin_close,
                     drule_all OI_RET >> strip_tac >> fin_oi];
val SHAPE_CALL_goal =
  ``!ext mc (ffi1:(mlstring list # IO_fs) ffi_state) ms1 i c ab ffi2 nb.
      mc.target = arm8_target /\ mc.len_reg = 1 /\ mc.len2_reg = 3 /\
      EL 0 mc.ffi_names = ExtCall «read» /\ EL 1 mc.ffi_names = ExtCall «write» /\
      EL 2 mc.ffi_names = ExtCall «close» /\ EL 3 mc.ffi_names = ExtCall «open_in» /\
      ffi1.oracle = basis_ffi_oracle ext /\ read_ffi_bytearrays mc ms1 = (SOME c, SOME ab) /\
      call_FFI ffi1 (EL i mc.ffi_names) c ab = FFI_return ffi2 nb ==>
      ^VokS i nb ms1``;
(* the conclusion is the beta-redex VokS i nb ms1 (no antiquote with free variables); the proofs start with BETA_TAC *)
val SHAPE_CALL = thmA "basis_returning_call_has_valid_shape" SHAPE_CALL_goal
  [(rpt gen_tac >> strip_tac >> BETA_TAC >>
    `LENGTH c = w2n (ms1.REG 1w) /\ LENGTH ab = w2n (ms1.REG 3w)` by metis_tac [LENS] >>
    rpt conj_tac >> strip_tac >> rveq >>
    qpat_x_assum `call_FFI _ _ _ _ = _` mp_tac >> asm_rewrite_tac [] >> strip_tac >>
    CL "shape-call-1" ret_any)];
(* ================= premise 3 from the oracle alone ================= *)
val _ = pr "MARK CALLS";
val SHAPE_OK_goal =
  ``!ext k mc (ffi:(mlstring list # IO_fs) ffi_state) ms.
      mc.target = arm8_target /\ mc.len_reg = 1 /\ mc.len2_reg = 3 /\
      (!i. i < LENGTH mc.ffi_entry_pcs ==> ?nm. EL i mc.ffi_names = ExtCall nm) /\
      EL 0 mc.ffi_names = ExtCall «read» /\ EL 1 mc.ffi_names = ExtCall «write» /\
      EL 2 mc.ffi_names = ExtCall «close» /\ EL 3 mc.ffi_names = ExtCall «open_in» /\
      ffi.oracle = basis_ffi_oracle ext ==>
      ffi_calls_ok ^VokS mc ffi k ms``;
val SHAPE_OK = thmA "basis_returning_calls_have_valid_shapes" SHAPE_OK_goal
  [(rpt gen_tac >> strip_tac >> match_mp_tac G >> conj_tac >- first_assum ACCEPT_TAC >>
    rpt gen_tac >> strip_tac >> BETA_TAC >>
    qspecl_then [`ext`, `mc`, `ffi1`, `ms1`, `i`, `c`, `ab`, `ffi2`, `nb`] mp_tac SHAPE_CALL >>
    impl_tac >- (rpt conj_tac >> FIRST [first_assum ACCEPT_TAC, metis_tac []]) >>
    disch_then (ACCEPT_TAC o BETA_RULE))];
val REFS = thmA "refund_ffi_calls_ok_shape"
  ``!b envmc ext ffi k ms. ffi.oracle = basis_ffi_oracle ext ==> ffi_calls_ok ^VokS (refund_mc b envmc) ffi k ms``
  [(rpt strip_tac >> match_mp_tac SHAPE_OK >> qexists_tac `ext` >> fs [RMF, EXT4] >> TRY EVAL_TAC)];
val REFST = thmA "refund_ffi_calls_ok_shape_totalised"
  ``!sl envmc Vok ext cl fs k ms.
      ffi_calls_ok ^VokS (refund_mc (sl + 0x1000040D0w) (envmc with ffi_interfer := refund_ffi_tot Vok envmc.ffi_interfer))
                   (basis_ffi ext cl fs) k ms``
  [(rpt gen_tac >> match_mp_tac REFS >> qexists_tac `ext` >> simp [basis_ffi_def])];
(* ================= structure: terms from the stored theorem ================= *)
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
val P3S = thmA "refund_l2r_third_premise_shape" (list_mk_forall (p3fv, p3))
  [(rpt gen_tac >> rpt strip_tac >> match_mp_tac REFS >> qexists_tac `ext` >> simp [basis_ffi_def])];
fun strip_n 0 t = t | strip_n n t = strip_n (n - 1) (snd (dest_forall t));
val _ = if aconv (strip_n (length p3fv) (concl P3S)) p3
        then pr "CONTROL_OK P3S is premise 3 of refund_profile_a_sl_reach with Vok := VokS (term from the stored theorem)"
        else bad "P3S-not-the-premise";
(* ================= assembly ================= *)
val _ = pr "MARK ASSEMBLY";
val newPrems = List.filter (fn p => not (aconv p p3)) oldPrems;
val ASM_goal = mk_imp (list_mk_conj newPrems, rConc);
fun build_asm () =
  let val na = list_mk_conj newPrems
      val cs = CONJUNCTS (ASSUME na)
      fun find p = (case List.find (fn th => aconv (concl th) p) cs of
                      SOME th => th | NONE => raise Fail "assembly: premise not found")
      val th3 = SPECL p3fv P3S
      val olds = map (fn p => if aconv p p3 then th3 else find p) oldPrems
  in DISCH na (MP RCHS (LIST_CONJ olds)) end;
val ASM = thmA "refund_profile_a_sl_shape" ASM_goal [fwd build_asm];
(* ================= controls ================= *)
val _ = pr "MARK CONTROLS";
val MC4 = ``<| prog_addresses := UNIV; shared_addresses := {}; ffi_entry_pcs := [0w; 16w; 32w; 48w];
               ffi_names := [ExtCall «read»; ExtCall «write»; ExtCall «close»; ExtCall «open_in»];
               ptr_reg := 0; len_reg := 1; ptr2_reg := 2; len2_reg := 3; ffi_interfer := ARB; callee_saved_regs := [];
               next_interfer := ARB; halt_pc := 4w; install_pc := 8w; install_interfer := ARB; target := arm8_target;
               mmio_info := [] |>``;
val FSB = ``<| inode_tbl := []; files := []; infds := []; numchars := LNIL; maxFD := 0 |> : IO_fs``;
val FFIB = ``basis_ffi no_ext [] ^FSB``;
val FFIR = ``<| oracle := (\s st c b. Oracle_return st b); ffi_state := (); io_events := [] |> : unit ffi_state``;
(* x1 = 8, x3 = 4 at the read entry (pc 0w) and at the write entry (pc 16w) *)
val MSR = ``(ARB:arm8_state) with <| PC := 0w; REG := (\r. if r = 1w then 8w else if r = 3w then 4w else 0w);
                                     MEM := (\a. 0w) |>``;
val MSW = ``(ARB:arm8_state) with <| PC := 16w; REG := (\r. if r = 1w then 8w else if r = 3w then 4w else 0w);
                                     MEM := (\a. 0w) |>``;
(* read with configuration length 0 (x1 = 0) and x3 = 4: shape-valid; the model returns the error byte *)
val MSR0 = ``(ARB:arm8_state) with <| PC := 0w; REG := (\r. if r = 3w then 4w else 0w); MEM := (\a. 0w) |>``;
(* all registers 0: a read with x3 = 0 (pc 0w) and the U393 close state x1 = 0, x3 = 0 (pc 32w) *)
val MSU = ``(ARB:arm8_state) with <| PC := 0w; REG := (\r. 0w); MEM := (\a. 0w) |>``;
val MSUc = ``(ARB:arm8_state) with <| PC := 32w; REG := (\r. 0w); MEM := (\a. 0w) |>``;
val Pne0 = ``\i (nb:word8 list) (s:arm8_state). i <> 0``;
val Pne1 = ``\i (nb:word8 list) (s:arm8_state). i <> 1``;
val PF = ``\(i:num) (nb:word8 list) (s:arm8_state). F``;   (* L2dx: untyped i gave a type error *)
(* L2b conc_tacs (alternative 1 passed for NV-B and N2 in L2b-0003) *)
val conc_tacs =
  [(simp [calls_def, arm8_target_def, find_index_def, read_ffi_bytearrays_def, read_ffi_bytearray_def,
          read_bytearray_def, call_FFI_def] >> TRY EVAL_TAC)];
val NVR = thmA "basis_read_call_returns_at_a_concrete_state" ``~ffi_calls_ok ^Pne0 ^MC4 ^FFIB (SUC 0) ^MSR`` conc_tacs;
val NVRok = thmA "shape_predicate_holds_at_the_concrete_read_call" ``ffi_calls_ok ^VokS ^MC4 ^FFIB (SUC 0) ^MSR`` conc_tacs;
val NVW = thmA "basis_write_call_returns_at_a_concrete_state" ``~ffi_calls_ok ^Pne1 ^MC4 ^FFIB (SUC 0) ^MSW`` conc_tacs;
val NVWok = thmA "shape_predicate_holds_at_the_concrete_write_call" ``ffi_calls_ok ^VokS ^MC4 ^FFIB (SUC 0) ^MSW`` conc_tacs;
(* the read with x1 = 0 RETURNS under the basis oracle (error byte): premise 2 is demanded there *)
val NVR0 = thmA "basis_read_call_with_conf_length_0_returns" ``~ffi_calls_ok ^Pne0 ^MC4 ^FFIB (SUC 0) ^MSR0`` conc_tacs;
val NEG = thmA "shape_predicate_rejects_u393_and_zero_length_states"
  ``~(^VokS) 2 nb ^MSU /\ ~(^VokS) 0 nb ^MSU /\ ~(^VokS) 1 nb ^MSU /\ ~(^VokS) 3 nb ^MSU /\
    (^VokS) 0 nb ^MSR /\ (^VokS) 0 nb ^MSR0``
  [(simp [] >> TRY EVAL_TAC)];
(* the shape predicate does not hold by itself: under an always-returning oracle the zero-length read violates it *)
val NEGO = thmA "shape_predicate_needs_the_basis_oracle" ``~ffi_calls_ok ^VokS ^MC4 ^FFIR (SUC 0) ^MSU`` conc_tacs;
(* under the basis oracle the zero-length read and the U393 close call do NOT return (FFI_failed) *)
(* OPTIONAL: not explored (L2dx statement type error, now fixed in PF); UNCHECKED *)
val NFAIL = thmO "basis_oracle_fails_at_zero_length_read_and_u393_close"
  ``ffi_calls_ok ^PF ^MC4 ^FFIB (SUC 0) ^MSU /\ ffi_calls_ok ^PF ^MC4 ^FFIB (SUC 0) ^MSUc``
  (map (fn t => rpt conj_tac >> t) conc_tacs);
(* error-byte answers at shape-valid calls (the states where the ORIGINAL C aborts). L2dx: ERR1, ERR3, ERR4 closed with
   simp then TRY EVAL_TAC; ERR2 was left at `!fsys. T` after EVAL_TAC, so it is OPTIONAL with a final simp [] (UNCHECKED). *)
val err_tacs = [(simp [ffi_read_def, ffi_write_def, ffi_open_in_def] >> TRY EVAL_TAC)];
val ERR1 = thmA "ffi_read_conf_length_0_returns_error_byte"
  ``!fsys. ffi_read [] [0w;0w;0w;0w] fsys = SOME (FFIreturn [1w;0w;0w;0w] fsys)`` err_tacs;
val ERR2 = thmO "ffi_read_short_array_returns_error_byte"
  ``!fsys. ffi_read [0w;0w;0w;0w;0w;0w;0w;0w] [0w;16w;0w;0w] fsys = SOME (FFIreturn [1w;16w;0w;0w] fsys)``
  [(simp [ffi_read_def, ffi_write_def, ffi_open_in_def] >> TRY EVAL_TAC >> simp [])];
val ERR3 = thmA "ffi_write_conf_length_0_returns_error_byte"
  ``!fsys. ffi_write [] [0w;0w;0w;0w] fsys = SOME (FFIreturn [1w;0w;0w;0w] fsys)`` err_tacs;
val ERR4 = thmA "ffi_open_in_one_byte_array_returns_error_byte"
  ``!c fsys. ffi_open_in c [0w] fsys = SOME (FFIreturn [1w] fsys)`` err_tacs;
(* the remaining premise is satisfiable (by the stored abstract effect); L2dx: closed in 5 steps *)
val SAT = thmA "remaining_premise_met_by_the_abstract_effect"
  ``!b dm. refund_ffi_contract_on b dm ^VokS refund_abs_ffi``
  [(rpt gen_tac >> rewrite_tac [on_def] >> rpt gen_tac >> strip_tac >>
    mp_tac (Q.SPECL [`b`, `dm`] AB) >> rewrite_tac [contract_at_def] >>
    disch_then (qspecl_then [`k`, `index`, `new_bytes`, `ms2`, `t1`, `bytes`, `bytes2`] mp_tac) >>
    impl_tac >- (rpt conj_tac >> first_assum ACCEPT_TAC) >> disch_then ACCEPT_TAC)];
(* ===== structural checks of the assembly ===== *)
val (asmAnte, asmConc) = dest_imp (concl ASM);
val newA = strip_conj asmAnte;
val origConc = snd (dest_imp (concl RCH));
val _ = if aconv asmConc origConc
        then pr "CONTROL_OK ASSEMBLY conclusion is term-identical to the conclusion of the stored refund_profile_a_sl_reach"
        else bad "ASSEMBLY-conclusion";
val _ = if not (free_in VokV (concl ASM)) then pr "CONTROL_OK ASSEMBLY does not mention the variable Vok"
        else bad "ASSEMBLY-Vok-free";
val _ = if length newA + 1 = length oldPrems andalso ListPair.all (fn (x, y) => aconv x y) (newA, newPrems)
        then pr ("CONTROL_OK ASSEMBLY premises = premises of refund_profile_a_sl_reach with Vok := VokS minus premise 3 ("
                 ^ Int.toString (length newA) ^ " of " ^ Int.toString (length oldPrems) ^ ")")
        else bad "ASSEMBLY-premises";
val _ = if not (has_const "ffi_calls_ok" asmAnte) then pr "CONTROL_OK ASSEMBLY premises do not mention ffi_calls_ok"
        else bad "ASSEMBLY-ffi_calls_ok";
val _ = if not (has_const "basis_ffi_oracle" VokS) andalso not (has_const "evaluate" (concl SHAPE_OK))
        then pr "CONTROL_OK VokS mentions no oracle; the premise-3 theorem mentions no program run (no L3)"
        else bad "VokS-scope";
val _ = if aconv (concl SHAPE_CALL) SHAPE_CALL_goal andalso aconv (concl SHAPE_OK) SHAPE_OK_goal
        then pr "CONTROL_OK SHAPE_CALL and SHAPE_OK are the literal statements of this file" else bad "literal";
val _ = if List.all is_neg [concl NVR, concl NVW, concl NVR0, concl NEGO]
        then pr "CONTROL_OK NVR, NVW, NVR0, NEGO are negations (the calls RETURN)" else bad "negations";
val contractPs = List.filter (has_const "refund_ffi_contract_on") newA;
val interfPs = List.filter (has_const "interference_ok") newA;
val _ = List.app (fn t => pr ("REMAINING_NATIVE_PREMISE " ^ term_to_string t)) contractPs;
val _ = List.app (fn t => pr ("REMAINING_INTERFERENCE_PREMISE " ^ term_to_string t)) interfPs;
val _ = (List.app (fn t => pr ("REMAINING_NATIVE_PREMISE_UNFOLDED " ^
           term_to_string (rhs (concl ((REWRITE_CONV [on_def] THENC DEPTH_CONV BETA_CONV) t))))) contractPs)
        handle e => pr ("UNFOLD_PRINT_FAILED " ^ General.exnMessage e);
val _ = if length contractPs = 1 then pr "CONTROL_OK exactly one contract premise" else bad "contract-premise-count";
val _ = pr ("ASSEMBLY_FREE_VARS " ^ String.concatWith " " (map (fst o dest_var) (free_vars (concl ASM))));
(* ================= OPTIONAL: the composed model theorem at ext := no_ext (MG-0001 construction) =================
   Inputs (deps-MG.txt): forge_refundModelFrame (MF-0002) refund_model_frame_decision_reach (M1b),
   refund_model_frame_meets_exported_contract (M3); forge_refundExportedContract exported_contract_on_refund_fields.
   UP and UPC are the passed MG-0001 proofs (MG-0001.sml lines 117-150), copied with their two alternatives and stored
   here under l2d_ names (forge_refundModelFrameEvents is not in deps-MG). G3 replays MG-0001 G1 with Vok := VokS and
   premise 3 given by REFST. Every item OPTIONAL: a failure prints OPTIONAL_FAILED and does not block the export. *)
val _ = pr "MARK MODEL_FRAME";
val MF_results = (let
  fun MF n = DB.fetch "forge_refundModelFrame" n
  val M1B = MF "refund_model_frame_decision_reach"
  val M3 = MF "refund_model_frame_meets_exported_contract"
  val ECON0 = DB.fetch "forge_refundExportedContract" "exported_contract_on_refund_fields"
  fun at_no_ext th =
    let val v = valOf (List.find (fn v => fst (dest_var v) = "ext") (free_vars (concl th)))
        val c = mk_thy_const {Thy = "basis_ffi", Name = "no_ext", Ty = type_of v}
    in INST [v |-> c] th end
  val ASM_NE = at_no_ext ASM
  val VokM = valOf (List.find (fn v => fst (dest_var v) = "Vok") (free_vars (concl M1B)))
  val M1B_S = INST [VokM |-> VokS] M1B
  val (ANTE_S, M1BC) = dest_imp (concl M1B_S)
  val M3C = snd (dest_imp (concl M3))
  fun pieces c =
    let val (ms, B) = dest_exists c
        val (C1, ALLB) = dest_conj B
        val (b, I) = dest_forall ALLB
        val (_, E) = dest_imp I
        val (tio, body) = strip_exists E
        val (_, N) = dest_conj body
    in (ms, b, List.nth (tio, 0), List.nth (tio, 1), N) end
  val (msv, bv, tv, iov, N1) = pieces M1BC
  val (msv3, bv3, tv3, iov3, N3) = pieces M3C
  val _ = if aconv msv msv3 andalso aconv bv bv3 andalso aconv tv tv3 andalso aconv iov iov3
          then pr "CONTROL_OK M1b and M3 conclusions use the same bound variables" else bad "MF-bound-variables-differ"
  val gv3 = fst (dest_forall N3)
  fun fv n = List.find (fn v => fst (dest_var v) = n) (free_vars (concl ECON0))
  val ECON = INST (List.mapPartial (fn (n, n') => case fv n of SOME v => SOME (v |-> mk_var (n', type_of v)) | NONE => NONE)
                     [("h", "dafny_heap"), ("env", "dafny_env")]) ECON0
  val UPo = thmO "l2d_frame_contract_upgrade" (mk_imp (N1, N3))
     [DISCH_TAC \\ X_GEN_TAC gv3 \\ DISCH_TAC
        \\ first_x_assum (fn th => first_assum (STRIP_ASSUME_TAC o MATCH_MP th))
        \\ CONJ_TAC >- FIRST_ASSUM ACCEPT_TAC
        \\ CONJ_TAC >- FIRST_ASSUM ACCEPT_TAC
        \\ rpt gen_tac \\ DISCH_TAC \\ MATCH_MP_TAC ECON \\ metis_tac [],
      DISCH_TAC \\ X_GEN_TAC gv3 \\ rpt strip_tac \\ res_tac \\ TRY (FIRST_ASSUM ACCEPT_TAC)
        \\ MATCH_MP_TAC ECON \\ metis_tac []]
  val UP = valOf UPo
  val UPCo = thmO "l2d_model_frame_contract_of_reach" (mk_imp (M1BC, M3C))
     [DISCH_THEN (X_CHOOSE_THEN msv STRIP_ASSUME_TAC)
        \\ EXISTS_TAC msv \\ CONJ_TAC >- (CONJ_TAC \\ FIRST_ASSUM ACCEPT_TAC)
        \\ X_GEN_TAC bv \\ DISCH_TAC
        \\ first_x_assum drule
        \\ DISCH_THEN (X_CHOOSE_THEN tv (X_CHOOSE_THEN iov (fn th =>
             EXISTS_TAC tv \\ EXISTS_TAC iov \\ ACCEPT_TAC (CONJ (CONJUNCT1 th) (MATCH_MP UP (CONJUNCT2 th)))))),
      ho_match_mp_tac boolTheory.MONO_EXISTS \\ gen_tac \\ BETA_TAC
        \\ ho_match_mp_tac boolTheory.MONO_AND \\ CONJ_TAC >- REWRITE_TAC []
        \\ ho_match_mp_tac boolTheory.MONO_ALL \\ gen_tac \\ BETA_TAC
        \\ ho_match_mp_tac boolTheory.MONO_IMP \\ CONJ_TAC >- REWRITE_TAC []
        \\ ho_match_mp_tac boolTheory.MONO_EXISTS \\ gen_tac \\ BETA_TAC
        \\ ho_match_mp_tac boolTheory.MONO_EXISTS \\ gen_tac \\ BETA_TAC
        \\ ho_match_mp_tac boolTheory.MONO_AND \\ CONJ_TAC >- REWRITE_TAC []
        \\ MATCH_ACCEPT_TAC UP]
  val UPC = valOf UPCo
  val G3A = fst (dest_imp (concl ASM_NE))
  val PREM_TAC = FIRST [FIRST_ASSUM ACCEPT_TAC, (rpt gen_tac \\ strip_tac \\ MATCH_ACCEPT_TAC REFST)]
  val G3o = thmO "refund_model_frame_decision_shape" (mk_imp (G3A, M3C))
     [DISCH_THEN STRIP_ASSUME_TAC
        \\ MATCH_MP_TAC UPC
        \\ SUBGOAL_THEN ANTE_S (fn a => ACCEPT_TAC (MP M1B_S a))
        \\ rpt conj_tac \\ PREM_TAC,
      DISCH_THEN STRIP_ASSUME_TAC
        \\ SUBGOAL_THEN ANTE_S (fn a => ACCEPT_TAC (MP UPC (MP M1B_S a)))
        \\ rpt conj_tac \\ PREM_TAC]
  val G3 = valOf G3o
  val _ = if aconv (snd (dest_imp (concl G3))) M3C
          then pr "CONTROL_OK G3 conclusion is term-identical to the conclusion of refund_model_frame_meets_exported_contract"
          else bad "G3-conclusion"
  val _ = if aconv (fst (dest_imp (concl G3))) G3A
          then pr "CONTROL_OK G3 antecedent is term-identical to the antecedent of refund_profile_a_sl_shape at ext := no_ext"
          else bad "G3-antecedent"
  val _ = if not (has_const "ffi_calls_ok" G3A) andalso not (has_const "refund_env_ok_sl" G3A)
             andalso not (Lib.mem "ext" (map (fst o dest_var) (free_vars (concl G3))))
          then pr "CONTROL_OK G3 antecedent has neither ffi_calls_ok nor refund_env_ok_sl; no free ext" else bad "G3-scope"
  val _ = List.app (fn t => pr ("G3_REMAINING_NATIVE_PREMISE " ^ term_to_string t))
                   (List.filter (has_const "refund_ffi_contract_on") (strip_conj G3A))
  in pr "MF_SECTION_DONE"; [UP, UPC, G3] end)
  handle e => (pr ("OPTIONAL_FAILED MODEL_FRAME section " ^ General.exnMessage e); []);
(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = pr ("DIAG_OK_UNDER_LIST " ^ String.concatWith " " (rev (!diag)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = pr ("PARENTS " ^ String.concatWith " " (Theory.parents "forge_refundRouteA2d"));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundRouteA2d" @ DB.definitions "forge_refundRouteA2d");
val closure = "forge_refundRouteA2d" :: Theory.ancestry "forge_refundRouteA2d";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = if List.exists (fn n => n = "forge_refundRouteA2b") closure andalso List.exists (fn n => n = "forge_refundRouteA2") closure
        then pr "CONTROL_OK closure contains forge_refundRouteA2 and forge_refundRouteA2b" else raise Fail "parents missing";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundRouteA2d")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundRouteA2d")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
