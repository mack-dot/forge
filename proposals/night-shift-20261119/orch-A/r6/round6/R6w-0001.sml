(* R6w-0001.sml: worker A33 (Night-Shift Orchestrator A). PROOF script. NOT RUN. Every tactic UNCHECKED until run.
   Theory forge_refundR6Write. Parents by loading: deps-R6w.txt = deps-R6ffi.txt + forge_refundR6Ffi (case R6ffi-0002).
   Base = round5/R6ffi-0002.sml (ran as R6ffi-0002: exit 0, EXACT_COMPLETE); kept: open, harness (pr, Timeout, tags,
   trunc, showg, tlim), LOAD, checks. Changed: header, theory name, the shared-files section (round6/r6w_*.sml, the
   SAME files as exploration R6wx-0001), the counts (1 definition; theorems = the stored list), the parent control.
   Run it only after R6wx-0001 shows EXPLORE_HEAD_CLOSED for every REQUIRED lemma (r6w_steps.sml R6W_LEMMAS).
   Stored: definition write_event_ok_def; theorems write_event_ok_writei, write_event_ok_refund, SEG_APPEND3_W,
   IOxV_FFI_part_IN, UNIQUE_IOFS_V, IOFS_V_HPROP_INJ, writei_spec_W, write_spec_V, output_aux_spec_V, output_spec_V,
   output_STDIO_spec_V, print_spec_V, print_spec_refund (required) and STDIO_V_numchars, UNIQUE_STDIO_V,
   STDIO_V_HPROP_INJ, STD_streams_fd0 (optional). Nothing with a hypothesis is stored; no cheat, no mk_thm, no axiom. *)
open preamble basis_ffiTheory fsFFITheory fsFFIPropsTheory TextIOProofTheory MarshallingTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
val _ = (load "Timeout"; pr "TIMEOUT_HELPER Timeout.apply loaded")
  handle e => (pr ("TIMEOUT_LOAD_FAILED " ^ General.exnMessage e); raise e);
fun trunc n s = if size s <= n then s else String.substring (s, 0, n) ^ " ...";
val _ = metisTools.limit := {time = SOME 20.0, infs = NONE};   (* = the exploration's value *)
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun showg tag ((asl, w) : goal) = (pr ("SHOW " ^ tag);
   List.app (fn a => pr ("  ASM " ^ trunc 600 (term_to_string a))) asl;
   pr ("  GOAL " ^ trunc 2500 (term_to_string w)));
fun tlim secs (tac : tactic) (g : goal) (ctxt : Context.t) =
  Timeout.apply (Time.fromSeconds (Int.toLarge secs)) (fn () => tac g ctxt) ()
  handle Timeout.TIMEOUT _ => (pr ("TIMEOUT_CANDIDATE after " ^ Int.toString secs ^ " s");
                               raise mk_HOL_ERR "A30" "tlim" "time limit");

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
val _ = new_theory "forge_refundR6Write";
fun fth thy nm = DB.fetch thy nm;   (* proof mode: a missing name is fatal *)
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));

(* ================= shared files (the same bytes as in R6wx-0001) ================= *)
val R6W_PROOF_MODE = true;
val R6WDIR = "/Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/round6/";
val _ = (pr "MARK USE r6w_common.sml"; use (R6WDIR ^ "r6w_common.sml"); pr "PART_DONE r6w_common.sml");
val _ = (pr "MARK USE r6w_steps.sml"; use (R6WDIR ^ "r6w_steps.sml"); pr "PART_DONE r6w_steps.sml");
val _ = (pr "MARK USE r6w_prove.sml"; use (R6WDIR ^ "r6w_prove.sml"); pr "PART_DONE r6w_prove.sml");

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundR6Write" @ DB.definitions "forge_refundR6Write");
val closure = "forge_refundR6Write" :: Theory.ancestry "forge_refundR6Write";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = if List.exists (fn n => n = "forge_refundR6Ffi") closure
        then pr "CONTROL_OK closure contains forge_refundR6Ffi" else raise Fail "parent forge_refundR6Ffi missing";
val _ = if List.exists (fn n => n = "forge_refundRouteA2c") closure
        then pr "CONTROL_OK closure contains forge_refundRouteA2c" else raise Fail "parent forge_refundRouteA2c missing";
val _ = if List.exists (fn n => n = "TextIOProof") closure
        then pr "CONTROL_OK closure contains TextIOProof" else raise Fail "parent TextIOProof missing";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundR6Write")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundR6Write")));
val _ = pr ("STORED_NAMES " ^ String.concatWith " " (rev (!stored_names)));
val _ = if length (DB.theorems "forge_refundR6Write") = length (!stored_names) andalso
           length (DB.definitions "forge_refundR6Write") = 1
        then pr "CONTROL_OK theorems = stored list, 1 definition" else raise Fail "unexpected number of stored items";
val _ = if Lib.mem "print_spec_refund" (!stored_names) then pr "CONTROL_OK print_spec_refund stored"
        else raise Fail "print_spec_refund missing";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
