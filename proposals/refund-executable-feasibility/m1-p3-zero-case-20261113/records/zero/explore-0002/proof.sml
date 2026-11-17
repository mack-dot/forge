load "lab_to_targetProofTheory";
open preamble targetSemTheory targetPropsTheory asmPropsTheory lab_to_targetProofTheory forge_targetInstallPrefixTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_zeroExplore";
(* The installer entry is 2*ffi_offset below the code start. A counter at offset x above the
   code start differs from it when x + 2*ffi_offset does not wrap. *)
val distinct_goal = ``!(p:'a word) x. x + 2 * ffi_offset < dimword (:'a) ==> p + n2w x <> p - n2w (2 * ffi_offset)``;
val distinct_tac = rw[] >> strip_tac >>
  `n2w (x + 2 * ffi_offset) = (0w:'a word)` by
     (simp[GSYM word_add_n2w] >> pop_assum mp_tac >> simp[WORD_EQ_SUB_RADD, WORD_ADD_ASSOC] >>
      metis_tac[WORD_ADD_INV_0_EQ, WORD_ADD_ASSOC, WORD_ADD_COMM]) >>
  gvs[lab_to_targetTheory.ffi_offset_def];
(* Clock-zero case of the strengthened simulation: needs a layout bound that state_rel does not state. *)
val zero_goal = ``state_rel (mc_conf,code2,labs,p) s1 t1 ms1 /\
   pos_val s1.pc 0 code2 + 2 * ffi_offset < dimword (:'a) ==>
   no_install_prefix mc_conf ffi 0 (ms1:'state)``;
fun zero_tac distinct = strip_tac >> simp[no_install_prefix_zero] >>
  fs[state_rel_def, target_state_rel_def] >> metis_tac[distinct];
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
val a = run "distinct" distinct_goal [("all", distinct_tac)];
val _ = if isSome a then () else (run "distinct-staged" distinct_goal [("d1", rw[] >> strip_tac), ("d2", fs[WORD_EQ_SUB_RADD]), ("d3", fs[GSYM WORD_ADD_ASSOC, word_add_n2w]), ("d4", fs[WORD_ADD_INV_0_EQ]), ("d5", gvs[lab_to_targetTheory.ffi_offset_def])]; ());
val _ = if isSome a then (run "zero" zero_goal [("all", zero_tac (valOf a))]; ()) else ();
val _ = pr ("WRAP_EXAMPLE " ^ thm_to_string (EVAL ``(0w:word8) + n2w 224 = 0w - n2w (2 * ffi_offset)``));
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
