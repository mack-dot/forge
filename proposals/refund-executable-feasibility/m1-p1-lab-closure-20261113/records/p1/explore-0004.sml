load "forge_refundArm8CompileTheory"; load "backend_arm8_cvTheory"; load "labPropsTheory"; load "wordConvsTheory";
open preamble cv_transLib backendTheory backend_asmTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun stamp s = pr ("STAMP " ^ s ^ " " ^ Time.toString (Time.now ()));
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P1_OUT"));
val _ = new_theory "forge_p1Explore";
(* A second name for the published target configuration. The specialised
   functions below are DEFINED as the published functions at this
   configuration, and that defining link is kept (the published library
   backend_asmLib overwrites it). The code follows backend_asmLib.asm_spec. *)
val forge8_config_def = Define `forge8_config = arm8_config`;
val asm_conf = lhs (concl forge8_config_def);
val record_def = TRANS forge8_config_def arm8_targetTheory.arm8_config_def;
val field_lemma = TypeBase.accessors_of (type_of asm_conf)
    |> map (rator o fst o dest_eq o concl o SPEC_ALL)
    |> map (fn tm => mk_icomb(tm,asm_conf))
    |> map (fn tm => SIMP_CONV (srw_ss()) [record_def] tm)
    |> LIST_CONJ;
val mem = ref ([]:thm list);
fun asm_spec th0 = let
    val th1 = th0 |> DefnBase.one_line_ify NONE |> SPEC_ALL
    val (c,args) = th1 |> concl |> dest_eq |> fst |> strip_comb
    val tm = first (fn tm => can (match_term tm) asm_conf) args
    val (i,s) = match_term tm asm_conf
    val th2 = INST i (INST_TYPE s th1)
    val tm1 = th2 |> concl |> dest_eq |> fst
    val (c,args1) = strip_comb tm1
    val args2 = filter is_var args1
    val tm2 = list_mk_abs(args2,tm1)
    val full_name = (c |> dest_const |> fst) ^ "_forge8"
    val v = mk_var(full_name,type_of tm2)
    val d = new_definition(full_name ^ "_link",mk_eq(v,tm2))
              |> SIMP_RULE std_ss [FUN_EQ_THM] |> GSYM
              |> REWRITE_RULE [GSYM FUN_EQ_THM] |> SPEC_ALL
    val _ = (mem := (d::(!mem)))
    val th3 = th2 |> REWRITE_RULE (!mem)
                  |> SIMP_RULE (srw_ss()) [field_lemma,combinTheory.o_DEF]
                  |> REWRITE_RULE (!mem)
                  |> SPEC_ALL
    val _ = List.null (find_terms (aconv asm_conf) (concl th3))
                orelse failwith ("resulting term contains asm_conf reference: " ^ full_name)
    val _ = save_thm(full_name ^ "_def",th3)
    in (d, th3) end;
val (inst_select_exp_link, inst_select_exp_f8) = asm_spec word_instTheory.inst_select_exp_def;
val (inst_select_link, inst_select_f8) = asm_spec word_instTheory.inst_select_def;
val (get_forced_link, get_forced_f8) = asm_spec word_allocTheory.get_forced_def;
val (comp_link, comp_f8) = asm_spec word_to_stackTheory.comp_def;
val (compile_prog_link, compile_prog_f8) = asm_spec word_to_stackTheory.compile_prog_def;
val (cwts_link, cwts_f8) = asm_spec word_to_stackTheory.compile_word_to_stack_def;
val (word_alloc_link, word_alloc_f8) = asm_spec word_alloc_inlogic_def;
val (each_link, each_f8) = asm_spec each_inlogic_def;
val (w2w_link, w2w_f8) = asm_spec word_to_word_inlogic_def;
val links = !mem;
val _ = List.app (fn th => pr ("LINK " ^ thm_to_string th)) links;
fun word_tyvars ty =
  case total dest_thy_type ty of
    NONE => []
  | SOME {Thy="fcp",Tyop="cart",Args=[_,v]} => if is_vartype v then [v] else word_tyvars v
  | SOME {Args,...} => List.concat (map word_tyvars Args);
fun arch_spec th =
  find_terms (K true) (concl th) |> List.concat o map (word_tyvars o type_of) |> mk_set
  |> map (fn v => v |-> ``:64``) |> (fn s => INST_TYPE s th);
(* cv translations of the re-specialised functions; tactics as in the published backend_arm8_cvScript. *)
val pre = cv_auto_trans_pre "" (comp_f8 |> arch_spec);
val comp_pre = store_thm ("comp_forge8_pre[cv_pre]", ``!perf v bs kf. comp_forge8_pre perf v bs kf``,
  gen_tac \\ gen_tac \\ completeInduct_on `prog_size v`
  \\ rw [] \\ gvs [PULL_FORALL] \\ rw [] \\ simp [Once pre] \\ rw [] \\ gvs [] \\ last_x_assum irule \\ gvs []);
val _ = cv_auto_trans (compile_prog_f8 |> arch_spec);
val pre = cv_auto_trans_pre "" (cwts_f8 |> arch_spec);
val cwts_pre = store_thm ("compile_word_to_stack_forge8_pre[cv_pre]",
  ``!perf k v bitmaps. compile_word_to_stack_forge8_pre perf k v bitmaps``, Induct_on `v` \\ rw [] \\ simp [Once pre]);
val pre = cv_trans_pre "" (get_forced_f8 |> arch_spec);
val get_forced_pre = store_thm ("get_forced_forge8_pre[cv_pre]", ``!v acc. get_forced_forge8_pre v acc``,
  gen_tac \\ completeInduct_on `prog_size v` \\ rw [] \\ gvs [PULL_FORALL] \\ simp [Once pre] \\ rw [] \\ gvs [] \\ last_x_assum $ irule \\ gvs []);
val _ = cv_trans (word_alloc_f8 |> arch_spec);
val pre = cv_trans_pre "" (inst_select_exp_f8 |> arch_spec);
val inst_select_exp_pre = store_thm ("inst_select_exp_forge8_pre[cv_pre]",
  ``!bits v tar temp. inst_select_exp_forge8_pre bits tar temp v``,
  gen_tac \\ gen_tac \\ completeInduct_on `exp_size v` \\ rw [] \\ gvs [PULL_FORALL] \\ rw [] \\ simp [Once pre] \\ rw [] \\ gvs []
  \\ last_x_assum irule \\ gvs []);
val pre = cv_trans_pre "" (inst_select_f8 |> arch_spec);
val inst_select_pre = store_thm ("inst_select_forge8_pre[cv_pre]", ``!bits v temp. inst_select_forge8_pre bits temp v``,
  gen_tac \\ gen_tac \\ completeInduct_on `prog_size v` \\ rw [] \\ gvs [PULL_FORALL] \\ simp [Once pre] \\ rw []
  \\ first_x_assum irule \\ gvs []);
val pre = (each_f8 |> arch_spec) |> cv_trans_pre "";
val each_pre = store_thm ("each_inlogic_forge8_pre[cv_pre]", ``!v. each_inlogic_forge8_pre v``, Induct \\ rw [] \\ simp [Once pre]);
val _ = cv_trans (w2w_f8 |> arch_spec);
(* The lab program of the published pipeline, computed with the in-logic word_to_word check. *)
val lab_forge8_def = Define `lab_forge8 c p =
  let (c0,p0) = to_word_0_arm8 c p in
  case word_to_word_inlogic_forge8 c0.word_to_word_conf p0 of
    NONE => NONE
  | SOME (col,wp) =>
     let perf = c0.stack_conf.perf_calls in
     let (progs,fs,bitmaps) = compile_word_to_stack_forge8 perf 24 wp (if perf then (List [16],1) else (List [4],1)) in
     let sp = (raise_stub_location,raise_stub perf 24,Metadata (strlit "_Raise") [Stub])::
              (store_consts_stub_location,store_consts_stub 24,Metadata (strlit "_StoreConsts") [Stub])::progs in
       SOME (stack_to_lab$compile (arch_wordsize ARMv8) c0.stack_conf c0.data_conf
               (2 * max_heap_limit 64 c0.data_conf - 1) 26 (-4351,4350) sp)`;
val arm8_link = prove (``to_word_0_arm8 c p = to_word_0 arm8_config c p``,
  simp[backend_arm8Theory.to_word_0_arm8_def, to_word_0_def, backend_arm8Theory.compile_0_arm8_def,
       data_to_wordTheory.compile_0_def, arm8_targetTheory.arm8_config_def]);
(* The published lemma word_to_word_inlogic_thm is local to backend_asmScript; same statement and tactic. *)
val w2w_inlogic_thm = prove (``word_to_word_inlogic asm_conf c.word_to_word_conf p = SOME (col,prog) ==>
  word_to_word$compile c.word_to_word_conf asm_conf p = (col,prog)``,
  gvs [word_to_word_inlogic_def,word_to_wordTheory.compile_def]
  \\ pairarg_tac \\ gvs [AllCaseEqs()] \\ rw []
  \\ last_x_assum kall_tac
  \\ pop_assum mp_tac
  \\ qspec_tac (`ZIP (p,n_oracles)`,`xs`)
  \\ qid_spec_tac `prog`
  \\ Induct_on `xs`
  \\ gvs [each_inlogic_def]
  \\ PairCases
  \\ gvs [each_inlogic_def,AllCaseEqs(),word_alloc_inlogic_def]
  \\ rpt strip_tac \\ gvs []
  \\ gvs [word_to_wordTheory.full_compile_single_def]
  \\ gvs [word_to_wordTheory.compile_single_def]
  \\ rw [] \\ gvs [word_allocTheory.word_alloc_def]);
val lab_link_goal = ``lab_forge8 c p = SOME L ==> SND (SND (to_lab arm8_config c p)) = L``;
(* Exploration only *)
open proofManagerLib;
fun goals_now () = (top_goals ()) handle _ => [];
fun proved () = ((top_thm (); true) handle _ => false);
fun goal_string (asl, w) = String.concatWith "\n" (map (fn a => "  ASM " ^ term_to_string a) asl) ^ "\n  GOAL " ^ term_to_string w;
fun show label = (pr ("AFTER " ^ label ^ ": " ^ Int.toString (length (goals_now ())) ^ " goals, proved=" ^ Bool.toString (proved ()));
                  List.app (fn gl => pr (goal_string gl ^ "\n----")) (goals_now ()));
fun step label tac = ((e tac; show label) handle ex => (pr ("STEP_FAILED " ^ label ^ " " ^ exn_to_string ex); show ("failure of " ^ label)));
val _ = pr "W2W_INLOGIC_PROVED";
val _ = (cv_auto_trans (lab_forge8_def |> SRULE [data_to_wordTheory.max_heap_limit_def, backend_commonTheory.word_shift_def]); pr "LAB_F8_TRANSLATED")
        handle ex => pr ("STEP_FAILED translate lab_forge8 :: " ^ exn_to_string ex);
val _ = g `^lab_link_goal`;
val _ = step "l1" (simp[lab_forge8_def, arm8_link] >> pairarg_tac >> simp[AllCaseEqs()] >> strip_tac >> pairarg_tac >> gvs[]);
val _ = step "l2" (fs[GSYM w2w_link, GSYM cwts_link, forge8_config_def]);
val _ = step "l3" (`c0.word_to_word_conf = c0.word_to_word_conf` by simp[] >> drule w2w_inlogic_thm >> strip_tac);
val _ = step "l4" (simp[to_lab_def, to_stack_def, to_word_thm, word_to_stackTheory.compile_def] >> rpt (pairarg_tac >> gvs[]));
val _ = step "l5" (gvs[arm8_targetTheory.arm8_config_def] >> EVAL_TAC);
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
