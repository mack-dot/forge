(* Fresh import; expected statements are written out. *)
load "labSemTheory"; load "labPropsTheory";
open preamble labSemTheory labLangTheory forge_labRegionInvariantTheory forge_labRegionStepTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val one_step_expected = ``!s res t. region_inv G OK code s /\ labSem$evaluate s = (res,t) ==>
   (?s2. labSem$evaluate s2 = (res,t) /\ region_inv G OK code s2 /\ s2.clock < s.clock) \/ t = s``;
val prefix_expected = ``!s k res t. region_inv G OK code s /\ labSem$evaluate (s with clock := k) = (res,t) ==>
   region_inv G OK code t /\ OK t.pc /\ t.code = code /\ (!i bs n. labSem$asm_fetch t <> SOME (LabAsm Install i bs n))``;
val expected = [
 ("region_one_step", one_step_expected),
 ("region_run", ``!k s res t. s.clock = k /\ region_inv G OK code s /\ labSem$evaluate s = (res,t) ==> region_inv G OK code t``),
 ("region_prefix", prefix_expected),
 ("region_hyp_witness", ``region_hyp (\v. T) (\p. T) []``),
 ("region_step_callffi", ``!s res t name i bs n code G OK. region_inv G OK code s /\ s.clock <> 0 /\
    labSem$asm_fetch s = SOME (LabAsm (CallFFI name) i bs n) /\ labSem$evaluate s = (res,t) ==>
    (?s2. labSem$evaluate s2 = (res,t) /\ region_inv G OK code s2 /\ s2.clock < s.clock) \/ t = s``)];
val _ = List.app (fn (n, tm) =>
  let val th = DB.fetch "forge_labRegionStep" n in
    (* Equal up to the order of the outer universal quantifiers (GEN_ALL fixes that order). *)
    if aconv (snd (strip_forall tm)) (snd (strip_forall (concl th))) andalso
       HOLset.equal (HOLset.addList (empty_tmset, fst (strip_forall tm)), HOLset.addList (empty_tmset, fst (strip_forall (concl th))))
       andalso null (free_vars (concl th)) = null (free_vars tm)
    then () else raise Fail ("Exact statement mismatch: " ^ n);
    tags n th; pr ("IMPORTED " ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val names = map fst (DB.theorems "forge_labRegionStep");
val _ = pr ("THEOREM_NAMES " ^ String.concatWith " " names);
val _ = List.app (fn n => tags n (DB.fetch "forge_labRegionStep" n)) names;
val _ = if length (List.filter (String.isPrefix "region_step_") names) = 11 then () else raise Fail "Expected eleven branch lemmas";
val _ = List.app (fn n => pr ("DEFINITION " ^ n ^ "\n" ^ thm_to_string (DB.fetch "forge_labRegionInvariant" n)))
   ["val_inv_def", "step_ok_def", "region_hyp_def", "region_inv_def"];
val closure = "forge_labRegionStep" :: Theory.ancestry "forge_labRegionStep";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "P2_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
