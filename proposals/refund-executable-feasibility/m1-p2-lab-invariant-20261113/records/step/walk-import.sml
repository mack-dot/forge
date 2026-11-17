load "labSemTheory"; load "labPropsTheory";
open preamble labSemTheory labLangTheory forge_labRegionInvariantTheory forge_labRegionStepTheory forge_labRegionWalkTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val expected = [
 ("hyp_walk_region_hyp", ``!okp code. hyp_walk okp (\n1 n2. labSem$loc_to_pc n1 n2 code) 0 code ==> region_hyp (loc_good okp code) okp code``),
 ("hyp_walk_fetch", ``!okp rs k secs. hyp_walk okp rs k secs ==>
   !pc line. labSem$asm_fetch_aux pc secs = SOME line /\ okp (k + pc) ==> line_ok okp rs (k + pc) line``)];
val _ = List.app (fn (n, tm) =>
  let val th = DB.fetch "forge_labRegionWalk" n in
    if aconv tm (concl th) then () else raise Fail ("Exact statement mismatch: " ^ n);
    tags n th; pr ("IMPORTED " ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val _ = List.app (fn (n, th) => pr ("DEFINITION " ^ n ^ "\n" ^ thm_to_string th)) (DB.definitions "forge_labRegionWalk");
val closure = "forge_labRegionWalk" :: Theory.ancestry "forge_labRegionWalk";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "P2_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
