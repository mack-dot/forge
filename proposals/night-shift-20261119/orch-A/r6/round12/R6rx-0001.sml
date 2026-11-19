(* R6rx-0001.sml (worker A35, round 10). EXPLORATION of the R6 READ side. NOT RUN. NOT a proof attempt; no export_theory.
   = round9/R6wx-0004.sml (ran as R6wx-0004: exit 0, EXPLORE_COMPLETE) with only these changes: this header, the scratch
   theory name forge_refundR6RExplore1, NAMED_CONSTS + read_event_ok, the shared-files section (round10/r6r_common.sml,
   r6r_steps.sml, r6r_explore_calls.sml; flag R6R_PROOF_MODE; directory R6RDIR), names A33 -> A35.
   Parents loaded by the runner: deps-R6r.txt = deps-R6w.txt + forge_refundR6Write (R6w-0004). In the scratch theory,
   new_definition (four definitions) and save_thm of hypothesis-free lemmas happen (later lemmas need REAL prerequisites:
   xlet_auto_spec/xapp_spec reject a spec with a hypothesis); nothing is exported. Ends with EXPLORE_COMPLETE.
   Every tactic UNCHECKED. *)
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
val _ = new_theory "forge_refundR6RExplore1";
val _ = pr "EXPLORE_MODE nothing is exported (scratch definitions and helper theorems only)";

(* fth : string -> string -> thm. A missing name prints FETCH_FAILED and gives TRUTH (no static error). *)
fun fth thy nm = DB.fetch thy nm
  handle e => (pr ("FETCH_FAILED " ^ thy ^ "." ^ nm ^ " " ^ trunc 200 (General.exnMessage e)); TRUTH);


(* ================= the stepper: LOx-0001.sml lines 420-525, copied; NAMED_CONSTS changed ================= *)
val _ = pr "EXPLORE_MODE nothing is exported; the open lemmas are never stored";
val _ = metisTools.limit := {time = SOME 20.0, infs = NONE};
val STEP_SECS = 60;
type step = string * tactic * tactic list;

(* ---------- printing ---------- *)
val NAMED_CONSTS = ["arm8_run", "evaluate", "machine_sem", "refund_valid_event", "read_event_ok"];
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

(* ================= replay helpers (R6ffi-0002.sml lines 18-24, names A30 -> A35) ================= *)
fun showg tag ((asl, w) : goal) = (pr ("SHOW " ^ tag);
   List.app (fn a => pr ("  ASM " ^ trunc 600 (term_to_string a))) asl;
   pr ("  GOAL " ^ trunc 2500 (term_to_string w)));
fun tlim secs (tac : tactic) (g : goal) (ctxt : Context.t) =
  Timeout.apply (Time.fromSeconds (Int.toLarge secs)) (fn () => tac g ctxt) ()
  handle Timeout.TIMEOUT _ => (pr ("TIMEOUT_CANDIDATE after " ^ Int.toString secs ^ " s");
                               raise mk_HOL_ERR "A35" "tlim" "time limit");

(* ================= shared files ================= *)
val R6R_PROOF_MODE = false;
val R6RDIR = "/Users/USER/forge/results/night-shift-20261119/orch-A/r6/round10/";
fun use_part (f : string) : bool =
  (pr ("MARK USE " ^ f); use (R6RDIR ^ f); pr ("PART_DONE " ^ f); true)
  handle e => (pr ("PART_FAILED " ^ f ^ " " ^ trunc 800 (General.exnMessage e)); false);
val ok_common = use_part "r6r_common.sml";
val ok_steps = ok_common andalso use_part "r6r_steps.sml";
(* explore_head at top level would not see the values of a failed use; run them from a third small file *)
val _ = if ok_steps then ignore (use_part "r6r_explore_calls.sml") else pr "EXPLORE_SKIPPED shared files failed";
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
