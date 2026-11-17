load "labSemTheory"; load "labPropsTheory";
open preamble labSemTheory labLangTheory forge_labRegionInvariantTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P2_OUT"));
val _ = new_theory "forge_p2Explore";
val inv_def = region_inv_def;
val upd_defs = [inc_pc_def, dec_clock_def, upd_pc_def, upd_reg_def, asm_inst_consts];
(* Facts carried by the invariant, stated on s.code. *)
val inv_facts_goal = ``region_inv G OK code s ==>
   s.code = code /\ (!w. G (Word w)) /\ val_inv G s /\ OK s.pc /\
   (!n1 n2 p. G (Loc n1 n2) /\ loc_to_pc n1 n2 s.code = SOME p ==> OK p) /\
   (!line. asm_fetch s = SOME line ==> step_ok G OK s.code s.pc line)``;
val inv_facts_tac = rw[inv_def, region_hyp_def, asm_fetch_def] >> metis_tac[];
(* Re-establishing the invariant for a successor state. *)
val inv_next_goal = ``!s s2. region_inv G OK code s /\ s2.code = s.code /\ val_inv G s2 /\ OK s2.pc ==> region_inv G OK code s2``;
val inv_next_tac = rw[inv_def];
fun branch_goal line = ``!s res t. region_inv G OK code s /\ s.clock <> 0 /\ asm_fetch s = SOME ^line /\ evaluate s = (res,t) ==>
   (?s2. evaluate s2 = (res,t) /\ region_inv G OK code s2 /\ s2.clock < s.clock) \/ t = s``;
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
val inv_facts = prove (inv_facts_goal, inv_facts_tac);
val inv_next = prove (inv_next_goal, inv_next_tac);
val _ = pr "HELPERS_PROVED";
val ffi_goal = branch_goal ``LabAsm (CallFFI name) i bs n``;
val unfold_tac = rpt strip_tac >> drule inv_facts >> strip_tac >> qpat_x_assum `evaluate _ = _` mp_tac >> simp[Once evaluate_def];
val _ = run "callffi" ffi_goal
  [("unfold", unfold_tac),
   ("split", rpt (TOP_CASE_TAC >> gvs[])),
   ("d1", strip_tac >> disj1_tac),
   ("d2", first_assum (irule_at (Pos hd))),
   ("d3", simp[]),
   ("d4", irule inv_next),
   ("d5", qexists_tac `s` >> simp[]),
   ("leaf-val", conj_tac >- (fs[val_inv_def] >> rw[]
        >- (rename1 `get_reg_value v` >> Cases_on `v` >> fs[targetSemTheory.get_reg_value_def])
        >- (irule write_bytearray_val_inv >> fs[]))),
   ("leaf-pc", first_x_assum irule >> fs[val_inv_def] >> metis_tac[])];
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
