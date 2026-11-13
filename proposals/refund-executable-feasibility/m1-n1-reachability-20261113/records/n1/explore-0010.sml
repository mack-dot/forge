load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "wordConvsTheory";
load "wordConvsProofTheory"; load "backendProofTheory";
open preamble cv_transLib backendTheory word_to_wordTheory data_to_wordTheory wordConvsTheory wordConvsProofTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun stamp s = pr ("STAMP " ^ s ^ " " ^ Time.toString (Time.now ()));
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
(* Exploration only. Goal manager; nothing exported. *)
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_N1_OUT"));
val _ = new_theory "forge_n1Explore";
open proofManagerLib;
fun goals_now () = (top_goals ()) handle _ => [];
fun proved () = ((top_thm (); true) handle _ => false);
fun goal_string (asl, w) = String.concatWith "\n" (map (fn a => "  ASM " ^ term_to_string a) asl) ^ "\n  GOAL " ^ term_to_string w;
fun show label = (pr ("AFTER " ^ label ^ ": " ^ Int.toString (length (goals_now ())) ^ " goals, proved=" ^ Bool.toString (proved ()));
                  List.app (fn gl => pr (goal_string gl ^ "\n----")) (goals_now ()));
fun step label tac = ((e tac; show label) handle ex => (pr ("STEP_FAILED " ^ label ^ " " ^ exn_to_string ex); show ("failure of " ^ label)));
fun attempt label f = (f (); pr ("STEP_OK " ^ label)) handle ex => pr ("STEP_FAILED " ^ label ^ " :: " ^ exn_to_string ex);
val _ = List.app (fn (n, th) => if String.isSubstring "compile_0_arm8" n then pr ("ARM8_THM " ^ n ^ " :: " ^ thm_to_string th) else ())
          (DB.theorems "backend_arm8" @ DB.definitions "backend_arm8");
val arm8_link = prove (``to_word_0_arm8 c p = to_word_0 arm8_config c p``,
  simp[backend_arm8Theory.to_word_0_arm8_def, to_word_0_def, backend_arm8Theory.compile_0_arm8_def, compile_0_def, arm8_targetTheory.arm8_config_def]);
val oracle_indep = prove (``SND (to_word_0 ac (set_oracle c orac) p) = SND (to_word_0 ac c p)``,
  simp[to_word_0_def, to_data_def, to_bvi_def, to_bvl_def, to_clos_def, to_flat_def, set_oracle_def] >> rpt (pairarg_tac >> gvs[]));
val singleton = prove (``!wc ac f orac. SND (word_to_word$compile (wc with col_oracle := [orac]) ac [f]) =
     [full_compile_single (isa_bits ac) ac.two_reg_arith (ac.reg_count - (5 + LENGTH ac.avoid_regs)) wc.reg_alg ac (f, orac)]``,
  simp[word_to_wordTheory.compile_def, next_n_oracle_def]);
val fst_single = prove (``!bits tra rc alg ac n m pp md orac. FST (full_compile_single bits tra rc alg ac ((n,m,pp,md),orac)) = n``,
  simp[full_compile_single_def, compile_single_def] >> rpt gen_tac >> rpt (pairarg_tac >> gvs[]));
(* D: one function: labels after word_to_word are within the name and the labels before *)
val _ = g `!wc ac n m pp md orac. good_handlers n pp ==>
   ?m2 pp2 md2. full_compile_single (isa_bits ac) ac.two_reg_arith (ac.reg_count - (5 + LENGTH ac.avoid_regs)) wc.reg_alg ac ((n,m,pp,md), orac) = (n,m2,pp2,md2) /\
                get_code_labels pp2 SUBSET n INSERT get_code_labels pp`;
val _ = step "single-start" (rpt strip_tac >>
   qspecl_then [`wc`,`ac`,`(n,m,pp,md)`,`orac`] assume_tac singleton >>
   qspecl_then [`isa_bits ac`,`ac.two_reg_arith`,`ac.reg_count - (5 + LENGTH ac.avoid_regs)`,`wc.reg_alg`,`ac`,`n`,`m`,`pp`,`md`,`orac`] assume_tac fst_single >>
   mp_tac (Q.INST [`progs` |-> `[(n,m,pp,md)]`, `elabs` |-> `get_code_labels pp`, `wc` |-> `wc with col_oracle := [orac]`, `ac` |-> `ac`]
             word_good_code_labels_word_to_word));
val _ = step "single-cases" (qmatch_asmsub_abbrev_tac `FST out = n` >> PairCases_on `out` >>
   fs[markerTheory.Abbrev_def] >> pop_assum (assume_tac o SYM) >> fs[]);
val _ = step "single-labels" (fs[good_code_labels_def]);
val _ = step "single-close" (gvs[SUBSET_DEF] >> metis_tac[]);
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
