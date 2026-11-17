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
(* Lab-level static checks. *)
val asm_no_label_def = Define `
  asm_no_label (ls:num list) a =
    case a of
      labLang$Jump (Lab n1 _) => ~MEM n1 ls
    | JumpCmp _ _ _ (Lab n1 _) => ~MEM n1 ls
    | Call (Lab n1 _) => ~MEM n1 ls
    | LocValue _ (Lab n1 _) => ~MEM n1 ls
    | _ => T`;
val line_no_label_def = Define `
  line_no_label ls l = case l of LabAsm a _ _ _ => asm_no_label ls a | _ => T`;
val line_is_exit_def = Define `
  line_is_exit l = case l of
      LabAsm (Jump _) _ _ _ => T
    | LabAsm Halt _ _ _ => T
    | Asm (Asmi (JumpReg _)) _ _ => T
    | _ => F`;
val is_label_def = Define `is_label l = case l of Label _ _ _ => T | _ => F`;
val sec_ends_exit_def = Define `
  sec_ends_exit sec = case REVERSE (FILTER (\l. ~is_label l) (Section_lines sec)) of [] => F | l::_ => line_is_exit l`;
val no_fall_def = Define `
  (no_fall (ls:num list) [] = T) /\
  (no_fall ls [s] = T) /\
  (no_fall ls (s1::s2::rest) =
     ((MEM (Section_num s2) ls /\ ~MEM (Section_num s1) ls ==> sec_ends_exit s1) /\ no_fall ls (s2::rest)))`;
val lab_closed_def = Define `
  lab_closed ls secs <=>
    EVERY (\sec. MEM (Section_num sec) ls \/ EVERY (line_no_label ls) (Section_lines sec)) secs /\
    (case secs of [] => T | s::_ => ~MEM (Section_num s) ls) /\
    no_fall ls secs`;
val line_is_install_def = Define `line_is_install l = case l of LabAsm Install _ _ _ => T | _ => F`;
val line_is_jumpreg_def = Define `line_is_jumpreg l = case l of Asm (Asmi (JumpReg _)) _ _ => T | _ => F`;
val line_is_locvalue_def = Define `line_is_locvalue l = case l of LabAsm (LocValue _ _) _ _ _ => T | _ => F`;
val lab_stats_def = Define `
  lab_stats secs =
    (LENGTH secs,
     MAP Section_num (FILTER (\sec. EXISTS line_is_install (Section_lines sec)) secs),
     SUM (MAP (\sec. LENGTH (FILTER line_is_jumpreg (Section_lines sec))) secs),
     SUM (MAP (\sec. LENGTH (FILTER line_is_locvalue (Section_lines sec))) secs),
     MAP Section_num (FILTER (\sec. ~EVERY (line_no_label [29;31]) (Section_lines sec)) secs))`;
val lab_names_def = Define `lab_names secs = MAP Section_num secs`;
val lab_check_def = Define `lab_check ls c p = case lab_forge8 c p of NONE => F | SOME L => lab_closed ls L`;
val lab_info_def = Define `lab_info c p = case lab_forge8 c p of NONE => NONE | SOME L => SOME (lab_stats L, TAKE 40 (lab_names L))`;
(* Exploration only *)
load "reg_allocComputeLib";
fun attempt label f = (f (); pr ("STEP_OK " ^ label)) handle ex => pr ("STEP_FAILED " ^ label ^ " :: " ^ exn_to_string ex);
val _ = cv_auto_trans (lab_forge8_def |> SRULE [data_to_wordTheory.max_heap_limit_def, backend_commonTheory.word_shift_def]);
val _ = attempt "translate checks" (fn () => List.app (fn d => (cv_auto_trans d; ()))
   [asm_no_label_def, line_no_label_def, line_is_exit_def, is_label_def, sec_ends_exit_def, no_fall_def, lab_closed_def,
    line_is_install_def, line_is_jumpreg_def, line_is_locvalue_def, lab_stats_def, lab_names_def, lab_check_def, lab_info_def]);
val _ = pr ("COMPILED_SPEC " ^ thm_to_string (DB.fetch "forge_refundArm8Compile" "compiled"));
val prog_def = DB.fetch "forge_refundWholeProg" "refund_prog_def";
val _ = Feedback.trace ("Theory.allow_rebinds", 1) (cv_trans_deep_embedding EVAL) prog_def;
val c = EVAL ``arm8_config$arm8_backend_config``;
val conf_tm = rhs (concl c);
val _ = stamp "before livesets";
val graphs_raw = cv_eval_raw ``FST (to_livesets_arm8 ^conf_tm refund_prog)`` |> concl |> rhs;
val _ = stamp "after livesets";
val oracles = reg_allocComputeLib.get_oracle_raw reg_alloc.Irc graphs_raw;
val _ = stamp "after allocation";
val oracle_def = new_definition ("refund_alloc_oracle_def", mk_eq (mk_var ("refund_alloc_oracle", type_of oracles), oracles));
val _ = Feedback.trace ("Theory.allow_rebinds", 1) (cv_trans_deep_embedding EVAL) oracle_def;
val oracle_tm = lhs (concl oracle_def);
val _ = pr ("ORACLE_LENGTH " ^ term_to_string (rhs (concl (cv_eval ``LENGTH ^oracle_tm``))));
val c_oracle_tm = ``set_oracle ^conf_tm ^oracle_tm``;
val _ = stamp "before compile";
val th1 = cv_eval_raw ``compile_cake_arm8 ^c_oracle_tm refund_prog``;
val _ = stamp "after compile";
val to_option_some = cv_typeTheory.to_option_def |> cj 2;
val to_pair = cv_typeTheory.to_pair_def |> cj 1;
val c2n_Num = cvTheory.c2n_def |> cj 1;
val th3 = th1 |> CONV_RULE (PATH_CONV "lr" (REWRITE_CONV [GSYM c]))
              |> CONV_RULE (PATH_CONV "r" (REWR_CONV to_option_some))
              |> CONV_RULE (PATH_CONV "rr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrrrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrrrrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrrrrrr" (REWR_CONV to_pair)
                        THENC PATH_CONV "rrrlr" (REWR_CONV c2n_Num)
                        THENC PATH_CONV "rrrrrlr" (REWR_CONV c2n_Num)
                        THENC PATH_CONV "rrrrrrrlr" (REWR_CONV c2n_Num));
fun fold name path def th = (CONV_RULE (PATH_CONV path (REWR_CONV (SYM def))) th before pr ("SAME_AS_STORED " ^ name))
   handle ex => (pr ("DIFFERS_FROM_STORED " ^ name); th);
val th4 = th3 |> fold "code" "rrlr" forge_refundArm8CompileTheory.code_def
              |> fold "data" "rrrrlr" forge_refundArm8CompileTheory.data_def
              |> fold "ffis" "rrrrrrlr" forge_refundArm8CompileTheory.ffis_def
              |> fold "conf" "rrrrrrrrr" forge_refundArm8CompileTheory.conf_def;
val compiled_new = MATCH_MP backend_arm8Theory.compile_cake_arm8_thm th4 |> REWRITE_RULE [LENGTH_NIL];
val s = thm_to_string compiled_new;
val _ = pr ("COMPILED_NEW " ^ String.substring (s, 0, Int.min (900, size s)));
val _ = stamp "before lab evaluation";
val _ = attempt "lab info" (fn () => pr ("LAB_INFO " ^ term_to_string (rhs (concl (cv_eval ``lab_info ^c_oracle_tm refund_prog``)))));
val _ = attempt "lab check pair" (fn () => pr ("LAB_CLOSED_29_31 " ^ term_to_string (rhs (concl (cv_eval ``lab_check [29;31] ^c_oracle_tm refund_prog``)))));
val _ = attempt "lab check single" (fn () => pr ("LAB_CLOSED_29 " ^ term_to_string (rhs (concl (cv_eval ``lab_check [29] ^c_oracle_tm refund_prog``)))));
val _ = stamp "after lab evaluation";
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
