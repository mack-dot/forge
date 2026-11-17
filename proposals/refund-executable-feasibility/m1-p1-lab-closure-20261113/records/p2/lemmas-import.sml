load "labSemTheory"; load "labPropsTheory";
open preamble labSemTheory labLangTheory forge_labRegionInvariantTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val expected = [
 ("asm_inst_val_inv", ``!i s. (!w. G (Word w)) /\ val_inv G s ==> val_inv G (labSem$asm_inst i s)``),
 ("write_bytearray_val_inv", ``!bs w m. (!w. G (Word w)) /\ (!a. G (m a)) ==> !a. G (wordSem$write_bytearray w bs m dm be a)``)];
val _ = List.app (fn (n, tm) =>
  let val th = DB.fetch "forge_labRegionInvariant" n in
    if aconv tm (concl th) then () else raise Fail ("Exact statement mismatch: " ^ n);
    tags n th; pr ("IMPORTED " ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val _ = if length (DB.theorems "forge_labRegionInvariant") = 2 then () else raise Fail "Unexpected theorem count";
val _ = List.app (fn (n, th) => pr ("DEFINITION " ^ n ^ "\n" ^ thm_to_string th)) (DB.definitions "forge_labRegionInvariant");
val closure = "forge_labRegionInvariant" :: Theory.ancestry "forge_labRegionInvariant";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "P2_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
