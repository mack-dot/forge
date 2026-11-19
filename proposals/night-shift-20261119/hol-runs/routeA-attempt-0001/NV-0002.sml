(* NV-0001.sml (worker W-nv, Night-Shift Orchestrator A). PROOF script. NOT RUN. Every tactic UNCHECKED until run.
   Theory forge_refundShapeSat. Parents by loading: deps-NV.txt = deps-MG.txt + forge_refundRouteA2d (L2d-0001)
   + forge_refundInputSat (round4 slide-s3-copy fs-r4-0001). Run it only after NVx-0001 shows TRY_HELPER_CLOSED for
   every REQUIRED lemma (REQUIRED_NOT_CLOSED empty). Harness and guard = round13 R6r-0003.sml (guard lines copied
   byte-identical). Stored: refund_ffi_contract_at_imp_on, refund_shape_premises_satisfiable_for_every_request,
   refund_shape_premises_satisfiable (NV1), refund_shape_run_is_accepted (NV2) (required); refund_abs_env_fields,
   refund_shape_premises_hold_at_a_constructed_state (optional). No definition. Nothing with a hypothesis is stored;
   no cheat, no mk_thm, no axiom. MODEL ONLY: nothing here is about the real machine. *)
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
                               raise mk_HOL_ERR "W-nv" "tlim" "time limit");

val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundShapeSat";
fun fth thy nm = DB.fetch thy nm;   (* proof mode: a missing name is fatal *)
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));

(* ================= shared files (the same bytes as in NVx-0001) ================= *)
val NV_PROOF_MODE = true;
val NVDIR = "/Users/mackianni/forge/results/night-shift-20261119/orch-A/nonvacuity/";
val _ = (pr "MARK USE nv_common.sml"; use (NVDIR ^ "nv_common.sml"); pr "PART_DONE nv_common.sml");
val _ = (pr "MARK USE nv_steps.sml"; use (NVDIR ^ "nv_steps.sml"); pr "PART_DONE nv_steps.sml");
val _ = (pr "MARK USE nv_prove.sml"; use (NVDIR ^ "nv_prove.sml"); pr "PART_DONE nv_prove.sml");

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = (pr "MARK USE nv_controls.sml"; use (NVDIR ^ "nv_controls.sml"); pr "PART_DONE nv_controls.sml");
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundShapeSat" @ DB.definitions "forge_refundShapeSat");
val _ = pr "CONTROL_OK every stored theorem: no hypothesis, no oracle, no axiom tag";
val closure = "forge_refundShapeSat" :: Theory.ancestry "forge_refundShapeSat";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 andalso List.all (fn a => String.isPrefix "bool." a) axs
        then pr "CONTROL_OK closure axioms are the four of bool" else raise Fail "closure axioms are not the four of bool";
val _ = List.app (fn p => if List.exists (fn n => n = p) closure then pr ("CONTROL_OK closure contains " ^ p)
                          else raise Fail ("parent missing " ^ p))
          ["forge_refundRouteA2d", "forge_refundInputSat", "forge_refundRouteA1", "forge_refundModelFrame"];
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundShapeSat")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundShapeSat")));
val _ = pr ("STORED_NAMES " ^ String.concatWith " " (rev (!stored_names)));
val _ = if length (DB.theorems "forge_refundShapeSat") = length (!stored_names) andalso
           null (DB.definitions "forge_refundShapeSat")
        then pr "CONTROL_OK theorems = stored list, 0 definitions" else raise Fail "unexpected number of stored items";
val _ = if List.all (fn n => Lib.mem n (!stored_names))
             ["refund_ffi_contract_at_imp_on", "refund_shape_premises_satisfiable_for_every_request",
              "refund_shape_premises_satisfiable", "refund_shape_run_is_accepted"]
        then pr "CONTROL_OK NV1 and NV2 stored" else raise Fail "a required theorem is missing";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
