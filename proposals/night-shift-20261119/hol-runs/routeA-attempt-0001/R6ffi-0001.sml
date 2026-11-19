(* R6ffi-0001.sml: worker A30 (Night-Shift Orchestrator A). PROOF script. NOT RUN. Every tactic UNCHECKED until run.
   Theory forge_refundR6Ffi. Parents by loading: deps-R6ffi.txt = deps-R6x.txt + forge_refundR6Base (case R6base-0001).
   It reads the SAME shared files as exploration R6x-0004 (round4/r6_common.sml, round4/r6_steps.sml) and replays each
   step list on the head goal: step = FIRST over (main :: alternatives), each candidate under the same 240 s limit as the
   exploration's explore_head, in the same order. So the proof takes the same path as the exploration, as long as no
   candidate is near its time limit. Run it only after R6x-0004 shows EXPLORE_HEAD_CLOSED for all four lemmas.
   Stored: definitions IOxV_def, IOFS_V_def, STDIO_V_def; theorems IOFS_V_FFI_part_hprop (X9), IOxV_IMP_IOx (X8),
   writei_spec_V, read_into_spec_V. Nothing with a hypothesis is stored; no cheat, no mk_thm, no axiom.
   Harness: R6base-0001.sml lines 16-36 (pr, Timeout, tags, trunc, showg, tlim), names A25 -> A30. *)
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
val _ = new_theory "forge_refundR6Ffi";
fun fth thy nm = DB.fetch thy nm;   (* proof mode: a missing name is fatal *)
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));

(* ================= shared files (the same bytes as in R6x-0004) ================= *)
val R6_PROOF_MODE = true;
val R6DIR = "/Users/mackianni/forge/results/night-shift-20261119/orch-A/r6/round4/";
val _ = (pr "MARK USE r6_common.sml"; use (R6DIR ^ "r6_common.sml"); pr "PART_DONE r6_common.sml");
val _ = (pr "MARK USE r6_steps.sml"; use (R6DIR ^ "r6_steps.sml"); pr "PART_DONE r6_steps.sml");
(* r6_prove.sml holds the replay and the stores: it refers to values of the two shared files *)
val _ = (pr "MARK USE r6_prove.sml"; use (R6DIR ^ "r6_prove.sml"); pr "PART_DONE r6_prove.sml");

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundR6Ffi" @ DB.definitions "forge_refundR6Ffi");
val closure = "forge_refundR6Ffi" :: Theory.ancestry "forge_refundR6Ffi";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = if List.exists (fn n => n = "forge_refundR6Base") closure
        then pr "CONTROL_OK closure contains forge_refundR6Base" else raise Fail "parent forge_refundR6Base missing";
val _ = if List.exists (fn n => n = "TextIOProof") closure
        then pr "CONTROL_OK closure contains TextIOProof" else raise Fail "parent TextIOProof missing";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundR6Ffi")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundR6Ffi")));
val _ = if length (DB.theorems "forge_refundR6Ffi") = 4 andalso length (DB.definitions "forge_refundR6Ffi") = 3
        then pr "CONTROL_OK 4 theorems, 3 definitions" else raise Fail "unexpected number of stored items";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
