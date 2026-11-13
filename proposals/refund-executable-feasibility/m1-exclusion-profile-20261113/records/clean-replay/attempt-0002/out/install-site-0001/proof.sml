(* U298: the one direct branch of the exact native code into the installer
   entry, checked against the published L3 ARMv8 model.  Word 17fffb6b at code
   offset 4660 (file offset 21252); installer entry = code start - 32. *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_NATIVE_STEP_OUT"));
val _ = new_theory "forge_refundInstallSite";
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val steps = arm8_stepLib.arm8_step_hex "17fffb6b";
val _ = if length steps = 1 then () else raise Fail "Expected one step theorem";
val step = hd steps;
val _ = pr ("STEP_THEOREM " ^ thm_to_string step);
val s = ``s:arm8_state``;
val premises = list_mk_conj (hyp step);
val _ = List.app (fn h => pr ("PREMISE " ^ term_to_string h)) (hyp step);
val goal = mk_forall (s, mk_imp (premises, ``?s1. NextStateARM8 ^s = SOME s1 /\ s1.PC = (^s).PC - 4692w /\
                                              s1.MEM = (^s).MEM /\ s1.REG = (^s).REG /\ s1.SP_EL0 = (^s).SP_EL0``));
val install_call_site_step = store_thm ("install_call_site_step", goal,
  rpt strip_tac >>
  mp_tac (DISCH_ALL step |> REWRITE_RULE [AND_IMP_INTRO]) >>
  impl_tac >- asm_rewrite_tac [] >>
  strip_tac >> simp [] >> FIRST [NO_TAC, blastLib.BBLAST_TAC, EVAL_TAC]);
val _ = tags "install_call_site_step" install_call_site_step;
val _ = pr ("CHECKED install_call_site_step\n" ^ thm_to_string install_call_site_step);
val _ = export_theory ();
val _ = pr "NATIVE_STEP_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
