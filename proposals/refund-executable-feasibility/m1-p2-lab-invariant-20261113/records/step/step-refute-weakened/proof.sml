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
(* Control by counterexample: without the static hypothesis the claim is false.
   Two sections; a jump from program counter 0 to section 1; OK holds only of 0. *)
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P2_OUT"));
val _ = new_theory "forge_labRegionStepControl";
val th = DB.fetch "forge_labRegionStep" "region_prefix";
val _ = if aconv prefix_expected (concl th) then () else raise Fail "Harness: original statement does not match";
val _ = pr "AFTER_POSITIVE_AUDIT";
val s0 = ``(ARB:(64,'c,'ffi) labSem$state) with <| pc := 0; clock := 1;
   code := [Section 0 [LabAsm (Jump (Lab 1 0)) 0 [] 0] ARB; Section 1 [LabAsm Halt 0 [] 0] ARB] |>``;
val final_pc = prove (``(SND (labSem$evaluate ^s0)).pc = 1``,
  simp[Once evaluate_def, asm_fetch_def, asm_fetch_aux_def, get_pc_value_def, loc_to_pc_def, upd_pc_def, dec_clock_def] >>
  simp[Once evaluate_def]);
val _ = pr ("COUNTEREXAMPLE_TO_WEAKENED_CLAIM " ^ thm_to_string final_pc);
val refuted = prove (``~(!s k res t. s.code = (^s0).code /\ val_inv (\v. T) s /\ (\p. p = 0) s.pc /\
      labSem$evaluate (s with clock := k) = (res,t) ==> (\p. p = 0) t.pc)``,
  simp[] >> qexistsl_tac [`^s0`, `1`] >> simp[val_inv_def] >>
  qexistsl_tac [`FST (labSem$evaluate ^s0)`, `SND (labSem$evaluate ^s0)`] >> simp[final_pc] >>
  `(^s0) with clock := 1 = ^s0` by simp[theorem "state_component_equality"] >> simp[final_pc]);
val _ = raise Fail ("Weakened claim refuted by a concrete run: " ^ thm_to_string final_pc);
