load "lab_to_targetProofTheory";
open preamble BasicProvers ffiTheory wordSemTheory labSemTheory labPropsTheory lab_to_targetTheory lab_filterProofTheory
     asmTheory asmSemTheory asmPropsTheory targetSemTheory targetPropsTheory backendPropsTheory lab_to_targetProofTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
