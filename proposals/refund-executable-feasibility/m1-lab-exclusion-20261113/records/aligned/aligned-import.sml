(* Fresh import; expected statements are written out. *)
load "labSemTheory"; load "labPropsTheory"; load "blastLib";
open preamble labSemTheory labLangTheory forge_labRegionInvariantTheory forge_labRegionAlignedTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val prefix_expected = ``!s k res t. region_inv2 G D OK code s /\ labSem$evaluate (s with clock := k) = (res,t) ==>
   region_inv2 G D OK code t /\ OK t.pc /\ t.code = code /\ (!i bs n. labSem$asm_fetch t <> SOME (LabAsm Install i bs n))``;
val expected = [
 ("region2_prefix", prefix_expected),
 ("region2_one_step", ``!s res t. region_inv2 G D OK code s /\ labSem$evaluate s = (res,t) ==>
   (?s2. labSem$evaluate s2 = (res,t) /\ region_inv2 G D OK code s2 /\ s2.clock < s.clock) \/ t = s``),
 ("asm_inst_mval_inv", ``!i s. (!w. G (Word w)) /\ load_covered D /\ mval_inv G D s /\ ~(labSem$asm_inst i s).failed ==> mval_inv G D (labSem$asm_inst i s)``),
 ("load_covered_byte_align_64", ``load_covered (\x:word64. ?a. x = byte_align a)``),
 ("all_address_premise_not_implied", ``!G (v0:64 word_loc). ~G v0 ==>
   ?m:word64 -> 64 word_loc. (!a. ?w. m (byte_align a) = Word w) /\ ~(!a. G (m a))``)];
val _ = List.app (fn (n, tm) =>
  let val th = DB.fetch "forge_labRegionAligned" n in
    if aconv tm (concl th) then () else raise Fail ("Exact statement mismatch: " ^ n);
    tags n th; pr ("IMPORTED " ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val names = map fst (DB.theorems "forge_labRegionAligned");
val _ = List.app (fn n => tags n (DB.fetch "forge_labRegionAligned" n)) names;
val _ = if length (List.filter (String.isPrefix "region2_step_") names) = 11 then () else raise Fail "Expected eleven branch lemmas";
val _ = List.app (fn n => pr ("DEFINITION " ^ n ^ "\n" ^ thm_to_string (DB.fetch "forge_labRegionAligned" n)))
   ["mval_inv_def", "load_covered_def", "region_inv2_def"];
val closure = "forge_labRegionAligned" :: Theory.ancestry "forge_labRegionAligned";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "P2_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
