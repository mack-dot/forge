(* R6t-0002.sml (worker W-top, round14). PROOF, NOT RUN. = round11/R6t-0001.sml with only: this comment, the round13
   guard block after trunc (guarded_apply replaces Timeout.apply in tlim), R6TDIR = round14/. Theory forge_refundR6Top,
   checks and counts unchanged. Every tactic and the guard are UNCHECKED. Round 11 header follows. *)
(* R6t-0001.sml (worker A36, Night-Shift Orchestrator A, round 11). PROOF script. NOT RUN. Every tactic UNCHECKED until run.
   Theory forge_refundR6Top. Parents by loading: deps-R6t.txt = deps-R6w.txt (attempt folder, 137 lines) + the two
   files of forge_refundR6Write (case R6w-0004).
   Base = round9/R6w-0004.sml (ran as R6w-0004: exit 0, EXACT_COMPLETE); kept: open, harness (pr, Timeout, tags, trunc,
   showg, tlim), LOAD, checks. Changed: this header, theory name, the shared-files section (round11/r6t_*.sml, the SAME
   files as exploration R6tx-0001), the counts (0 definitions; theorems = the stored list), the parent controls.
   Run it only after R6tx-0001 shows EXPLORE_HEAD_CLOSED for every REQUIRED lemma (r6t_steps.sml R6T_LEMMAS).
   Nothing with a hypothesis is stored; no cheat, no mk_thm, no axiom, no new definition. *)
open preamble basis_ffiTheory fsFFITheory fsFFIPropsTheory TextIOProofTheory MarshallingTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
val _ = (load "Timeout"; pr "TIMEOUT_HELPER Timeout.apply loaded")
  handle e => (pr ("TIMEOUT_LOAD_FAILED " ^ General.exnMessage e); raise e);
fun trunc n s = if size s <= n then s else String.substring (s, 0, n) ^ " ...";
(* ===== round13 guard (worker W-pre, static, UNCHECKED by HOL). Timeout.apply (HOL portableML/poly/concurrent/Timeout.sml
   12-31) sends ONE interrupt at the limit. In R6rx-0001 the same step stopped twice at 240 s (stdout 222, 776) and the
   third time ran on for > 25 min (stdout ends at 1096; actual_exit -15). Same pattern in R6tx-0001 (stdout ends at
   171, actual_exit -15). guarded_apply = Timeout.apply plus a watchdog
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
val _ = metisTools.limit := {time = SOME 20.0, infs = NONE};   (* = the exploration's value *)
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun showg tag ((asl, w) : goal) = (pr ("SHOW " ^ tag);
   List.app (fn a => pr ("  ASM " ^ trunc 600 (term_to_string a))) asl;
   pr ("  GOAL " ^ trunc 2500 (term_to_string w)));
fun tlim secs (tac : tactic) (g : goal) (ctxt : Context.t) =
  guarded_apply secs (fn () => tac g ctxt)
  handle Timeout.TIMEOUT _ => (pr ("TIMEOUT_CANDIDATE after " ^ Int.toString secs ^ " s");
                               raise mk_HOL_ERR "A36" "tlim" "time limit");

(* ================= LOAD (as R6x-0004 lines 9-17, but a load failure is fatal) ================= *)
val _ = pr "MARK LOAD";
val CK = "/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml";
val _ = loadPath := !loadPath @ map (fn d => CK ^ "/" ^ d)
          ["characteristic", "basis", "basis/pure", "translator", "semantics", "semantics/proofs",
           "semantics/ffi", "compiler/backend/semantics", "misc"];
val _ = List.app (fn s => (load s; pr ("LOAD_OK " ^ s)))
  ["cfHeapsBaseTheory", "cfStoreTheory", "cfMainTheory", "cfAppTheory", "TextIOProofTheory", "basis_ffiTheory",
   "ml_progTheory", "semanticsPropsTheory", "targetSemTheory", "targetPropsTheory", "rich_listTheory",
   "forge_refundStdioProgTheory", "forge_refundWholeProgTheory", "cfLib", "basis_ffiLib", "basisFunctionsLib"];

val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundR6Top";
fun fth thy nm = DB.fetch thy nm;   (* proof mode: a missing name is fatal *)
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));

(* ================= shared files (the same bytes as in R6tx-0001) ================= *)
val R6T_PROOF_MODE = true;
val R6TDIR = "/Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/round14/";
val _ = (pr "MARK USE r6t_common.sml"; use (R6TDIR ^ "r6t_common.sml"); pr "PART_DONE r6t_common.sml");
val _ = (pr "MARK USE r6t_steps.sml"; use (R6TDIR ^ "r6t_steps.sml"); pr "PART_DONE r6t_steps.sml");
val _ = (pr "MARK USE r6t_prove.sml"; use (R6TDIR ^ "r6t_prove.sml"); pr "PART_DONE r6t_prove.sml");

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundR6Top" @ DB.definitions "forge_refundR6Top");
val closure = "forge_refundR6Top" :: Theory.ancestry "forge_refundR6Top";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
fun need_parent (t : string) : unit =
  if List.exists (fn n => n = t) closure then pr ("CONTROL_OK closure contains " ^ t)
  else raise Fail ("parent " ^ t ^ " missing");
val _ = List.app need_parent ["forge_refundR6Write", "forge_refundR6Ffi", "forge_refundR6Base", "forge_refundRouteA2c",
                              "TextIOProof", "basis_ffi", "cfMain"];
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundR6Top")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundR6Top")));
val _ = pr ("STORED_NAMES " ^ String.concatWith " " (rev (!stored_names)));
val _ = if length (DB.theorems "forge_refundR6Top") = length (!stored_names) andalso
           length (DB.definitions "forge_refundR6Top") = 0
        then pr "CONTROL_OK theorems = stored list, 0 definitions" else raise Fail "unexpected number of stored items";
val _ = List.app (fn n => if Lib.mem n (!stored_names) then pr ("CONTROL_OK stored " ^ n)
                          else raise Fail (n ^ " missing"))
          ["init_heap_V", "whole_prog_spec_V_events"];
(* the stored statements must be the statements of r6t_common.sml (aconv) *)
val _ = List.app (fn (n, t, _, _) =>
          if Lib.mem n (!stored_names) then
            (if aconv (concl (DB.fetch "forge_refundR6Top" n)) t then pr ("CONTROL_OK statement " ^ n)
             else raise Fail ("statement changed: " ^ n))
          else ()) R6T_LEMMAS;
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
