(* TRx-0003.sml (worker W-trace, round 2): = TRx-0001.sml with Thread.Thread. -> Thread., Thread.Mutex. -> Mutex.
   (pinned HOL, ConcIsaLib.sml lines 1, 6), shared files tr_common2.sml / tr_steps2.sml, scratch theory forge_machineTraceExplore3.
   NOT RUN. See CHANGES_TR.txt. *)
(* TRx-0001.sml (worker W-trace, Night-Shift Orchestrator A, 2026-11-19). EXPLORATION of case TR-0001. NOT RUN.
   NOT a proof attempt; no export_theory. Scratch theory forge_machineTraceExplore3. Shared files (the SAME bytes as the
   proof trace_v1.sml): tr_common.sml, tr_steps.sml; exploration-only: tr_explore_calls.sml.
   (1) every statement ASSUMEd into TH; (2) every lemma tried as a real proof in dependency order (TRY_HELPER_CLOSED);
   (3) explore_head prints the goals after every step of every lemma that did not close.
   Guard block and stepper: copied byte for byte from round13/R6r-0003.sml 23-61 and round13/R6rx-0003.sml 85-243
   (only NAMED_CONSTS changed). Every tactic and the guard UNCHECKED. ASCII only. *)
open preamble;
val _ = Globals.max_print_depth := 60;
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
val _ = (load "Timeout"; pr "TIMEOUT_HELPER Timeout.apply loaded")
  handle e => (pr ("TIMEOUT_LOAD_FAILED " ^ General.exnMessage e); raise e);
fun trunc n s = if size s <= n then s else String.substring (s, 0, n) ^ " ...";
(* ===== round13 guard (worker W-pre, static, UNCHECKED by HOL). Timeout.apply (HOL portableML/poly/concurrent/Timeout.sml
   12-31) sends ONE interrupt at the limit. In R6rx-0001 the same step stopped twice at 240 s (stdout 222, 776) and the
   third time ran on for > 25 min (stdout ends at 1096; actual_exit -15). guarded_apply = Timeout.apply plus a watchdog
   thread: GUARD_GRACE s after the limit it interrupts the step again every 5 s (interrupt state InterruptAsynch inside
   the step); GUARD_HARD s after the limit it prints WATCHDOG_HARD_EXIT and ends the process with exit code 3 (no export
   can follow). A step that ends in time is not changed. ===== *)
val GUARD_GRACE = 15;
val GUARD_HARD = 300;
fun guarded_apply (secs : int) (f : unit -> 'a) : 'a =
  let
    val self = Thread.self ()
    val lock = Mutex.mutex ()
    val finished = ref false
    val start = Time.now ()
    fun is_finished () : bool =
      (Mutex.lock lock; let val b = !finished in Mutex.unlock lock; b end)
    fun since () : int = LargeInt.toInt (Time.toSeconds (Time.- (Time.now (), start)))
    fun dog () : unit =
      if is_finished () then ()
      else if since () < secs + GUARD_GRACE then (OS.Process.sleep (Time.fromSeconds 1); dog ())
      else if since () >= secs + GUARD_HARD then
        (pr ("WATCHDOG_HARD_EXIT step still running after " ^ Int.toString (since ()) ^ " s (limit " ^
             Int.toString secs ^ " s)");
         Posix.Process.exit 0w3)
      else
        (Mutex.lock lock;
         (if !finished then () else (Thread.interrupt self handle _ => ()));
         Mutex.unlock lock;
         pr ("WATCHDOG_INTERRUPT_AGAIN after " ^ Int.toString (since ()) ^ " s (limit " ^ Int.toString secs ^ " s)");
         OS.Process.sleep (Time.fromSeconds 5);
         dog ())
    val _ = Thread.fork (fn () => (dog () handle _ => ()), [])
    fun finish () : unit = (Mutex.lock lock; finished := true; Mutex.unlock lock)
    fun run () = (Thread.setAttributes [Thread.InterruptState Thread.InterruptAsynch]; f ())
  in
    (Timeout.apply (Time.fromSeconds (Int.toLarge secs)) run () before finish ())
    handle e => (finish (); raise e)
  end;
val _ = pr "GUARD_DEFINED guarded_apply";

(* ================= LOAD (generic: the CakeML machine semantics only) ================= *)
val _ = pr "MARK LOAD";
val CK = "/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml";
val HOLX = "/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/examples/pl-semantics/lprefix_lub";
val _ = loadPath := !loadPath @ (map (fn d => CK ^ "/" ^ d)
          ["misc", "semantics/ffi", "compiler/encoders/asm", "compiler/backend/semantics"]) @ [HOLX];
fun tryload s = (load s; pr ("LOAD_OK " ^ s))
  handle e => pr ("LOAD_FAILED " ^ s ^ " " ^ trunc 300 (General.exnMessage e));
val _ = List.app tryload
  ["miscTheory", "ffiTheory", "asmPropsTheory", "targetSemTheory", "targetPropsTheory", "lprefix_lubTheory"];

val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_machineTraceExplore3";
val _ = pr "EXPLORE_MODE nothing is exported (scratch definitions and helper theorems only)";

(* ================= the stepper: LOx-0001.sml lines 420-525, copied; NAMED_CONSTS changed ================= *)
val _ = pr "EXPLORE_MODE nothing is exported; the open lemmas are never stored";
val _ = metisTools.limit := {time = SOME 20.0, infs = NONE};
val STEP_SECS = 60;
type step = string * tactic * tactic list;

(* ---------- printing ---------- *)
val NAMED_CONSTS = ["evaluate", "machine_sem", "trace_ok", "trace_next_interfer", "trace_ffi_interfer"];
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
  in guarded_apply STEP_SECS (fn () => prefix_of ts g ctxt) end;
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
              val (gs1, _) = guarded_apply HEAD_SECS (fn () => tac g ctxt)
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

(* ================= replay helpers (round13/R6rx-0003.sml 245-252) ================= *)
fun showg tag ((asl, w) : goal) = (pr ("SHOW " ^ tag);
   List.app (fn a => pr ("  ASM " ^ trunc 600 (term_to_string a))) asl;
   pr ("  GOAL " ^ trunc 2500 (term_to_string w)));
fun tlim secs (tac : tactic) (g : goal) (ctxt : Context.t) =
  guarded_apply secs (fn () => tac g ctxt)
  handle Timeout.TIMEOUT _ => (pr ("TIMEOUT_CANDIDATE after " ^ Int.toString secs ^ " s");
                               raise mk_HOL_ERR "WTR" "tlim" "time limit");

(* ================= shared files ================= *)
val TR_PROOF_MODE = false;
val TRDIR = "/Users/mackianni/forge/results/night-shift-20261119/orch-A/trace/";
fun use_part (f : string) : bool =
  (pr ("MARK USE " ^ f); use (TRDIR ^ f); pr ("PART_DONE " ^ f); true)
  handle e => (pr ("PART_FAILED " ^ f ^ " " ^ trunc 800 (General.exnMessage e)); false);
val ok_common = use_part "tr_common2.sml";
val ok_steps = ok_common andalso use_part "tr_steps2.sml";
val _ = if ok_steps then ignore (use_part "tr_explore_calls.sml") else pr "EXPLORE_SKIPPED shared files failed";
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
