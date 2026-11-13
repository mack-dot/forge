(* Exploration only: an ideal install handler for the ARM8 machine model.
   Goal manager; stores no theorem and exports no theory. *)
load "arm8_configProofTheory"; load "targetPropsTheory";
open preamble targetSemTheory targetPropsTheory asmPropsTheory arm8_targetTheory arm8_configProofTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
open proofManagerLib;
fun goals_now () = (top_goals ()) handle _ => [];
fun goal_string (asl, w) = String.concatWith "\n" (map (fn a => "  ASM " ^ term_to_string a) asl) ^ "\n  GOAL " ^ term_to_string w;
fun show label = (pr ("AFTER " ^ label); pr (Int.toString (length (goals_now ())) ^ " goals");
                  List.app (fn gl => pr (goal_string gl ^ "\n----")) (goals_now ()));
val handler = ``\(k:num) (x:word8 list # arm8_state).
   (SND x) with <| PC := (SND x).REG 30w;
                   MEM := asm_write_bytearray ((SND x).REG 2w) (FST x) (SND x).MEM;
                   REG := (0w =+ (SND x).REG 2w) (SND x).REG |>``;
val goal = ``!mc pc cbspace. is_arm8_machine_config mc ==>
               install_interfer_ok pc cbspace (mc with install_interfer := ^handler)``;
val _ = pr ("GOAL " ^ term_to_string goal);
val _ = pr ("GOAL_TYPE_OF_MC " ^ type_to_string (type_of (fst (dest_forall goal))));
val _ = g `^goal`;
fun step label tac = (e tac; show label) handle ex => (pr ("STEP_FAILED " ^ label ^ " " ^ General.exnMessage ex); show ("state at failure of " ^ label));
val _ = step "unfold" (rpt gen_tac >> strip_tac >>
   fs[is_arm8_machine_config_def, install_interfer_ok_def] >> rpt gen_tac >> strip_tac >>
   fs[target_state_rel_def, arm8_target_def, arm8_config_def, arm8_ok_def, read_ffi_bytearray_def]);
val _ = step "regs" (
   first_assum (qspec_then `30` mp_tac) >> first_assum (qspec_then `2` mp_tac) >>
   simp[] >> rpt strip_tac >> gvs[]);
val _ = step "split" (rpt conj_tac);
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
