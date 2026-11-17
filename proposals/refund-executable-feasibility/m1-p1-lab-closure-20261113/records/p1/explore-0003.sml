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
(* Exploration only: can the re-specialised functions be cv-translated as in the published script? *)
fun attempt label f = (f (); pr ("STEP_OK " ^ label)) handle ex => pr ("STEP_FAILED " ^ label ^ " :: " ^ exn_to_string ex);
val _ = pr ("W2W_F8 " ^ thm_to_string w2w_f8);
val _ = pr ("CWTS_F8 " ^ thm_to_string cwts_f8);
val _ = stamp "before translations";
val pre = cv_auto_trans_pre "" (comp_f8 |> arch_spec);
val _ = pr ("PRE_COMP " ^ thm_to_string pre);
val _ = attempt "comp pre" (fn () => (store_thm ("comp_forge8_pre[cv_pre]", ``!perf v bs kf. comp_forge8_pre perf v bs kf``,
  gen_tac \\ gen_tac \\ completeInduct_on `prog_size v`
  \\ rw [] \\ gvs [PULL_FORALL] \\ rw [] \\ simp [Once pre] \\ rw [] \\ gvs [] \\ last_x_assum irule \\ gvs []); ()));
val _ = attempt "compile_prog" (fn () => (cv_auto_trans (compile_prog_f8 |> arch_spec); ()));
val pre = cv_auto_trans_pre "" (cwts_f8 |> arch_spec);
val _ = attempt "cwts pre" (fn () => (store_thm ("compile_word_to_stack_forge8_pre[cv_pre]",
  ``!perf k v bitmaps. compile_word_to_stack_forge8_pre perf k v bitmaps``, Induct_on `v` \\ rw [] \\ simp [Once pre]); ()));
val pre = cv_trans_pre "" (get_forced_f8 |> arch_spec);
val _ = attempt "get_forced pre" (fn () => (store_thm ("get_forced_forge8_pre[cv_pre]", ``!v acc. get_forced_forge8_pre v acc``,
  gen_tac \\ completeInduct_on `prog_size v` \\ rw [] \\ gvs [PULL_FORALL] \\ simp [Once pre] \\ rw [] \\ gvs [] \\ last_x_assum $ irule \\ gvs []); ()));
val _ = attempt "word_alloc" (fn () => (cv_trans (word_alloc_f8 |> arch_spec); ()));
val pre = cv_trans_pre "" (inst_select_exp_f8 |> arch_spec);
val _ = attempt "inst_select_exp pre" (fn () => (store_thm ("inst_select_exp_forge8_pre[cv_pre]",
  ``!bits v tar temp. inst_select_exp_forge8_pre bits tar temp v``,
  gen_tac \\ gen_tac \\ completeInduct_on `exp_size v` \\ rw [] \\ gvs [PULL_FORALL] \\ rw [] \\ simp [Once pre] \\ rw [] \\ gvs []
  \\ last_x_assum irule \\ gvs []); ()));
val pre = cv_trans_pre "" (inst_select_f8 |> arch_spec);
val _ = attempt "inst_select pre" (fn () => (store_thm ("inst_select_forge8_pre[cv_pre]", ``!bits v temp. inst_select_forge8_pre bits temp v``,
  gen_tac \\ gen_tac \\ completeInduct_on `prog_size v` \\ rw [] \\ gvs [PULL_FORALL] \\ simp [Once pre] \\ rw []
  \\ first_x_assum irule \\ gvs []); ()));
val pre = (each_f8 |> arch_spec) |> cv_trans_pre "";
val _ = attempt "each pre" (fn () => (store_thm ("each_inlogic_forge8_pre[cv_pre]", ``!v. each_inlogic_forge8_pre v``,
  Induct \\ rw [] \\ simp [Once pre]); ()));
val _ = attempt "w2w" (fn () => (cv_trans (w2w_f8 |> arch_spec); ()));
val _ = stamp "after translations";
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
