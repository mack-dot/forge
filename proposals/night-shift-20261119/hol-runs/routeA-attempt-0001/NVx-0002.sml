(* NVx-0001.sml (worker W-nv, Night-Shift Orchestrator A). EXPLORATION. NOT RUN. NOT a proof attempt; no export_theory.
   Scratch theory forge_refundShapeSatExplore1 (never exported). Parents by loading: deps-NV.txt (as NV-0001).
   Reads the SAME shared files as NV-0001.sml (nv_common.sml, nv_steps.sml) plus nv_explore_calls.sml and
   nv_controls.sml. Each lemma: a WALK that prints the goals after every step, then TRY_HELPER = the proof's replay in
   TAC_PROOF; closed hypothesis-free lemmas are saved in the scratch theory so later lemmas use REAL prerequisites.
   Harness and guard = round13 R6rx-0003.sml / R6r-0003.sml (guard lines copied byte-identical).
   Ends with EXPLORE_COMPLETE. Every tactic UNCHECKED. MODEL ONLY. *)
open preamble targetSemTheory targetPropsTheory;
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
val _ = metisTools.limit := {time = SOME 20.0, infs = NONE};
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun showg tag ((asl, w) : goal) = (pr ("SHOW " ^ tag);
   List.app (fn a => pr ("  ASM " ^ trunc 600 (term_to_string a))) asl;
   pr ("  GOAL " ^ trunc 2500 (term_to_string w)));
fun tlim secs (tac : tactic) (g : goal) (ctxt : Context.t) =
  guarded_apply secs (fn () => tac g ctxt)
  handle Timeout.TIMEOUT _ => (pr ("TIMEOUT_CANDIDATE after " ^ Int.toString secs ^ " s");
                               raise mk_HOL_ERR "W-nv" "tlim" "time limit");

val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundShapeSatExplore1";
val _ = pr "EXPLORE_MODE nothing is exported (scratch theorems only)";
(* fth : a missing name prints FETCH_FAILED and gives TRUTH (the statement builder then reports STATEMENT_FAILED) *)
fun fth thy nm = DB.fetch thy nm
  handle e => (pr ("FETCH_FAILED " ^ thy ^ "." ^ nm ^ " " ^ trunc 200 (General.exnMessage e)); TRUTH);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));

val NV_PROOF_MODE = false;
val NVDIR = "/Users/mackianni/forge/results/night-shift-20261119/orch-A/nonvacuity/";
val _ = (pr "MARK USE nv_common.sml"; use (NVDIR ^ "nv_common.sml"); pr "PART_DONE nv_common.sml");
val _ = (pr "MARK USE nv_steps.sml"; use (NVDIR ^ "nv_steps.sml"); pr "PART_DONE nv_steps.sml");
val _ = (pr "MARK USE nv_explore_calls.sml"; use (NVDIR ^ "nv_explore_calls.sml"); pr "PART_DONE nv_explore_calls.sml");
val _ = (pr "MARK USE nv_controls.sml"; use (NVDIR ^ "nv_controls.sml"); pr "PART_DONE nv_controls.sml");
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
