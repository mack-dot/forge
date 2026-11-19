(* trace_v1.sml = case TR-0001 (worker W-trace, Night-Shift Orchestrator A, 2026-11-19). PROOF. NOT RUN.
   Every definition, tactic and the guard is UNCHECKED until a run ends with exit 0 and EXACT_COMPLETE.
   Theory forge_machineTrace: the model side of graph link X8 ("real process refines machine model"), GENERIC in the
   machine configuration mc : ('w,'s,'p) machine_config and the FFI state st : 'ffi ffi_state. It names NO real machine,
   no refund constant and no arm8 constant (checked at the end: CONTROL_OK generic).
   Main results: evaluate_follows_trace (T-TRACE), trace_io (T-IO), trace_terminate / trace_fail (T-PREFIX),
   trace_next_interfer_ok (interference_ok), trace_ffi_interfer_guard / _off (guard facts), the two one-event lemmas.
   Run it only after TRx-0001 shows TRY_HELPER_CLOSED for every REQUIRED lemma (tr_steps.sml TR_LEMMAS).
   Guard block: copied byte for byte from round13/R6r-0003.sml 23-61. No cheat, no mk_thm, no axiom. ASCII only. *)
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
                               raise mk_HOL_ERR "WTR" "tlim" "time limit");

(* ================= LOAD (generic: the CakeML machine semantics only) ================= *)
val _ = pr "MARK LOAD";
val CK = "/Users/USER/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml";
val HOLX = "/Users/USER/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/examples/pl-semantics/lprefix_lub";
val _ = loadPath := !loadPath @ (map (fn d => CK ^ "/" ^ d)
          ["misc", "semantics/ffi", "compiler/encoders/asm", "compiler/backend/semantics"]) @ [HOLX];
fun tryload s = (load s; pr ("LOAD_OK " ^ s))
  handle e => pr ("LOAD_FAILED " ^ s ^ " " ^ trunc 300 (General.exnMessage e));
val _ = List.app (fn s => (load s; pr ("LOAD_OK " ^ s)))
  ["miscTheory", "ffiTheory", "asmPropsTheory", "targetSemTheory", "targetPropsTheory"];
val _ = tryload "lprefix_lubTheory";   (* only the optional Diverge corollary needs it *)

val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_machineTrace";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));

(* ================= shared files (the same bytes as in TRx-0001) ================= *)
val TR_PROOF_MODE = true;
val TRDIR = "/Users/USER/forge/results/night-shift-20261119/orch-A/trace/";
val _ = (pr "MARK USE tr_common.sml"; use (TRDIR ^ "tr_common.sml"); pr "PART_DONE tr_common.sml");
val _ = (pr "MARK USE tr_steps.sml"; use (TRDIR ^ "tr_steps.sml"); pr "PART_DONE tr_steps.sml");
val _ = (pr "MARK USE tr_prove.sml"; use (TRDIR ^ "tr_prove.sml"); pr "PART_DONE tr_prove.sml");

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val THY = "forge_machineTrace";
val _ = List.app (fn (n, th) => tags n th) (DB.theorems THY @ DB.definitions THY);
val _ = if null (DB.axioms THY) then pr "CONTROL_OK no axiom in forge_machineTrace" else raise Fail "axiom in theory";
val closure = THY :: Theory.ancestry THY;
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = List.app (fn n => if List.exists (fn m => m = n) closure then pr ("CONTROL_OK closure contains " ^ n)
                          else raise Fail ("parent missing " ^ n))
          ["targetSem", "targetProps", "ffi", "misc", "asmProps"];
(* generic: no stored theorem or definition of this theory mentions a constant of a forge_ theory (other than this
   one) or of a theory whose name contains arm8, x64, riscv, mips, ag32 or refund *)
val bad_thy_parts = ["arm8", "x64", "riscv", "mips", "ag32", "refund"];
fun bad_thy (t : string) : bool =
  (t <> THY andalso String.isPrefix "forge_" t) orelse
  List.exists (fn p => String.isSubstring p t) bad_thy_parts;
val const_thys =
  Lib.mk_set (List.concat (map (fn (_, th) =>
    map (fn c => #Thy (dest_thy_const c)) (find_terms is_const (concl th)))
    (DB.theorems THY @ DB.definitions THY)));
val _ = pr ("CONSTANT_THEORIES " ^ String.concatWith " " const_thys);
val _ = if List.exists bad_thy const_thys then raise Fail "a stored item mentions a machine-specific or forge constant"
        else pr "CONTROL_OK generic: no forge_, refund or ISA constant in any stored item";
val REQUIRED = map #1 (List.filter #4 TR_LEMMAS);
val _ = if List.all (fn n => Lib.mem n (!stored_names)) REQUIRED
        then pr ("CONTROL_OK all " ^ Int.toString (length REQUIRED) ^ " required lemmas stored")
        else raise Fail "a required lemma is missing";
val _ = pr ("STORED_NAMES " ^ String.concatWith " " (rev (!stored_names)));
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems THY)));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions THY)));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
