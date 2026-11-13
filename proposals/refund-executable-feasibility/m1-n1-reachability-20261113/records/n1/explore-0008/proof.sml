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
(* A: specialised function equals the published one at arm8_config *)
val _ = g `to_word_0_arm8 c p = to_word_0 arm8_config c p`;
val _ = step "arm8-link" (simp[backend_arm8Theory.to_word_0_arm8_def, to_word_0_def, backend_arm8Theory.compile_0_arm8_def, compile_0_def, arm8_targetTheory.arm8_config_def]);
(* B: oracle independence of the pre-allocation program *)
val _ = g `SND (to_word_0 ac (set_oracle c orac) p) = SND (to_word_0 ac c p)`;
val _ = step "oracle-indep" (simp[to_word_0_def, to_data_def, to_bvi_def, to_bvl_def, to_clos_def, to_flat_def, set_oracle_def] >>
                             rpt (pairarg_tac >> gvs[]));
(* C: singleton compile *)
val _ = g `!wc ac f orac. SND (word_to_word$compile (wc with col_oracle := [orac]) ac [f]) =
     [full_compile_single (isa_bits ac) ac.two_reg_arith (ac.reg_count - (5 + LENGTH ac.avoid_regs)) wc.reg_alg ac (f, orac)]`;
val _ = step "singleton" (simp[word_to_wordTheory.compile_def, next_n_oracle_def]);
val _ = g `!bits tra rc alg ac n m pp md orac. FST (full_compile_single bits tra rc alg ac ((n,m,pp,md),orac)) = n`;
val _ = step "fst" (simp[full_compile_single_def, compile_single_def] >> rpt gen_tac >> rpt (pairarg_tac >> gvs[]));
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
