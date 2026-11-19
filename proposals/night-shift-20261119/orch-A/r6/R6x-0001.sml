(* R6x-0001.sml: R6 EXPLORATION run (worker A25, Night-Shift Orchestrator A). NOT RUN. NOT a proof attempt.
   Purpose: start route R-CF-INV for premise R6 of forge_refundRouteA2c.refund_profile_a_sl_events.
   - No export_theory, no save_thm, no store_thm, no new_definition. Scratch theory "forge_refundR6Explore" (never exported).
   - Open sub-lemmas are only explored. Where one exploration needs another, it uses ASSUME of its statement;
     VALIDATION ... hyps N > 0 then means "closed only under the ASSUMEd statements".
   - Every tactic is UNCHECKED. Ends with EXPLORE_COMPLETE.
   - Stepper (section "the stepper") = LOx-0001.sml lines 420-525 (SHA-256 5ef71604...331d7d), copied; only NAMED_CONSTS differs.
   - Part CF (file R6x-0001-cf.sml, same folder) is run with `use` inside a handler: it needs cfLib.
   Sections: LOAD, STORED (print statements), CONSTS, PARSE (route statements, type check only), EXPLORE (X1..X7),
   CF (X8, optional). *)
open preamble basis_ffiTheory fsFFITheory fsFFIPropsTheory TextIOProofTheory MarshallingTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
val _ = (load "Timeout"; pr "TIMEOUT_HELPER Timeout.apply loaded")
  handle e => (pr ("TIMEOUT_LOAD_FAILED " ^ General.exnMessage e); raise e);
fun trunc n s = if size s <= n then s else String.substring (s, 0, n) ^ " ...";

(* ================= LOAD ================= *)
val _ = pr "MARK LOAD";
val CK = "/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml";
val _ = loadPath := !loadPath @ map (fn d => CK ^ "/" ^ d)
          ["characteristic", "basis", "basis/pure", "translator", "semantics", "semantics/proofs",
           "semantics/ffi", "compiler/backend/semantics", "misc"];
fun tryload s = (load s; pr ("LOAD_OK " ^ s))
  handle e => pr ("LOAD_FAILED " ^ s ^ " " ^ trunc 300 (General.exnMessage e));
val _ = List.app tryload
  ["cfHeapsBaseTheory", "cfStoreTheory", "cfMainTheory", "cfAppTheory", "TextIOProofTheory", "basis_ffiTheory",
   "ml_progTheory", "semanticsPropsTheory", "targetSemTheory", "targetPropsTheory", "rich_listTheory",
   "forge_refundStdioProgTheory", "forge_refundWholeProgTheory", "cfLib", "basis_ffiLib"];
(* The forge theories of the deps file (ExclusionReal, SourceNonFail, SlideProfileA, RouteA1/A2/A2b/A2c) are loaded by
   the runner from their files; THEORY_NAMES lines below show whether they are present. *)

val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundR6Explore";
val _ = pr "EXPLORE_MODE nothing is exported; no theorem, no definition is stored";

(* fth : string -> string -> thm. A missing name prints FETCH_FAILED and gives TRUTH (no static error). *)
fun fth thy nm = DB.fetch thy nm
  handle e => (pr ("FETCH_FAILED " ^ thy ^ "." ^ nm ^ " " ^ trunc 200 (General.exnMessage e)); TRUTH);

(* ================= STORED: exact statements the route starts from ================= *)
val _ = pr "MARK STORED";
val _ = Globals.max_print_depth := 1000;
fun show_stored (thy, nm) =
  (let val th = DB.fetch thy nm
       val (ors, axs) = Tag.dest_tag (Thm.tag th)
   in pr ("STORED " ^ thy ^ "." ^ nm ^ " hyps " ^ Int.toString (length (hyp th)) ^
          " oracles " ^ String.concatWith "," ors ^ " axioms " ^ Int.toString (length axs));
      pr (trunc 9000 (thm_to_string th))
   end)
  handle e => pr ("FETCH_FAILED " ^ thy ^ "." ^ nm ^ " " ^ trunc 200 (General.exnMessage e));
val stored_list =
  [("forge_refundRouteA2c", "refund_valid_event_def"), ("forge_refundRouteA2c", "VokY3_def"),
   ("forge_refundRouteA2c", "refund_profile_a_sl_events"),
   ("forge_refundRouteA1", "refund_env_ok_sl_of_contract_on"),
   ("forge_refundSlideInstalled", "refund_installed_from_entry_reduced_sl"),
   ("forge_refundSlideProfileA", "refund_env_ok_sl_iff_installed_residual"),
   ("forge_refundSlideProfileA", "refund_profile_a_sl"),
   ("forge_refundSourceNonFail", "refund_behavior_valid_request_no_handler"),
   ("forge_refundSourceNonFail", "refund_source_nonfail"),
   ("forge_refundExclusionReal", "refund_compile_correct_no_handler"),
   ("forge_refundWholeProg", "refund_semantics"),
   ("forge_refundWholeProg", "refund_request_whole_prog_spec"),
   ("forge_refundWholeProg", "refund_whole_prog_spec"),
   ("forge_refundStdioProg", "refund_main_valid"),
   ("ml_prog", "sem_satisfies_IMP_Terminate"),
   ("basis_ffi", "whole_prog_spec_def"), ("basis_ffi", "whole_prog_spec_IMP"),
   ("basis_ffi", "whole_prog_spec_semantics_prog"), ("basis_ffi", "basis_proj1_def"), ("basis_ffi", "basis_proj2_def"),
   ("basis_ffi", "STDIO_precond"), ("basis_ffi", "extract_fs_def"),
   ("cfMain", "call_main_thm2"), ("cfMain", "FFI_part_hprop_def"),
   ("cfStore", "parts_ok_def"), ("cfStore", "ffi2heap_def"), ("cfStore", "ffi_has_index_in_def"),
   ("cfHeapsBase", "IO_def"), ("cfHeapsBase", "IOx_def"), ("cfHeapsBase", "mk_ffi_next_def"),
   ("TextIOProof", "IOFS_def"), ("TextIOProof", "IOFS_iobuff_def"), ("TextIOProof", "STDIO_def"),
   ("TextIOProof", "FD_def"), ("TextIOProof", "INSTREAM_STR_def"), ("TextIOProof", "instream_buffered_inv_def"),
   ("TextIOProof", "writei_spec"), ("TextIOProof", "read_into_spec"), ("TextIOProof", "print_spec"),
   ("TextIOProof", "inputAllFrom_NONE_spec"), ("TextIOProof", "refillBuffer_with_read_guard_spec_STR"),
   ("TextIOProof", "consume_rest_spec"),
   ("semanticsProps", "extend_with_resource_limit_def"), ("semanticsProps", "sem_satisfies_def"),
   ("targetProps", "machine_sem_total"), ("targetProps", "evaluate_add_clock"),
   ("targetProps", "evaluate_add_clock_io_events_mono")];
val _ = List.app show_stored stored_list;
val _ = List.app (fn thy =>
          (pr ("THEORY_NAMES " ^ thy ^ " " ^ String.concatWith " " (map fst (DB.theorems thy))))
          handle e => pr ("THEORY_NAMES_FAILED " ^ thy))
        ["forge_refundRouteA1", "forge_refundRouteA2", "forge_refundRouteA2b", "forge_refundRouteA2c"];
val _ = Globals.max_print_depth := 60;

(* ================= CONSTS: theory of every ambiguous constant in the key statements ================= *)
val _ = pr "MARK CONSTS";
val WATCH = ["evaluate", "arm8_run", "machine_sem", "Success", "Terminate", "encode", "extract_fs",
             "refund_prog", "basis_ffi", "IOx", "STDIO", "refund_valid_event", "semantics_dec_list"];
fun consts_report (label : string) (tm : term) =
  List.app (fn c => let val {Thy = thy, Name = nm, Ty = ty} = dest_thy_const c
                    in pr ("CONST_IN " ^ label ^ " " ^ thy ^ "$" ^ nm ^ " : " ^ trunc 200 (type_to_string ty)) end)
    (op_mk_set aconv (find_terms (fn t => is_const t andalso Lib.mem (fst (dest_const t)) WATCH) tm));
val _ = List.app (fn (thy, nm) => consts_report (thy ^ "." ^ nm) (concl (DB.fetch thy nm))
                                  handle _ => pr ("CONST_REPORT_FAILED " ^ thy ^ "." ^ nm))
  [("forge_refundRouteA2c", "refund_profile_a_sl_events"), ("forge_refundWholeProg", "refund_semantics"),
   ("forge_refundSourceNonFail", "refund_behavior_valid_request_no_handler"),
   ("forge_refundExclusionReal", "refund_compile_correct_no_handler")];

(* ================= PARSE: the route statements (type check only; nothing is proved here) ================= *)
val _ = pr "MARK PARSE";
fun parse_check (name : string) (f : unit -> term) : term option =
  (let val t = f ()
   in pr ("TYPECHECK_OK " ^ name ^ " : " ^ type_to_string (type_of t));
      pr ("  TERM " ^ trunc 6000 (term_to_string t));
      pr ("  FREE_VARS " ^ trunc 2000 (String.concatWith ", "
            (map (fn v => let val (n, ty) = dest_var v in n ^ ":" ^ type_to_string ty end) (free_vars t))));
      consts_report name t;
      SOME t
   end)
  handle e => (pr ("TYPECHECK_FAILED " ^ name ^ " " ^ trunc 800 (General.exnMessage e)); NONE);

val RVE = fth "forge_refundRouteA2c" "refund_valid_event_def";
val RVE_C = (prim_mk_const {Thy = "forge_refundRouteA2c", Name = "refund_valid_event"})
            handle e => (pr ("CONST_MISSING refund_valid_event"); T);

(* P0. Proposed weaker read clause (statement change; see RUN_PLAN_R6x.md "Statement change"). The write clause is the
   L2c text unchanged. *)
val RVEW_opt = parse_check "P0_refund_valid_event_w_lambda" (fn () =>
  ``\e. (?ab nb. e = IO_event (ExtCall «read») (n2w8 0) (ZIP (ab,nb)) /\ LENGTH nb = LENGTH ab /\
                 4 <= LENGTH ab /\ LENGTH ab < 65536 /\ w22n [EL 0 ab; EL 1 ab] + 4 <= LENGTH ab /\ HD nb = 0w) \/
        (?ab nb. e = IO_event (ExtCall «write») (n2w8 1) (ZIP (ab,nb)) /\ LENGTH ab = 2052 /\
                 LENGTH nb = LENGTH ab /\ w22n [EL 0 ab; EL 1 ab] + w22n [EL 2 ab; EL 3 ab] <= 2048 /\ HD nb = 0w)``);
val RVEW = case RVEW_opt of SOME t => t | NONE => RVE_C;

(* P1. SRC-EV: refund_semantics with "EVERY pred io_events" added inside the existential (built from the stored term). *)
fun add_every_in_sem (pred : term) (tm : term) : term =
  let val (a, c) = dest_imp tm
      val (f, lam) = dest_comb c
      val (bv, body) = dest_abs lam
      val (iov, eb) = dest_exists body
  in mk_imp (a, mk_comb (f, mk_abs (bv, mk_exists (iov, mk_conj (eb, ``EVERY ^pred ^iov``))))) end;
val SEM = fth "forge_refundWholeProg" "refund_semantics";
val SRC_EV = parse_check "P1_SRC_EV" (fn () => add_every_in_sem RVE_C (concl SEM));
val SRC_EV_W = parse_check "P1w_SRC_EV_weak_read_clause" (fn () => add_every_in_sem RVEW (concl SEM));

(* P2. BEH-EV: refund_behavior_valid_request_no_handler with the same conjunct (slide 0 form, mc0 generic). *)
fun add_every_in_exists (pred : term) (tm : term) : term =
  let val (a, c) = dest_imp tm
      val (iov, b) = dest_exists c
  in mk_imp (a, mk_exists (iov, mk_conj (b, ``EVERY ^pred ^iov``))) end;
val BEH = fth "forge_refundSourceNonFail" "refund_behavior_valid_request_no_handler";
val BEH_EV = parse_check "P2_BEH_EV" (fn () => add_every_in_exists RVE_C (concl BEH));

(* P3. R6-DISCHARGE target: the premises of refund_profile_a_sl_events other than R6 imply R6. *)
val EVS = fth "forge_refundRouteA2c" "refund_profile_a_sl_events";
fun r6_split (tm : term) =
  let val (a, _) = dest_imp tm
      val cs = strip_conj a
      val (r6s, others) = List.partition (fn c => is_forall c andalso free_in RVE_C c) cs
  in (r6s, others) end;
val R6_TARGET = parse_check "P3_R6_DISCHARGE_TARGET" (fn () =>
  let val (r6s, others) = r6_split (concl EVS)
      val _ = pr ("R6_CONJUNCTS_FOUND " ^ Int.toString (length r6s) ^ " OTHER_PREMISES " ^ Int.toString (length others))
  in mk_imp (list_mk_conj others, hd r6s) end);

(* P4. L-CLK, generic in the machine and the predicate. *)
val CLK_TM = parse_check "P4_L_CLK" (fn () =>
  ``!mc (ffi:'ffi ffi_state) ms io (P:io_event -> bool).
      targetSem$machine_sem mc ffi ms SUBSET semanticsProps$extend_with_resource_limit {Terminate Success io} /\
      EVERY P io ==>
      !j. EVERY P (SND (SND (targetSem$evaluate mc ffi j ms))).io_events``);

(* P5. The instrumented IO predicate (type check of the core of IOFS_V; Inv is a parameter). *)
val IOXV_TM = parse_check "P5_IOxV_lambda" (fn () =>
  ``\(Inv:io_event -> bool) (fs:IO_fs).
      SEP_EXISTS evs. one (FFI_part (fsFFI$encode fs) (mk_ffi_next fs_ffi_part) (MAP FST (SND (SND fs_ffi_part))) evs) *
                      &(EVERY Inv evs) * &(~MEM «» (MAP FST (SND (SND fs_ffi_part))))``);
val IOFS_V_TM = parse_check "P5b_IOFS_V_lambda" (fn () =>
  ``\(Inv:io_event -> bool) (fs:IO_fs).
      (SEP_EXISTS evs. one (FFI_part (fsFFI$encode fs) (mk_ffi_next fs_ffi_part) (MAP FST (SND (SND fs_ffi_part))) evs) *
                       &(EVERY Inv evs) * &(~MEM «» (MAP FST (SND (SND fs_ffi_part))))) *
      (SEP_EXISTS v. W8ARRAY iobuff_loc v * &(LENGTH v = 2052)) * &wfFS fs``);

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
   R6x-0001 EXPLORATIONS (worker A25). Every tactic UNCHECKED. Nothing is stored.
   X1-X3: L-CLK (every finite clock j; generic).  X4-X6: R-REPLAY counterexample (validates that the stored
   extract_fs equation cannot exclude an invalid event).  X6c: old refund_valid_event implies the proposed weaker one.
   X7a/X7: the three-parts FILTER lemma (final source-level assembly).  X9: FFI_part_hprop of IOFS_V.
   X8 (file R6x-0001-cf.sml): IOxV ==>> IOx with xsimpl (needs cfLib). *)
val _ = pr "MARK EXPLORE";
val MSD = fth "targetSem" "machine_sem_def";
val MST = fth "targetProps" "machine_sem_total";
val EAC = fth "targetProps" "evaluate_add_clock";
val EAM = fth "targetProps" "evaluate_add_clock_io_events_mono";
val EWRL = fth "semanticsProps" "extend_with_resource_limit_def";
val SUBD = fth "pred_set" "SUBSET_DEF";
val IND = fth "bool" "IN_DEF";
val EVA = fth "list" "EVERY_APPEND";
val MEMA = fth "list" "MEM_APPEND";
val LUPD = fth "list" "LUPDATE_def";
val IPA = fth "rich_list" "IS_PREFIX_APPEND";
val IPT = fth "rich_list" "IS_PREFIX_TRANS";
val IPR = fth "rich_list" "IS_PREFIX_REFL";
val EFN = fth "basis_ffi" "extract_fs_with_numchars_def";
val EFA = fth "basis_ffi" "extract_fs_with_numchars_APPEND";
val EFD = fth "basis_ffi" "extract_fs_def";
val FFP = fth "fsFFI" "fs_ffi_part_def";
val FREAD = fth "fsFFI" "ffi_read_def";
val N2W8 = fth "Marshalling" "n2w8_def";
val N2W2 = fth "Marshalling" "n2w2_def";
val W22N = fth "Marshalling" "w22n_def";
val DIM8 = fth "words" "dimword_8";
val W2NN = fth "words" "w2n_n2w";
val FHI = fth "cfStore" "ffi_has_index_in_def";
val IOxD = fth "cfHeapsBase" "IOx_def";
val IOD = fth "cfHeapsBase" "IO_def";
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

(* parse once; NONE on a parse error *)
fun tm_opt (name : string) (f : unit -> term) : term option =
  SOME (f ()) handle e => (pr ("STATEMENT_PARSE_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e)); NONE);
fun assume_opt (t : term option) : thm = case t of SOME x => ASSUME x | NONE => TRUTH;
fun goal_of (t : term option) () : term = valOf t;

(* ---------- X1 every element of a prefix ---------- *)
val X1 = tm_opt "X1" (fn () => ``!(P:'a -> bool) (l1:'a list) l2. l1 <<= l2 /\ EVERY P l2 ==> EVERY P l1``);
val _ = explore "X1_EVERY_prefix" (goal_of X1) (fn () =>
  [("intro", rpt gen_tac, []),
   ("rw_prefix", rw [IPA], [strip_tac \\ fs [IPA]]),
   ("every_append", fs [EVA], [metis_tac [EVA], simp [EVA]])]);

(* ---------- X2 the events at any clock are a prefix of a terminating behaviour's events ---------- *)
val X2 = tm_opt "X2" (fn () =>
  ``!mc (ffi:'ffi ffi_state) ms t iob j.
      targetSem$machine_sem mc ffi ms (Terminate t iob) ==>
      (SND (SND (targetSem$evaluate mc ffi j ms))).io_events <<= iob``);
val _ = explore "X2_clock_prefix_of_Terminate" (goal_of X2) (fn () =>
  [("intro", rpt gen_tac, []),
   ("unfold", simp [MSD] \\ strip_tac, [rw [MSD], fs [MSD] \\ strip_tac]),
   ("case_split", Cases_on `j <= k`, []),
   ("le_A", TRY (qspecl_then [`mc`, `ffi`, `j`, `ms`, `k`] mp_tac EAM \\ asm_simp_tac (srw_ss()) [IPR] \\ NO_TAC), []),
   ("gt_A", TRY (`k + (j - k) = j` by decide_tac \\
                 qspecl_then [`mc`, `ffi`, `k`, `ms`, `j - k`, `Halt t`, `ms'`, `st'`] mp_tac EAC \\
                 asm_simp_tac (srw_ss()) [] \\ strip_tac \\ asm_simp_tac (srw_ss()) [IPR] \\ NO_TAC), []),
   ("le_B", TRY (((irule IPT \\ qexists_tac `(SND (SND (targetSem$evaluate mc ffi k ms))).io_events` \\ conj_tac)
                  THENL [irule EAM \\ decide_tac, asm_simp_tac (srw_ss()) [IPR]]) \\ NO_TAC), []),
   ("gt_B", TRY (drule EAC \\ simp [] \\ disch_then (qspec_then `j - k` mp_tac) \\
                 `k + (j - k) = j` by decide_tac \\ asm_simp_tac (srw_ss()) [IPR] \\ NO_TAC), [])]);

(* ---------- X3 L-CLK (X1, X2 ASSUMEd) ---------- *)
val EVP_A = assume_opt X1;
val CLKA_A = assume_opt X2;
val X3 = tm_opt "X3" (fn () =>
  ``!mc (ffi:'ffi ffi_state) ms io (P:io_event -> bool).
      targetSem$machine_sem mc ffi ms SUBSET semanticsProps$extend_with_resource_limit {Terminate Success io} /\
      EVERY P io ==>
      !j. EVERY P (SND (SND (targetSem$evaluate mc ffi j ms))).io_events``);
val _ = explore "X3_L_CLK" (goal_of X3) (fn () =>
  [("intro", rpt strip_tac, []),
   ("total", qspecl_then [`ffi`, `ms`, `mc`] strip_assume_tac (GEN_ALL MST),
      [`?b. targetSem$machine_sem mc ffi ms b` by metis_tac [MST]]),
   ("in_ext", `b IN semanticsProps$extend_with_resource_limit {Terminate Success io}` by fs [SUBD, IND],
      [`b IN semanticsProps$extend_with_resource_limit {Terminate Success io}` by metis_tac [SUBD, IND]]),
   ("unfold_ext", pop_assum mp_tac \\ simp [EWRL] \\ strip_tac, [pop_assum mp_tac \\ rw [EWRL]]),
   ("subst", rveq, [rpt BasicProvers.VAR_EQ_TAC]),
   ("close_A", TRY (((irule EVP_A \\ qexists_tac `io` \\ conj_tac)
                     THENL [metis_tac [CLKA_A, IPT, IPR], first_assum ACCEPT_TAC]) \\ NO_TAC), []),
   ("close_B", TRY (metis_tac [EVP_A, CLKA_A, IPT, IPR]), [])]);

(* ---------- X4-X6 R-REPLAY counterexample: a replay-neutral invalid event ---------- *)
(* E_BAD = a read event with an EMPTY conf (C: clen = 0 fails assert(clen == 8), basis_ffi.c 161). The model oracle
   answers it with the error byte and an unchanged state (fsFFIScript.sml 307-327), so the replay skips it. *)
val X4 = tm_opt "X4" (fn () =>
  ``!ext cls fs. basis_ffi$extract_fs_with_numchars ext (cls,fs)
        [IO_event (ExtCall «read») [] (ZIP ([0w;0w;0w;0w],[1w;0w;0w;0w]))] = SOME (cls,fs)``);
val _ = explore "X4_bad_event_replays_to_the_same_state" (goal_of X4) (fn () =>
  [("intro", rpt gen_tac, []),
   ("eval_replay", simp [EFN, FFP, FREAD, LUPD],
      [simp [EFN, FFP] \\ EVAL_TAC, rw [EFN, FFP, FREAD, LUPD] \\ EVAL_TAC, EVAL_TAC])]);
val X4_A = assume_opt X4;
val X5 = tm_opt "X5" (fn () =>
  ``!ext cl fs io. basis_ffi$extract_fs ext (cl,fs)
        (io ++ [IO_event (ExtCall «read») [] (ZIP ([0w;0w;0w;0w],[1w;0w;0w;0w]))]) =
      basis_ffi$extract_fs ext (cl,fs) io``);
val _ = explore "X5_stored_replay_cannot_exclude_the_bad_event" (goal_of X5) (fn () =>
  [("intro", rpt gen_tac, []),
   ("unfold", simp [EFD, EFA], [rw [EFD, EFA]]),
   ("cases", Cases_on `extract_fs_with_numchars ext (cl,fs) io` \\ simp [],
      [BasicProvers.every_case_tac \\ fs []]),
   ("pair", TRY (rename1 `SOME stv` \\ PairCases_on `stv` \\ simp [X4_A]),
      [])]);
val X6 = tm_opt "X6" (fn () =>
  ``~refund_valid_event (IO_event (ExtCall «read») [] (ZIP ([0w;0w;0w;0w],[1w;0w;0w;0w])))``);
val _ = explore "X6_bad_event_is_not_valid" (goal_of X6) (fn () =>
  [("simp", simp [RVE, N2W8], [rw [RVE, N2W8], simp [RVE] \\ EVAL_TAC])]);
val X6w = tm_opt "X6w" (fn () =>
  ``~(^RVEW (IO_event (ExtCall «read») [] (ZIP ([0w;0w;0w;0w],[1w;0w;0w;0w]))))``);
val _ = explore "X6w_bad_event_is_not_valid_w" (goal_of X6w) (fn () =>
  [("simp", simp [N2W8], [rw [N2W8], EVAL_TAC])]);
(* control: the proposed weaker predicate is implied by the stored one (so R6_w is a weaker premise) *)
val X6c = tm_opt "X6c" (fn () => ``!e. refund_valid_event e ==> ^RVEW e``);
val _ = explore "X6c_old_predicate_implies_weaker_predicate" (goal_of X6c) (fn () =>
  [("unfold", simp [RVE] \\ rpt strip_tac, [rw [RVE]]),
   ("subst", rveq, [rpt BasicProvers.VAR_EQ_TAC]),
   ("beta", TRY BETA_TAC, []),
   ("write_case", TRY (disj2_tac \\ qexistsl_tac [`ab`, `nb`] \\ asm_simp_tac (srw_ss()) [] \\ NO_TAC), []),
   ("read_case", TRY (disj1_tac \\ qexistsl_tac [`ab`, `nb`] \\
                      `?a0 a1 rest. ab = a0::a1::rest` by (Cases_on `ab` \\ fs [] \\ Cases_on `t` \\ fs []) \\
                      rveq \\ fs [N2W2, W22N, DIM8, W2NN] \\ NO_TAC), []),
   ("read_case_B", TRY (disj1_tac \\ qexistsl_tac [`ab`, `nb`] \\
                        `?a0 a1 rest. ab = a0::a1::rest` by (Cases_on `ab` \\ fs [] \\ Cases_on `t` \\ fs []) \\
                        rveq \\ fs [N2W2] \\ EVAL_TAC \\ NO_TAC), [])]);

(* ---------- X7a / X7 three parts: no cl event, no runtime event, every fs event valid => every event valid ---------- *)
val X7a = tm_opt "X7a" (fn () =>
  ``!a b e. cfStore$ffi_has_index_in (a ++ b) e <=>
            cfStore$ffi_has_index_in a e \/ cfStore$ffi_has_index_in b e``);
val _ = explore "X7a_ffi_has_index_in_APPEND" (goal_of X7a) (fn () =>
  [("intro", rpt gen_tac, []),
   ("cases_event", namedCases_on `e` ["nm conf bs"], [Cases_on `e`]),
   ("cases_name", Cases_on `nm`, [Cases_on `f`]),
   ("simp", simp [FHI, MEMA], [rw [FHI, MEMA], fs [FHI, MEMA] \\ metis_tac []])]);
val X7a_A = assume_opt X7a;
val X7 = tm_opt "X7" (fn () =>
  ``!(P:io_event -> bool) ns1 ns2 ns3 evs.
      EVERY (cfStore$ffi_has_index_in (ns1 ++ ns2 ++ ns3)) evs /\
      FILTER (cfStore$ffi_has_index_in ns1) evs = [] /\
      FILTER (cfStore$ffi_has_index_in ns3) evs = [] /\
      EVERY P (FILTER (cfStore$ffi_has_index_in ns2) evs) ==> EVERY P evs``);
val _ = explore "X7_three_parts_every" (goal_of X7) (fn () =>
  [("intro", ntac 4 gen_tac, []),
   ("induct", Induct, []),
   ("simp", simp [], []),
   ("strip", rpt strip_tac, []),
   ("cases", Cases_on `ffi_has_index_in ns1 h` \\ Cases_on `ffi_has_index_in ns3 h` \\
             Cases_on `ffi_has_index_in ns2 h` \\ fs [X7a_A], [rfs [X7a_A]]),
   ("close", TRY (metis_tac []), [])]);

(* ---------- X9 FFI_part_hprop of the instrumented IOFS_V (needed by call_main_thm2) ---------- *)
val X9 = tm_opt "X9" (fn () => ``!(Inv:io_event -> bool) fs. FFI_part_hprop (^(valOf IOFS_V_TM) Inv fs)``);
val _ = explore "X9_FFI_part_hprop_IOFS_V" (goal_of X9) (fn () =>
  [("intro", rpt gen_tac \\ BETA_TAC, []),
   ("unfold", rw [FPH, SEPC, SEPE, W8AD, CELLD], [simp [FPH, SEPE]]),
   ("split", fs [ONES, STARD, SPLD, CONDD, ONED], []),
   ("close", TRY (metis_tac []), [])]);

(* ---------- X8 needs cfLib; run from a separate file, inside a handler ---------- *)
val WEAK_TM = tm_opt "X8" (fn () => ``!(Inv:io_event -> bool) fs. ^(valOf IOXV_TM) Inv fs ==>> IOx fs_ffi_part fs``);
val CF_FILE = "/Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/R6x-0001-cf.sml";
val _ = pr "MARK CF";
val _ = (use CF_FILE; pr "CF_PART_DONE")
  handle e => pr ("CF_PART_FAILED " ^ trunc 600 (General.exnMessage e));

val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
