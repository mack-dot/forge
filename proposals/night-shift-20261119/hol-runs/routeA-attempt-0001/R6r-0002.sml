(* R6r-0002.sml (worker A37, round 12). PROOF, NOT RUN. = round10/R6r-0001.sml with only these changes: this first comment
   and the directory R6RDIR (round12). Theory forge_refundR6Read (unchanged). Run it only after R6rx-0002 shows
   TRY_HELPER_CLOSED for every REQUIRED lemma. Every tactic UNCHECKED. Round 10 header follows. *)
(* R6r-0001.sml (worker A35, round 10). PROOF script. NOT RUN. Every tactic UNCHECKED until run.
   Theory forge_refundR6Read. Parents by loading: deps-R6r.txt = deps-R6w.txt + forge_refundR6Write (case R6w-0004).
   = round9/R6w-0004.sml (ran as R6w-0004: exit 0, EXACT_COMPLETE) with only these changes: this header, the theory name,
   the shared-files section (round10/r6r_*.sml, the SAME files as exploration R6rx-0001), the counts (4 definitions),
   the parent controls (+ forge_refundR6Write), the final control (refillBuffer_with_read_spec_V and read_event_ok_refund
   stored), names A30 -> A35. Run it only after R6rx-0001 shows TRY_HELPER_CLOSED for every REQUIRED lemma
   (r6r_steps.sml R6R_LEMMAS). Stored: definitions read_event_ok_def, INSTREAM_BUFFERED_FD_V_def, INSTREAM_STR_V_def,
   INSTREAM_STRP_V_def; theorems read_event_ok_read_into, read_event_ok_refund, STD_streams_fd0, INSTREAM_STRP_V_F_F,
   read_into_spec_R, refillBuffer_with_read_spec_V (required) and INSTREAM_BUFFERED_FD_V_IMP, INSTREAM_STR_V_IMP,
   refillBuffer_with_read_spec_STR_V (optional). Nothing with a hypothesis is stored; no cheat, no mk_thm, no axiom. *)
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
                               raise mk_HOL_ERR "A35" "tlim" "time limit");

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
val _ = new_theory "forge_refundR6Read";
fun fth thy nm = DB.fetch thy nm;   (* proof mode: a missing name is fatal *)
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));

(* ================= shared files (the same bytes as in R6rx-0001) ================= *)
val R6R_PROOF_MODE = true;
val R6RDIR = "/Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/round12/";
val _ = (pr "MARK USE r6r_common.sml"; use (R6RDIR ^ "r6r_common.sml"); pr "PART_DONE r6r_common.sml");
val _ = (pr "MARK USE r6r_steps.sml"; use (R6RDIR ^ "r6r_steps.sml"); pr "PART_DONE r6r_steps.sml");
val _ = (pr "MARK USE r6r_prove.sml"; use (R6RDIR ^ "r6r_prove.sml"); pr "PART_DONE r6r_prove.sml");

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundR6Read" @ DB.definitions "forge_refundR6Read");
val closure = "forge_refundR6Read" :: Theory.ancestry "forge_refundR6Read";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = if List.exists (fn n => n = "forge_refundR6Write") closure
        then pr "CONTROL_OK closure contains forge_refundR6Write" else raise Fail "parent forge_refundR6Write missing";
val _ = if List.exists (fn n => n = "forge_refundR6Ffi") closure
        then pr "CONTROL_OK closure contains forge_refundR6Ffi" else raise Fail "parent forge_refundR6Ffi missing";
val _ = if List.exists (fn n => n = "forge_refundRouteA2c") closure
        then pr "CONTROL_OK closure contains forge_refundRouteA2c" else raise Fail "parent forge_refundRouteA2c missing";
val _ = if List.exists (fn n => n = "TextIOProof") closure
        then pr "CONTROL_OK closure contains TextIOProof" else raise Fail "parent TextIOProof missing";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundR6Read")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundR6Read")));
val _ = pr ("STORED_NAMES " ^ String.concatWith " " (rev (!stored_names)));
val _ = if length (DB.theorems "forge_refundR6Read") = length (!stored_names) andalso
           length (DB.definitions "forge_refundR6Read") = 4
        then pr "CONTROL_OK theorems = stored list, 4 definitions" else raise Fail "unexpected number of stored items";
val _ = if Lib.mem "refillBuffer_with_read_spec_V" (!stored_names) andalso Lib.mem "read_event_ok_refund" (!stored_names)
        then pr "CONTROL_OK refillBuffer_with_read_spec_V and read_event_ok_refund stored"
        else raise Fail "refillBuffer_with_read_spec_V or read_event_ok_refund missing";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
