(* Exclusion chain: from the premises of the published compile-level lemma to the target-level installer exclusion. *)
open preamble BasicProvers ffiTheory wordSemTheory labSemTheory labPropsTheory lab_to_targetTheory lab_filterProofTheory
     asmTheory asmSemTheory asmPropsTheory targetSemTheory targetPropsTheory backendPropsTheory lab_to_targetProofTheory
     forge_targetInstallPrefixTheory forge_simZeroCaseTheory forge_simLayoutTheory forge_simRootTheory forge_simReplayTheory
     forge_refundLabFilteredTheory forge_refundExactExclusionTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundExclusionChain";
(* In this heap some bare names of the published text parse to constants of backend_asm. Remove those mappings,
   so the published text parses as in the published build. A constant-origin check at the end fails closed. *)
val _ = List.app (fn c => (let val {Name,Thy,...} = dest_thy_const c in Parse.temp_remove_ovl_mapping Name {Name=Name,Thy=Thy} end handle _ => ()))
          (Theory.constants "backend_asm");
(* The published text uses these names as variables; the refund compile theory defines constants with the same names. *)
val _ = List.app (fn n => (Parse.hide n; ())) ["code", "data", "ffis", "conf", "info", "name"];
fun say0 pfx s g = (print (pfx ^ ": " ^ s ^ "\n"); ALL_TAC g)
val s1 = ``s1:('a,lab_to_target$config,'ffi) labSem$state``;
val IMP_LEMMA = METIS_PROVE [] ``(a ==> b) ==> (b ==> c) ==> (a ==> c)``
fun dbgf tag name (g as (asl, w)) =
  (pr ("SHOWF " ^ tag);
   List.app (fn a => if String.isSubstring name (term_to_string a) andalso size (term_to_string a) < 900 then pr ("  ASM " ^ term_to_string a) else ()) asl;
   pr ("  GOAL " ^ term_to_string w); ALL_TAC g);
