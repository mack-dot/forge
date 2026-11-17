load "lab_to_targetProofTheory";
open preamble labSemTheory targetSemTheory targetPropsTheory asmPropsTheory lab_to_targetProofTheory
     forge_targetInstallPrefixTheory forge_simZeroCaseTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_layoutExplore";
(* Static layout bound: the encoded program plus the distance to the installer entry does not wrap. *)
val layout_def = Define `code_layout_ok (:'a) code2 <=> LENGTH (prog_to_bytes code2) + 2 * ffi_offset < dimword (:'a)`;
(* Every target state that is state_rel-related to SOME lab state of this code is off the installer entry. *)
val static_goal = ``state_rel (mc_conf,code2,labs,(p:'a word)) s1 t1 ms1 /\ code_layout_ok (:'a) code2 ==>
   no_install_prefix mc_conf ffi 0 (ms1:'state)``;
val static_tac = strip_tac >> match_mp_tac (GEN_ALL state_rel_no_install_prefix_zero) >>
   qexistsl_tac [`t1`,`s1`,`p`,`labs`,`code2`] >> simp[] >>
   `pos_val s1.pc 0 code2 <= LENGTH (prog_to_bytes code2)` by
      (qpat_x_assum `state_rel _ _ _ _` mp_tac >> simp[state_rel_def] >> rpt strip_tac >>
       drule pos_val_bound >> disch_then (qspecl_then [`s1.pc`,`0`] mp_tac) >> simp[]) >>
   fs[layout_def];
(* The bound that the published installed predicate states implies the layout bound. *)
val installed_goal = ``cbspace + LENGTH (prog_to_bytes code2) + ffi_offset * (i + 3) < dimword (:'a) ==> code_layout_ok (:'a) code2``;
val installed_tac = simp[layout_def, lab_to_targetTheory.ffi_offset_def];
open proofManagerLib;
fun goals_now () = (top_goals ()) handle _ => [];
fun proved () = ((top_thm (); true) handle _ => false);
fun clip s = if size s > 1300 then String.substring (s, 0, 500) ^ "\n  ...\n" ^ String.substring (s, size s - 700, 700) else s;
fun goal_string (asl, w) = String.concatWith "\n" (map (fn a => "  ASM " ^ term_to_string a) asl) ^ "\n  GOAL " ^ term_to_string w;
fun show label = (pr ("AFTER " ^ label ^ ": " ^ Int.toString (length (goals_now ())) ^ " goals, proved=" ^ Bool.toString (proved ()));
                  List.app (fn gl => pr (clip (goal_string gl) ^ "\n----")) (List.take (goals_now (), Int.min (2, length (goals_now ())))));
(* Run stages in order on the top goal; stop at the first failure. Returns the theorem if proved. *)
fun run name goal stages =
  let val _ = (proofManagerLib.g `^goal`; ())
      fun go [] = ()
        | go ((label, tac) :: rest) =
            ((e tac; if proved () then pr ("STAGE_OK " ^ name ^ "/" ^ label ^ " (proved)") else (pr ("STAGE_OK " ^ name ^ "/" ^ label); go rest))
             handle ex => (pr ("STAGE_FAILED " ^ name ^ "/" ^ label ^ " :: " ^ exn_to_string ex); show (name ^ "/" ^ label)))
      val _ = go stages
  in if proved () then (pr ("LEMMA_PROVED " ^ name); SOME (top_thm ()))
     else (pr ("LEMMA_OPEN " ^ name); show (name ^ " end"); NONE) end;
val _ = pr ("ZERO_GEN " ^ thm_to_string (GEN_ALL state_rel_no_install_prefix_zero));
val a = run "static" static_goal [("s1", strip_tac >> match_mp_tac (GEN_ALL state_rel_no_install_prefix_zero)),
   ("s2", qexistsl_tac [`t1`,`s1`,`p`,`labs`,`code2`] >> simp[]),
   ("s3", `pos_val s1.pc 0 code2 <= LENGTH (prog_to_bytes code2)` by
      (qpat_x_assum `state_rel _ _ _ _` mp_tac >> simp[state_rel_def] >> rpt strip_tac >>
       drule pos_val_bound >> disch_then (qspecl_then [`s1.pc`,`0`] mp_tac) >> simp[])),
   ("s4", fs[layout_def])];
val b = run "installed" installed_goal [("all", installed_tac)];
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
