(* R6x-0003.sml: R6 EXPLORATION run 3 (worker A30, Night-Shift Orchestrator A). NOT RUN. NOT a proof attempt.
   No export_theory, no save_thm. Local definitions IOxV, IOFS_V, STDIO_V in the scratch theory "forge_refundR6Explore3"
   (never exported). Every tactic UNCHECKED. Ends with EXPLORE_COMPLETE.
   Base = R6x-0002.sml (SHA-256 1c76b89c...fcd46, ran with exit 0). Changes (diff in the report):
   (1) theory name; (2) NEW section GRAMMAR after new_theory: the R6x-0002 failure of xlet_auto
       ("Attempt to unify different type operators: semanticPrimitives$v and flatSem$v", origin cfLetAutoLib.xlet_auto)
       comes from cfLetAutoLib.sml:739 (dummy_spec POSTv (v:v). &T): in this session the bare type name v is bound to flatSem$v
       (the compiler-backend theories of the deps file are loaded after semanticPrimitives). The fix re-privileges the
       bare type names of ffi, namespace, ast, semanticPrimitives with Parse.temp_add_qtype (fallback: the grammars of
       TextIOProof); (3) NEW section INV_HELPERS (ON_INV, INV_CLOSE, INV_DIAG); (4) sub-files R6x-0003-*.sml in round3/. *)
open preamble basis_ffiTheory fsFFITheory fsFFIPropsTheory TextIOProofTheory MarshallingTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
val _ = (load "Timeout"; pr "TIMEOUT_HELPER Timeout.apply loaded")
  handle e => (pr ("TIMEOUT_LOAD_FAILED " ^ General.exnMessage e); raise e);
fun trunc n s = if size s <= n then s else String.substring (s, 0, n) ^ " ...";

(* ================= LOAD ================= *)
val _ = pr "MARK LOAD";
val CK = "/Users/USER/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml";
val _ = loadPath := !loadPath @ map (fn d => CK ^ "/" ^ d)
          ["characteristic", "basis", "basis/pure", "translator", "semantics", "semantics/proofs",
           "semantics/ffi", "compiler/backend/semantics", "misc"];
fun tryload s = (load s; pr ("LOAD_OK " ^ s))
  handle e => pr ("LOAD_FAILED " ^ s ^ " " ^ trunc 300 (General.exnMessage e));
val _ = List.app tryload
  ["cfHeapsBaseTheory", "cfStoreTheory", "cfMainTheory", "cfAppTheory", "TextIOProofTheory", "basis_ffiTheory",
   "ml_progTheory", "semanticsPropsTheory", "targetSemTheory", "targetPropsTheory", "rich_listTheory",
   "forge_refundStdioProgTheory", "forge_refundWholeProgTheory", "cfLib", "basis_ffiLib", "basisFunctionsLib"];
(* The forge theories of the deps file (ExclusionReal, SourceNonFail, SlideProfileA, RouteA1/A2/A2b/A2c) are loaded by
   the runner from their files; THEORY_NAMES lines below show whether they are present. *)

val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundR6Explore3";

(* ================= GRAMMAR (NEW in R6x-0003) ================= *)
val _ = pr "MARK GRAMMAR";
fun v_thy () : string = #Thy (dest_thy_type (Parse.Type [QUOTE ":v"]))
  handle e => "PARSE_FAILED " ^ trunc 200 (General.exnMessage e);
fun dummy_ok () : string = (ignore (Parse.Term [QUOTE "POSTv (v:v). &T"]); "OK")
  handle e => "FAILED " ^ trunc 400 (General.exnMessage e);
val _ = pr ("GRAMMAR_BEFORE type_v_from " ^ v_thy () ^ " ; xlet_auto_dummy_spec " ^ dummy_ok ());
fun privileged_thy (nm : string) : string option =
  Symtab.lookup (type_grammar.privileged_abbrevs (Parse.type_grammar ())) nm;
fun reprivilege (thy : string) : unit =
  let
    val tys = Theory.types thy
      handle e => (pr ("TYPES_FAILED " ^ thy ^ " " ^ trunc 200 (General.exnMessage e)); [])
    fun one ((nm, _) : string * int) : unit =
      (case privileged_thy nm of
         SOME t => if t = thy then ()
                   else (Parse.temp_add_qtype {Thy = thy, Name = nm};
                         pr ("TYPE_REPRIVILEGED " ^ nm ^ " was " ^ t ^ " now " ^ thy))
       | NONE => (Parse.temp_add_qtype {Thy = thy, Name = nm};
                  pr ("TYPE_PRIVILEGED " ^ nm ^ " was none now " ^ thy)))
      handle e => pr ("TYPE_REPRIVILEGE_FAILED " ^ thy ^ "$" ^ nm ^ " " ^ trunc 200 (General.exnMessage e))
  in List.app one tys end;
val _ = List.app reprivilege ["ffi", "namespace", "ast", "semanticPrimitives"];
val _ = pr ("GRAMMAR_AFTER_B type_v_from " ^ v_thy () ^ " ; xlet_auto_dummy_spec " ^ dummy_ok ());
val _ =
  if dummy_ok () = "OK" andalso v_thy () = "semanticPrimitives" then pr "GRAMMAR_FIX B"
  else (case Parse.grammarDB {thyname = "TextIOProof"} of
          SOME g => (Parse.temp_set_grammars g;
                     pr ("GRAMMAR_FIX A type_v_from " ^ v_thy () ^ " ; xlet_auto_dummy_spec " ^ dummy_ok ()))
        | NONE => pr "GRAMMAR_FIX_FAILED grammarDB TextIOProof = NONE");
val _ = pr "EXPLORE_MODE nothing is exported; no theorem, no definition is stored";

(* fth : string -> string -> thm. A missing name prints FETCH_FAILED and gives TRUTH (no static error). *)
fun fth thy nm = DB.fetch thy nm
  handle e => (pr ("FETCH_FAILED " ^ thy ^ "." ^ nm ^ " " ^ trunc 200 (General.exnMessage e)); TRUTH);


(* ================= the stepper: LOx-0001.sml lines 420-525, copied; NAMED_CONSTS changed ================= *)
val _ = pr "EXPLORE_MODE nothing is exported; the open lemmas are never stored";
val _ = metisTools.limit := {time = SOME 20.0, infs = NONE};
val STEP_SECS = 60;
type step = string * tactic * tactic list;

(* ---------- printing ---------- *)
val NAMED_CONSTS = ["arm8_run", "evaluate", "machine_sem", "refund_valid_event"];
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
    val v0 = (fn (_ : thm list) => raise mk_HOL_ERR "LOx" "explore" "no step was run") : thm list -> thm
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
   R6x-0002 PART D (worker A25). EXPLORATION ONLY. Every tactic UNCHECKED. Nothing exported.
   - Local definitions (scratch theory, never exported): IOxV, IOFS_V, STDIO_V.
   - X9r (here) and X8r, WRITEI_V, READ_INTO_V (three separate files, each read with use inside its own handler, so
     a static or run error in one does not hide the others).
   - explore_head: like explore, but each step acts on the HEAD goal only (the other goals are kept); it prints the
     goal count and the first two goals after each step. No validation (exploration only). *)
val _ = pr "MARK DEFS";
val _ = Globals.max_print_depth := 60;
fun def_or_truth name tm = new_definition (name, tm)
  handle e => (pr ("DEFINITION_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e)); TRUTH);
(* binder name "events" as in cfHeapsBase IO_def, so that copied tactics that name `events` still match *)
val IOxV_def = def_or_truth "IOxV_def"
  ``IOxV (Inv:io_event -> bool) (fs:IO_fs) =
      SEP_EXISTS events. one (FFI_part (fsFFI$encode fs) (mk_ffi_next fs_ffi_part)
                                       (MAP FST (SND (SND fs_ffi_part))) events) *
                         &(EVERY Inv events) * &(~MEM «» (MAP FST (SND (SND fs_ffi_part))))``;
val IOFS_V_def = def_or_truth "IOFS_V_def"
  ``IOFS_V (Inv:io_event -> bool) (fs:IO_fs) =
      IOxV Inv fs * (SEP_EXISTS v. W8ARRAY iobuff_loc v * &(LENGTH v = 2052)) * &wfFS fs``;
val STDIO_V_def = def_or_truth "STDIO_V_def"
  ``STDIO_V (Inv:io_event -> bool) (fs:IO_fs) =
      (SEP_EXISTS ll. IOFS_V Inv (fs with numchars := ll)) * &STD_streams fs``;
val _ = List.app (fn th => pr ("DEFINITION " ^ thm_to_string th)) [IOxV_def, IOFS_V_def, STDIO_V_def];

val SIR = fth "set_sep" "SEP_IMP_REFL";
val IOxD = fth "cfHeapsBase" "IOx_def";
val IOD = fth "cfHeapsBase" "IO_def";
val FFP = fth "fsFFI" "fs_ffi_part_def";
val FPH = fth "cfMain" "FFI_part_hprop_def";
val SEPC = fth "set_sep" "SEP_CLAUSES";
val SEPE = fth "set_sep" "SEP_EXISTS_THM";
val STARD = fth "set_sep" "STAR_def";
val CONDD = fth "set_sep" "cond_def";
val ONED = fth "set_sep" "one_def";
val ONES = fth "set_sep" "one_STAR";
val SPLD = fth "set_sep" "SPLIT_def";
val W8AD = fth "cfHeapsBase" "W8ARRAY_def";
val CELLD = fth "cfHeapsBase" "cell_def";
val INU = fth "pred_set" "IN_UNION";
val EVA = fth "list" "EVERY_APPEND";

(* ================= INV_HELPERS (NEW in R6x-0003) =================
   The only new proof obligation at an xffi site is the pure goal EVERY Inv (events ++ [e]) (or EVERY Inv new_events
   with an Abbrev), where e = IO_event (ExtCall name) conf (ZIP (ws, vs)) is the event that app_ffi_def adds
   (cfScript.sml 1767-1783, line 1777). ON_INV tac runs tac only on such a pure goal (no heap constant in it) and is
   ALL_TAC otherwise, so a step built from it is harmless when there is no such goal. *)
val _ = pr "MARK INV_HELPERS";
fun is_inv_var (t : term) : bool = is_var t andalso fst (dest_var t) = "Inv";
fun is_inv_app (t : term) : bool = is_comb t andalso is_inv_var (rator t);
fun is_every_inv (t : term) : bool =
  is_comb t andalso is_comb (rator t) andalso is_inv_var (rand (rator t)) andalso
  (let val c = rator (rator t) in is_const c andalso fst (dest_const c) = "EVERY" end);
val HEAP_CONSTS = ["SEP_IMP", "app", "cf_let", "cf_app", "cf_if", "cf_ffi", "app_ffi", "IOxV", "FFI_part", "W8ARRAY"];
fun mentions_heap (w : term) : bool =
  can (find_term (fn t => is_const t andalso Lib.mem (fst (dest_const t)) HEAP_CONSTS)) w;
fun is_inv_goal ((_, w) : goal) : bool =
  not (mentions_heap w) andalso can (find_term (fn t => is_inv_app t orelse is_every_inv t)) w;
fun ON_INV (tac : tactic) : tactic = fn g => if is_inv_goal g then tac g else ALL_TAC g;
val ABD = markerTheory.Abbrev_def;
val N2W2D = MarshallingTheory.n2w2_def;
val MIND = arithmeticTheory.MIN_DEF;
fun closing (t : tactic) : tactic = t \\ NO_TAC;
(* C1: H_inv as a conditional rewrite; C2/C3: irule H_inv (as stated / after n2w2_def); C4: irule H_inv after
   rewriting it with n2w2_def and APPEND (bytes ws in cons form); C5: metis. *)
val INV_C1 = fs [ABD, EVA, N2W2D];
val INV_C2 = fs [ABD, EVA] \\ first_x_assum irule \\ rw [] \\ fs [];
val INV_C3 = fs [ABD, EVA, N2W2D] \\ first_x_assum irule \\ rw [] \\ fs [MIND] \\ rw [] \\ fs [];
val INV_C4 = fs [ABD, EVA] \\
  qpat_x_assum [QUOTE "!nb. _"] (irule o SIMP_RULE bool_ss [N2W2D, listTheory.APPEND]) \\
  rw [] \\ fs [MIND] \\ rw [] \\ fs [];
val INV_C5 = fs [ABD, EVA] \\ metis_tac [];
val INV_CLOSE : tactic = FIRST (map closing [INV_C1, INV_C2, INV_C3, INV_C4, INV_C5]);
val INV_DIAG : tactic = fs [ABD, EVA, N2W2D];

(* ---------- head-goal stepper ---------- *)
val HEAD_SECS = 240;  (* CF steps (xsimpl, big fs) are slower than the 60 s of the prefix stepper *)
fun explore_head (lemma : string) (goalf : unit -> term) (steps : step list) : unit =
  let
    val gt = goalf ()
    fun app1 (tac : tactic) (gs : goal list) : goal list =
      case gs of
        [] => raise mk_HOL_ERR "R6x2" "explore_head" "no goal left"
      | g :: rest =>
          let val ctxt = Context.snapshot ()
              val (gs1, _) = Timeout.apply (Time.fromSeconds (Int.toLarge HEAD_SECS)) (fn () => tac g ctxt) ()
          in gs1 @ rest end
    fun attempt (tac : tactic) (gs : goal list) : goal list option * string =
      (SOME (app1 tac gs), "")
      handle Timeout.TIMEOUT _ => (NONE, "TIMEOUT after " ^ Int.toString HEAD_SECS ^ " s")
           | e => (NONE, General.exnMessage e)
    fun show2 (gs : goal list) = (pr ("  HEAD_GOALS_TOTAL " ^ Int.toString (length gs));
                                  show_goals lemma (List.take (gs, Int.min (2, length gs))))
    fun loop (i : int) (gs : goal list) (rest : step list) : unit =
      case rest of
        [] => if null gs then pr ("EXPLORE_HEAD_CLOSED " ^ lemma ^ " after_steps " ^ Int.toString (i - 1))
              else pr ("EXPLORE_HEAD_OPEN " ^ lemma ^ " goals " ^ Int.toString (length gs))
      | ((label, tac, alts) :: more) =>
          (case attempt tac gs of
             (SOME gs1, _) => (pr ("STEP " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " goals " ^
                                   Int.toString (length gs1)); show2 gs1; loop (i + 1) gs1 more)
           | (NONE, msg) => (pr ("STEP_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " " ^ trunc 800 msg);
                             pr ("GOALS_BEFORE_STEP " ^ lemma ^ " " ^ Int.toString i); show2 gs;
                             alt_loop i label gs more 1 alts))
    and alt_loop i label gs more k alts =
      case alts of
        [] => pr ("STEP_STUCK " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label)
      | (a :: others) =>
          (case attempt a gs of
             (SOME gs1, _) => (pr ("ALT_WORKS " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " alt " ^ Int.toString k);
                               pr ("STEP " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " goals " ^
                                   Int.toString (length gs1) ^ " (alt " ^ Int.toString k ^ ")");
                               show2 gs1; loop (i + 1) gs1 more)
           | (NONE, msg) => (pr ("ALT_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " alt " ^
                                 Int.toString k ^ " " ^ trunc 800 msg);
                             alt_loop i label gs more (k + 1) others))
  in
    pr ("EXPLORE_BEGIN " ^ lemma ^ " (head-goal mode) steps " ^ Int.toString (length steps));
    show_goals lemma [([], gt)];
    loop 1 [([], gt)] steps;
    pr ("EXPLORE_END " ^ lemma)
  end
  handle e => pr ("EXPLORE_ERROR " ^ lemma ^ " " ^ trunc 800 (General.exnMessage e));
fun tm_opt (name : string) (f : unit -> term) : term option =
  SOME (f ()) handle e => (pr ("STATEMENT_PARSE_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e)); NONE);
fun goal_of (t : term option) () : term = valOf t;

(* ---------- X9r: FFI_part_hprop (IOFS_V Inv fs). R6x-0001 steps 1-3 (log 1448-1472) + new close step:
   the printed goal (log 1490-1507) has ASM u UNION {Mem loc (W8array v)} = h and ASM FFI_part ... IN u. ---------- *)
val X9 = tm_opt "X9r" (fn () => ``!(Inv:io_event -> bool) fs. FFI_part_hprop (IOFS_V Inv fs)``);
val _ = explore "X9r_FFI_part_hprop_IOFS_V" (goal_of X9) (fn () =>
  [("intro", rpt gen_tac, []),
   ("unfold", rw [FPH, IOFS_V_def, IOxV_def, SEPC, SEPE, W8AD, CELLD], [simp [FPH, IOFS_V_def, IOxV_def, SEPE]]),
   ("split", fs [ONES, STARD, SPLD, CONDD, ONED], []),
   ("close", rveq \\ fs [INU] \\ metis_tac [],
      [qpat_x_assum `_ UNION _ = h` (SUBST_ALL_TAC o SYM) \\ simp [INU] \\ metis_tac [],
       metis_tac [INU]])]);

(* ---------- statements of the two S4 lemmas (built from the stored specs; Inv generic) ---------- *)
val _ = pr "MARK S4_STATEMENTS";
val IOX_FS = ``IOx fs_ffi_part``;
val IOXV_INV = ``IOxV (Inv:io_event -> bool)``;
(* writei_spec_V: writei_spec (TextIOProofScript.sml 1406-1421) with IOx fs_ffi_part := IOxV Inv, and one new
   hypothesis H_inv as the LAST antecedent (after bc = ...). *)
val WRITEI_V = tm_opt "writei_spec_V" (fn () =>
  let val (hs, c) = strip_imp (concl (fth "TextIOProof" "writei_spec"))
      val hinv = ``!nb:word8 list. LENGTH nb = 4 + LENGTH (rest:word8 list) /\ HD nb = 0w ==>
                     Inv (IO_event (ExtCall «write») (n2w8 fd) (ZIP (n2w2 n ++ n2w2 i ++ rest, nb)))``
  in list_mk_imp (hs @ [hinv], subst [IOX_FS |-> IOXV_INV] c) end);
(* read_into_spec_V: read_into_spec (2132-2149) with IOx fs_ffi_part := IOxV Inv; two NEW hypotheses that exclude the
   error branches (an error event has HD nb = 1w and is not valid), and H_inv. *)
val READ_INTO_V = tm_opt "read_into_spec_V" (fn () =>
  let val (vs, body) = strip_forall (concl (fth "TextIOProof" "read_into_spec"))
      val (hs, c) = strip_imp body
      val extra = [``get_fd_content fs fd <> NONE``, ``get_mode fs fd = SOME ReadMode``,
                   ``!nb:word8 list. LENGTH nb = 4 + LENGTH (rest:word8 list) /\ HD nb = 0w ==>
                       Inv (IO_event (ExtCall «read») (n2w8 fd) (ZIP (n2w2 n ++ h3::h4::rest, nb)))``]
  in list_mk_forall (vs, list_mk_imp (hs @ extra, subst [IOX_FS |-> IOXV_INV] c)) end);
val _ = List.app (fn (n, t) => case t of SOME x => pr ("STATEMENT " ^ n ^ "\n" ^ term_to_string x)
                                         | NONE => pr ("STATEMENT_MISSING " ^ n))
          [("writei_spec_V", WRITEI_V), ("read_into_spec_V", READ_INTO_V)];

(* ---------- the three CF files ---------- *)
val R6DIR = "/Users/USER/forge/results/night-shift-20261119/orch-A/r6/round3/";
fun use_part (f : string) =
  (pr ("MARK USE " ^ f); use (R6DIR ^ f); pr ("PART_DONE " ^ f))
  handle e => pr ("PART_FAILED " ^ f ^ " " ^ trunc 800 (General.exnMessage e));
val _ = use_part "R6x-0003-x8.sml";
val _ = use_part "R6x-0003-writei.sml";
val _ = use_part "R6x-0003-readinto.sml";

val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
