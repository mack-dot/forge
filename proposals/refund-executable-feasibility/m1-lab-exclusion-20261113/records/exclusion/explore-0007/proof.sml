load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "labPropsTheory"; load "wordConvsTheory"; load "labSemTheory";
load "lab_to_targetProofTheory"; load "blastLib";
open preamble backendTheory labSemTheory labLangTheory targetSemTheory
     forge_refundLabClosureTheory forge_refundLabResolveTheory
     forge_labRegionInvariantTheory forge_labRegionStepTheory forge_labRegionWalkTheory forge_refundLabRunTheory
     forge_labRegionAlignedTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_RUN_OUT"));
val _ = new_theory "forge_initExplore";
val L_tm = ``SND (SND (to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val ls_tm = ``[Install_location; InstallData_location]``;
val OK_tm = ``pc_ok ^ls_tm ^L_tm``;
val G_tm = ``(loc_good ^OK_tm ^L_tm) : 64 word_loc -> bool``;
val D_tm = ``\x:word64. ?a. x = byte_align a``;
val init_tm = ``lab_to_targetProof$make_init mc0 ffi0 t0 m dm1 sdm1 ms0 ^L_tm cmp0 cbpos0 cbspace0 coracle0``;
(* Premise: exactly the memory clause that good_init_state states for aligned addresses. *)
val aligned_goal = ``(!a. ?w. m (byte_align a) = Word w) /\ labSem$evaluate (^init_tm with clock := k) = (res,s2) ==>
   ^OK_tm s2.pc /\ s2.code = ^L_tm /\ (!i bs n. labSem$asm_fetch s2 <> SOME (LabAsm Install i bs n))``;
val good_goal =
  let val (ante, conc) = dest_imp aligned_goal val ev = el 2 (strip_conj ante)
      val m_tm = hd (List.filter (fn v => fst (dest_var v) = "m") (free_vars aligned_goal))
      val mc_tm = hd (List.filter (fn v => fst (dest_var v) = "mc0") (free_vars aligned_goal))
      val ms_tm = hd (List.filter (fn v => fst (dest_var v) = "ms0") (free_vars aligned_goal))
      val t_tm = hd (List.filter (fn v => fst (dest_var v) = "t0") (free_vars aligned_goal))
  in mk_imp (mk_conj (``targetSem$good_init_state ^mc_tm ^ms_tm bytes0 cbs0 ^t_tm ^m_tm dm0 sdm0``, ev), conc) end;
val pref2 =
  let val th0 = region2_prefix
      fun fv th n = valOf (List.find (fn v => fst (dest_var v) = n) (free_vars (concl th)))
      val th1 = INST_TYPE (match_type (type_of (fv th0 "G")) (type_of G_tm)) th0
  in INST [fv th1 "G" |-> G_tm, fv th1 "D" |-> D_tm, fv th1 "OK" |-> OK_tm, fv th1 "code" |-> L_tm] th1 end;
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
val _ = pr ("GOOD_GOAL " ^ term_to_string good_goal);
val ev_tm = el 2 (strip_conj (fst (dest_imp aligned_goal)));
fun try label f = (f (); pr ("TRY_OK " ^ label)) handle ex => pr ("TRY_FAILED " ^ label ^ " :: " ^ General.exnMessage ex ^ " :: " ^ exn_to_string ex);
val _ = pr ("PREF2 " ^ String.substring (thm_to_string pref2, 0, 300));
val _ = try "spec_all" (fn () => (SPEC_ALL pref2; ()));
val swapped = pref2 |> SPEC_ALL |> ONCE_REWRITE_RULE [CONJ_COMM] |> REWRITE_RULE [GSYM AND_IMP_INTRO];
val _ = pr ("SWAPPED " ^ String.substring (thm_to_string swapped, 0, 400));
val _ = try "match_mp" (fn () => (MATCH_MP swapped (ASSUME ev_tm); ()));
val _ = try "ispecl" (fn () => (ISPECL [rand (rand (lhs ev_tm))] pref2; ()));
val _ = try "part_match" (fn () => (PART_MATCH (el 2 o strip_conj o fst o dest_imp) pref2 ev_tm; ()));
val a = NONE : thm option;
val _ = if isSome a then (run "good" good_goal [("g1", strip_tac >> irule (valOf a) >> fs[good_init_state_def] >> metis_tac[])]; ()) else ();
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
