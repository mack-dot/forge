(* Strengthened simulation: prefix property for the installer entry, by replay of the published case tactics. *)
load "lab_to_targetProofTheory";
open preamble BasicProvers ffiTheory wordSemTheory labSemTheory labPropsTheory lab_to_targetTheory lab_filterProofTheory
     asmTheory asmSemTheory asmPropsTheory targetSemTheory targetPropsTheory backendPropsTheory lab_to_targetProofTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_simReplay";
(* published line 11 *)
val _ = temp_delsimps ["NORMEQ_CONV"]

(* published line 12 *)
val _ = diminish_srw_ss ["ABBREV"]

(* published line 14 *)
fun say0 pfx s g = (print (pfx ^ ": " ^ s ^ "\n"); ALL_TAC g)

(* published line 47 *)
Overload len_no_lab[local] = ``λxs. LENGTH (FILTER ($~ o is_Label) xs)``

(* published line 91 *)
val _ = temp_remove_rules_for_term"step";

(* published line 102 *)
Theorem enc_with_nop_thm[local]:
  enc_with_nop enc (b:asm) bytes =
      ?n. bytes = enc b ++ FLAT (REPLICATE n (enc (asm$Inst Skip)))
Proof
  fs [enc_with_nop_def,LENGTH_NIL]
  \\ IF_CASES_TAC \\ fs [FLAT_REPLICATE_NIL]
  \\ EQ_TAC \\ rw [] THEN1 metis_tac []
  \\ fs [LENGTH_APPEND,LENGTH_FLAT,map_replicate,SUM_REPLICATE]
  \\ full_simp_tac (std_ss++ARITH_ss) [GSYM LENGTH_NIL,MULT_DIV]
QED

(* published line 354 *)
Theorem lab_lookup_IMP[local]:
  (lab_lookup l1 l2 labs = SOME x) ==>
    (find_pos (Lab l1 l2) labs = x)
Proof
  full_simp_tac(srw_ss())[lab_lookup_def,find_pos_def,lookup_any_def]
  \\ BasicProvers.EVERY_CASE_TAC
QED

(* published line 1160 *)
Theorem prog_to_bytes_lemma[local]:
  !code2 code1 pc i pos.
      code_similar code1 code2 /\
      all_enc_ok (mc_conf:('a,'state,'b) machine_config).target.config
        labs ffi_names pos code2 /\
      (asm_fetch_aux pc code1 = SOME i) ==>
      ?bs j bs2.
        (prog_to_bytes code2 = bs ++ line_bytes j ++ bs2) /\
        (LENGTH bs + pos = pos_val pc pos code2) /\
        (LENGTH bs + pos + LENGTH (line_bytes j) = pos_val (pc+1) pos code2) /\
        line_similar i j /\
        line_ok mc_conf.target.config labs ffi_names (pos_val pc pos code2) j
Proof
  HO_MATCH_MP_TAC asm_code_length_ind \\ REPEAT STRIP_TAC
  THEN1 (Cases_on `code1` \\ full_simp_tac(srw_ss())[code_similar_def,asm_fetch_aux_def])
  THEN1
   (Cases_on `code1` \\ full_simp_tac(srw_ss())[code_similar_def]
    \\ Cases_on `h` \\ full_simp_tac(srw_ss())[code_similar_def]
    \\ Cases_on `l` \\ full_simp_tac(srw_ss())[asm_fetch_aux_def,pos_val_def] \\ srw_tac[][]
    \\ full_simp_tac(srw_ss())[prog_to_bytes_def,all_enc_ok_def] \\ metis_tac [])
  \\ Cases_on `code1` \\ full_simp_tac(srw_ss())[code_similar_def]
  \\ Cases_on `h` \\ full_simp_tac(srw_ss())[code_similar_def]
  \\ Cases_on`l` \\ full_simp_tac(srw_ss())[asm_fetch_aux_def,pos_val_def]
  \\ rpt var_eq_tac
  \\ Q.MATCH_ASSUM_RENAME_TAC `line_similar x1 x2`
  \\ Q.MATCH_ASSUM_RENAME_TAC `LIST_REL line_similar ys1 ys2`
  \\ `is_Label x2 = is_Label x1` by
    (Cases_on `x1` \\ Cases_on `x2` \\ full_simp_tac(srw_ss())[line_similar_def,is_Label_def])
  \\ full_simp_tac(srw_ss())[] \\ Cases_on `is_Label x1` \\ full_simp_tac(srw_ss())[]
  THEN1
   (full_simp_tac(srw_ss())[prog_to_bytes_def,LET_DEF]
    \\ FIRST_X_ASSUM (MP_TAC o Q.SPECL [`(Section k ys1 m)::t`,`pc`,`i`,
       `(pos + LENGTH (line_bytes x2))`])
    \\ full_simp_tac(srw_ss())[all_enc_ok_def,code_similar_def] \\ rpt strip_tac
    \\ full_simp_tac(srw_ss())[prog_to_bytes_def,LET_DEF]
    \\ Cases_on `x2` \\ full_simp_tac(srw_ss())[line_ok_def,is_Label_def] \\ srw_tac[][]
    \\ full_simp_tac(srw_ss())[line_length_def,line_bytes_def]
    \\ full_simp_tac(srw_ss())[AC ADD_COMM ADD_ASSOC])
  \\ Cases_on `pc = 0` \\ full_simp_tac(srw_ss())[] \\ srw_tac[][]
  THEN1
   (full_simp_tac(srw_ss())[listTheory.LENGTH_NIL] \\ qexists_tac `x2`
    \\ full_simp_tac(srw_ss())[prog_to_bytes_def,LET_DEF,all_enc_ok_def] \\ full_simp_tac(srw_ss())[pos_val_0]
    \\ imp_res_tac pos_val_0
    \\ full_simp_tac(srw_ss())[] \\ Cases_on `x2`
    \\ full_simp_tac(srw_ss())[line_ok_def,is_Label_def,line_bytes_def,line_length_def] \\ srw_tac[][])
  \\ full_simp_tac(srw_ss())[prog_to_bytes_def,LET_DEF]
  \\ FIRST_X_ASSUM (MP_TAC o Q.SPECL [`(Section k ys1 m)::t`,`pc-1`,`i`,
       `(pos + LENGTH (line_bytes x2))`])
  \\ full_simp_tac(srw_ss())[all_enc_ok_def,code_similar_def]
  \\ rpt strip_tac \\ full_simp_tac(srw_ss())[]
  \\ Q.LIST_EXISTS_TAC [`line_bytes x2 ++ bs`,
        `j`,`bs2`] \\ full_simp_tac(srw_ss())[] \\ `pc - 1 + 1 = pc` by decide_tac
  \\ full_simp_tac(srw_ss())[AC ADD_COMM ADD_ASSOC]
QED

(* published line 1215 *)
val prog_to_bytes_lemma = prog_to_bytes_lemma
  |> Q.SPECL [`code2`,`code1`,`pc`,`i`,`0`]
  |> SIMP_RULE std_ss [];

(* published line 1219 *)
Theorem bytes_in_mem_APPEND[local]:
  !xs ys a m md md1.
      bytes_in_mem a (xs ++ ys) m md md1 <=>
      bytes_in_mem a xs m md md1 /\
      bytes_in_mem (a + n2w (LENGTH xs)) ys m md md1
Proof
  Induct \\ full_simp_tac(srw_ss())[bytes_in_mem_def,ADD1,GSYM word_add_n2w,CONJ_ASSOC]
QED

(* published line 1327 *)
Theorem UPDATE_COND_SELF[local]:
  ∀cs rc ar (regs:num -> 'a word) g k v.
    (λa. if MEM a cs ∨ a = k ∨ ¬(a < rc) ∨ MEM a ar then regs a else g a)⦇ k ↦ v ⦈ =
    (λa. if MEM a cs ∨ a = k ∨ ¬(a < rc) ∨ MEM a ar
         then (if a = k then v else regs a) else g a)
Proof
  rpt gen_tac \\ once_rewrite_tac[FUN_EQ_THM]
  \\ qx_gen_tac `aa` \\ rewrite_tac[APPLY_UPDATE_THM] \\ BETA_TAC
  \\ Cases_on `aa = k` \\ simp[]
QED

(* published line 1349 *)
Theorem word_loc_val_byte_labs_mono[local]:
  (∀l1 l2 x. lab_lookup l1 l2 labs = SOME x ⇒ lab_lookup l1 l2 labs' = SOME x) ∧
  word_loc_val_byte p labs m a be = SOME v ⇒
  word_loc_val_byte p labs' m a be = SOME v
Proof
  rw[word_loc_val_byte_def]
  \\ Cases_on `m (byte_align a)` \\ gvs[word_loc_val_def]
  \\ Cases_on `lab_lookup n n0 labs` \\ gvs[]
  \\ first_x_assum drule \\ simp[]
QED

(* published line 1360 *)
val s1 = ``s1:('a,lab_to_target$config,'ffi) labSem$state``;

(* published line 1362 *)
Theorem IMP_bytes_in_memory[local]:
  code_similar code1 code2 /\
    all_enc_ok mc_conf.target.config labs ffi_names 0 code2 /\
    (asm_fetch_aux pc code1 = SOME i) /\
    bytes_in_mem p (prog_to_bytes code2) m (dm:'a word set) dm1 ==>
    ?j.
      bytes_in_mem (p + n2w (pos_val pc 0 code2)) (line_bytes j) m dm dm1 /\
      line_ok (mc_conf:('a,'state,'b) machine_config).target.config
        labs ffi_names (pos_val pc 0 code2) j /\
      (pos_val (pc+1) 0 code2 = pos_val pc 0 code2 + LENGTH (line_bytes j)) /\
      line_similar i j
Proof
  rpt strip_tac
  \\ mp_tac prog_to_bytes_lemma \\ fs[] \\ rpt strip_tac
  \\ fs[bytes_in_mem_APPEND]
  \\ Q.EXISTS_TAC `j` \\ fs[] \\ decide_tac
QED

(* published line 1380 *)
Theorem IMP_bytes_in_memory_JumpReg[local]:
  code_similar s1.code code2 /\
    all_enc_ok mc_conf.target.config labs ffi_names 0 code2 /\
    bytes_in_mem p (prog_to_bytes code2) t1.mem t1.mem_domain s1.mem_domain /\
    (asm_fetch s1 = SOME (Asm (Asmi (JumpReg r1)) l n)) ==>
    bytes_in_memory ((p:'a word) + n2w (pos_val s1.pc 0 code2))
      (mc_conf.target.config.encode (JumpReg r1)) t1.mem t1.mem_domain /\
    asm_ok (JumpReg r1) (mc_conf: ('a,'state,'b) machine_config).target.config
Proof
  fs[asm_fetch_def,LET_DEF]
  \\ Q.SPEC_TAC (`s1.pc`,`pc`) \\ strip_tac
  \\ Q.SPEC_TAC (`s1.code`,`code1`) \\ strip_tac \\ strip_tac
  \\ mp_tac (IMP_bytes_in_memory |> Q.GENL [`m`,`dm`,`i`,`dm1`]) \\ fs[]
  \\ strip_tac \\ res_tac
  \\ Cases_on `j` \\ fs[line_similar_def] \\ srw_tac[][]
  \\ fs[line_ok_def,enc_with_nop_thm] \\ srw_tac[][] \\ fs[]
  \\ imp_res_tac bytes_in_mem_IMP \\ fs[]
  \\ fs[asm_fetch_aux_def,prog_to_bytes_def,LET_DEF,line_bytes_def,
         bytes_in_memory_APPEND]
QED

(* published line 1401 *)
val case_eq_thms0 = map TypeBase.case_eq_of [``:lab``, ``:'a option``]

(* published line 1402 *)
val bool_case_eq_thms = map (fn th =>
  let val v = th |> concl |> lhs |> rhs
  in th |> GEN v |> Q.ISPEC`T` |> SIMP_RULE bool_ss [] end) case_eq_thms0

(* published line 1406 *)
Theorem IMP_bytes_in_memory_Jump[local]:
  code_similar ^s1.code code2 /\
    all_enc_ok mc_conf.target.config labs ffi_names 0 code2 /\
    bytes_in_mem p (prog_to_bytes code2) t1.mem t1.mem_domain s1.mem_domain /\
    (asm_fetch s1 = SOME (LabAsm (Jump jtarget) l bytes n)) ==>
    ?tt enc.
      (tt = &(find_pos jtarget labs) -
            &(pos_val s1.pc 0 code2)) /\
      (enc = mc_conf.target.config.encode (Jump tt)) /\
      bytes_in_memory ((p:'a word) + n2w (pos_val s1.pc 0 code2))
        enc t1.mem t1.mem_domain /\
      asm_ok (Jump tt) (mc_conf: ('a,'state,'b) machine_config).target.config
Proof
  fs[asm_fetch_def,LET_DEF]
  \\ Q.SPEC_TAC (`s1.pc`,`pc`) \\ strip_tac
  \\ Q.SPEC_TAC (`s1.code`,`code1`) \\ strip_tac \\ strip_tac
  \\ mp_tac (IMP_bytes_in_memory |> Q.GENL [`m`,`dm`,`i`,`dm1`]) \\ fs[]
  \\ strip_tac \\ res_tac
  \\ Cases_on `j` \\ fs[line_similar_def]
  \\ rveq
  \\ fs[line_ok_def,enc_with_nop_thm,LET_DEF,get_label_def]
  \\ fs(bool_case_eq_thms) \\ imp_res_tac lab_lookup_IMP
  \\ fs[LET_DEF,lab_inst_def,get_label_def] \\ srw_tac[][]
  \\ imp_res_tac bytes_in_mem_IMP \\ fs[]
  \\ fs[asm_fetch_aux_def,prog_to_bytes_def,LET_DEF,line_bytes_def,
         bytes_in_memory_APPEND]
QED

(* published line 1434 *)
Theorem IMP_bytes_in_memory_JumpCmp[local]:
  code_similar ^s1.code code2 /\
    all_enc_ok mc_conf.target.config labs ffi_names 0 code2 /\
    bytes_in_mem p (prog_to_bytes code2) t1.mem t1.mem_domain s1.mem_domain /\
    (asm_fetch s1 = SOME (LabAsm (JumpCmp cmp rr ri jtarget) l bytes n)) ==>
    ?tt enc.
      (tt = &(find_pos jtarget labs) -
            &(pos_val s1.pc 0 code2)) /\
      (enc = mc_conf.target.config.encode (JumpCmp cmp rr ri tt)) /\
      bytes_in_memory ((p:'a word) + n2w (pos_val s1.pc 0 code2))
        enc t1.mem t1.mem_domain /\
      asm_ok (JumpCmp cmp rr ri tt) (mc_conf: ('a,'state,'b) machine_config).target.config
Proof
  fs[asm_fetch_def,LET_DEF]
  \\ Q.SPEC_TAC (`s1.pc`,`pc`) \\ strip_tac
  \\ Q.SPEC_TAC (`s1.code`,`code1`) \\ strip_tac \\ strip_tac
  \\ mp_tac (IMP_bytes_in_memory |> Q.GENL [`m`,`dm`,`i`,`dm1`]) \\ fs[]
  \\ strip_tac \\ res_tac
  \\ Cases_on `j` \\ fs[line_similar_def]
  \\ rveq
  \\ fs[line_ok_def,enc_with_nop_thm,LET_DEF,get_label_def]
  \\ fs(bool_case_eq_thms) \\ imp_res_tac lab_lookup_IMP
  \\ fs[LET_DEF,lab_inst_def,get_label_def] \\ srw_tac[][]
  \\ imp_res_tac bytes_in_mem_IMP \\ fs[]
  \\ fs[asm_fetch_aux_def,prog_to_bytes_def,LET_DEF,line_bytes_def,
         bytes_in_memory_APPEND]
QED

(* published line 1462 *)
Theorem IMP_bytes_in_memory_JumpCmp_1[local]:
  code_similar ^s1.code code2 /\
    all_enc_ok mc_conf.target.config labs ffi_names 0 code2 /\
    bytes_in_mem p (prog_to_bytes code2) t1.mem t1.mem_domain s1.mem_domain /\
    (asm_fetch s1 = SOME (LabAsm (JumpCmp cmp rr ri jtarget) l bytes n)) ==>
    ?tt bytes.
      (tt = &(find_pos jtarget labs) -
            &(pos_val s1.pc 0 code2)) /\
      enc_with_nop mc_conf.target.config.encode (JumpCmp cmp rr ri tt) bytes /\
      bytes_in_memory ((p:'a word) + n2w (pos_val s1.pc 0 code2))
        bytes t1.mem t1.mem_domain /\
      (pos_val (s1.pc+1) 0 code2 = pos_val s1.pc 0 code2 + LENGTH bytes) /\
      asm_ok (JumpCmp cmp rr ri tt) (mc_conf: ('a,'state,'b) machine_config).target.config
Proof
  fs[asm_fetch_def,LET_DEF]
  \\ Q.SPEC_TAC (`s1.pc`,`pc`) \\ strip_tac
  \\ Q.SPEC_TAC (`s1.code`,`code1`) \\ strip_tac \\ strip_tac
  \\ mp_tac (IMP_bytes_in_memory |> Q.GENL [`m`,`dm`,`i`,`dm1`]) \\ fs[]
  \\ strip_tac \\ res_tac
  \\ Cases_on `j` \\ fs[line_similar_def]
  \\ rveq
  \\ fs[line_ok_def,enc_with_nop_thm,LET_DEF,get_label_def]
  \\ fs(bool_case_eq_thms) \\ imp_res_tac lab_lookup_IMP
  \\ Q.EXISTS_TAC `l'` \\ fs[enc_with_nop_thm,PULL_EXISTS,line_length_def]
  \\ imp_res_tac bytes_in_mem_IMP \\ fs[line_bytes_def]
  \\ rveq \\ fs[lab_inst_def]
  \\ metis_tac[]
QED

(* published line 1491 *)
Theorem IMP_bytes_in_memory_Call[local]:
  code_similar ^s1.code code2 /\
    all_enc_ok
      (mc_conf: ('a,'state,'b) machine_config).target.config labs ffi_names 0 code2 /\
    bytes_in_mem p (prog_to_bytes code2) t1.mem
      (t1:'a asm_state).mem_domain s1.mem_domain /\
    (asm_fetch s1 = SOME (LabAsm (Call ww) l bytes n)) ==>
    F
Proof
  rpt strip_tac
  \\ full_simp_tac(srw_ss())[asm_fetch_def,LET_DEF]
  \\ imp_res_tac IMP_bytes_in_memory
  \\ Cases_on `j` \\ full_simp_tac(srw_ss())[line_similar_def] \\ srw_tac[][]
  \\ full_simp_tac(srw_ss())[line_ok_def] \\ rev_full_simp_tac(srw_ss())[]
QED

(* published line 1507 *)
Theorem IMP_bytes_in_memory_LocValue[local]:
  code_similar ^s1.code code2 /\
    all_enc_ok mc_conf.target.config labs ffi_names 0 code2 /\
    bytes_in_mem p (prog_to_bytes code2) t1.mem t1.mem_domain s1.mem_domain /\
    (asm_fetch s1 = SOME (LabAsm (LocValue reg (Lab l1 l2)) l bytes n)) ==>
    ?tt bytes.
      (tt = &(find_pos (Lab l1 l2) labs) -
            &(pos_val s1.pc 0 code2)) /\
      enc_with_nop mc_conf.target.config.encode (Loc reg tt) bytes /\
      bytes_in_memory ((p:'a word) + n2w (pos_val s1.pc 0 code2))
        bytes t1.mem t1.mem_domain /\
      (pos_val (s1.pc+1) 0 code2 = pos_val s1.pc 0 code2 + LENGTH bytes) /\
      asm_ok (Loc reg tt) (mc_conf: ('a,'state,'b) machine_config).target.config
Proof
  fs[asm_fetch_def,LET_DEF]
  \\ Q.SPEC_TAC (`s1.pc`,`pc`) \\ strip_tac
  \\ Q.SPEC_TAC (`s1.code`,`code1`) \\ strip_tac \\ strip_tac
  \\ mp_tac (IMP_bytes_in_memory |> Q.GENL [`m`,`dm`,`i`,`dm1`]) \\ fs[]
  \\ strip_tac \\ res_tac
  \\ Cases_on `j` \\ fs[line_similar_def] \\ srw_tac[][]
  \\ fs[line_ok_def,LET_DEF] \\ srw_tac[][]
  \\ fs(bool_case_eq_thms) \\ imp_res_tac lab_lookup_IMP
  \\ Q.EXISTS_TAC `l'` \\ fs[enc_with_nop_thm,PULL_EXISTS,line_length_def]
  \\ fs[LET_DEF,lab_inst_def,get_label_def] \\ srw_tac[][]
  \\ imp_res_tac bytes_in_mem_IMP \\ fs[]
  \\ fs[asm_fetch_aux_def,prog_to_bytes_def,LET_DEF,line_bytes_def,
         bytes_in_memory_APPEND] \\ srw_tac[][] \\ metis_tac[]
QED

(* published line 1536 *)
Theorem IMP_bytes_in_memory_Inst[local]:
  code_similar ^s1.code code2 /\
    all_enc_ok mc_conf.target.config labs ffi_names 0 code2 /\
    bytes_in_mem p (prog_to_bytes code2) t1.mem t1.mem_domain s1.mem_domain /\
    (asm_fetch s1 = SOME (Asm (Asmi(Inst i)) bytes len)) ==>
    ?bytes.
      enc_with_nop mc_conf.target.config.encode (Inst i) bytes /\
      bytes_in_memory ((p:'a word) + n2w (pos_val s1.pc 0 code2))
        bytes t1.mem t1.mem_domain /\
      bytes_in_mem ((p:'a word) + n2w (pos_val s1.pc 0 code2))
        bytes t1.mem t1.mem_domain s1.mem_domain /\
      (pos_val (s1.pc+1) 0 code2 = pos_val s1.pc 0 code2 + LENGTH bytes) /\
      asm_ok (Inst i) (mc_conf: ('a,'state,'b) machine_config).target.config
Proof
  fs[asm_fetch_def,LET_DEF]
  \\ Q.SPEC_TAC (`s1.pc`,`pc`) \\ strip_tac
  \\ Q.SPEC_TAC (`s1.code`,`code1`) \\ strip_tac \\ strip_tac
  \\ mp_tac (IMP_bytes_in_memory |> Q.GENL [`m`,`dm`,`i`,`dm1`]) \\ fs[]
  \\ strip_tac \\ res_tac
  \\ Cases_on `j` \\ fs[line_similar_def] \\ srw_tac[][]
  \\ fs[line_ok_def,LET_DEF] \\ srw_tac[][]
  \\ Q.EXISTS_TAC `l` \\ fs[enc_with_nop_thm,PULL_EXISTS,line_length_def]
  \\ qexists_tac `n` \\ fs[]
  \\ fs[LET_DEF,lab_inst_def,get_label_def] \\ srw_tac[][]
  \\ imp_res_tac bytes_in_mem_IMP \\ fs[]
  \\ fs[asm_fetch_aux_def,prog_to_bytes_def,LET_DEF,line_bytes_def,
         bytes_in_memory_APPEND] \\ srw_tac[][]
QED

(* published line 1565 *)
Theorem IMP_bytes_in_memory_CallFFI[local]:
  code_similar ^s1.code code2 /\
    all_enc_ok mc_conf.target.config labs ffi_names 0 code2 /\
    bytes_in_mem p (prog_to_bytes code2) t1.mem t1.mem_domain s1.mem_domain /\
    (asm_fetch s1 = SOME (LabAsm (CallFFI name) l bytes n)) ==>
    ?tt enc.
      (tt = -&(pos_val s1.pc 0 code2 + (3 + get_ffi_index ffi_names (ExtCall name)) * ffi_offset)) /\
      (enc = mc_conf.target.config.encode (Jump tt)) /\
      bytes_in_memory ((p:'a word) + n2w (pos_val s1.pc 0 code2))
        enc t1.mem t1.mem_domain /\
      asm_ok (Jump tt) (mc_conf: ('a,'state,'b) machine_config).target.config
Proof
  fs[asm_fetch_def,LET_DEF]
  \\ Q.SPEC_TAC (`s1.pc`,`pc`) \\ strip_tac
  \\ Q.SPEC_TAC (`s1.code`,`code1`) \\ strip_tac \\ strip_tac
  \\ mp_tac (IMP_bytes_in_memory |> Q.GENL [`m`,`dm`,`i`,`dm1`]) \\ fs[]
  \\ strip_tac \\ res_tac
  \\ Cases_on `j` \\ fs[line_similar_def] \\ srw_tac[][]
  \\ fs[line_ok_def,enc_with_nop_thm,LET_DEF] \\ srw_tac[][]
  \\ fs[LET_DEF,lab_inst_def,get_label_def] \\ srw_tac[][]
  \\ imp_res_tac bytes_in_mem_IMP \\ fs[]
  \\ fs[asm_fetch_aux_def,prog_to_bytes_def,LET_DEF,line_bytes_def,
         bytes_in_memory_APPEND]
QED

(* published line 1590 *)
Theorem IMP_bytes_in_memory_Halt[local]:
  code_similar ^s1.code code2 /\
    all_enc_ok mc_conf.target.config labs ffi_names 0 code2 /\
    bytes_in_mem p (prog_to_bytes code2) t1.mem t1.mem_domain s1.mem_domain /\
    (asm_fetch s1 = SOME (LabAsm Halt l bytes n)) ==>
    ?tt enc.
      (tt = -&(pos_val s1.pc 0 code2 + ffi_offset)) /\
      (enc = mc_conf.target.config.encode (Jump tt)) /\
      bytes_in_memory ((p:'a word) + n2w (pos_val s1.pc 0 code2))
        enc t1.mem t1.mem_domain /\
      asm_ok (Jump tt) (mc_conf: ('a,'state,'b) machine_config).target.config
Proof
  fs[asm_fetch_def,LET_DEF]
  \\ Q.SPEC_TAC (`s1.pc`,`pc`) \\ strip_tac
  \\ Q.SPEC_TAC (`s1.code`,`code1`) \\ strip_tac \\ strip_tac
  \\ mp_tac (IMP_bytes_in_memory |> Q.GENL [`m`,`dm`,`i`,`dm1`]) \\ fs[]
  \\ strip_tac \\ res_tac
  \\ Cases_on `j` \\ fs[line_similar_def] \\ srw_tac[][]
  \\ fs[line_ok_def,enc_with_nop_thm,LET_DEF] \\ srw_tac[][]
  \\ fs[LET_DEF,lab_inst_def,get_label_def] \\ srw_tac[][]
  \\ imp_res_tac bytes_in_mem_IMP \\ fs[]
  \\ fs[asm_fetch_aux_def,prog_to_bytes_def,LET_DEF,line_bytes_def,
         bytes_in_memory_APPEND]
QED

(* published line 1615 *)
Theorem IMP_bytes_in_memory_Install[local]:
  code_similar ^s1.code code2 /\
    all_enc_ok mc_conf.target.config labs ffi_names 0 code2 /\
    bytes_in_mem p (prog_to_bytes code2) t1.mem t1.mem_domain s1.mem_domain /\
    (asm_fetch s1 = SOME (LabAsm Install c l n)) ==>
    ?tt enc.
      (tt = -&(pos_val s1.pc 0 code2 + 2 * ffi_offset)) /\
      (enc = mc_conf.target.config.encode (Jump tt)) /\
      bytes_in_memory ((p:'a word) + n2w (pos_val s1.pc 0 code2))
        enc t1.mem t1.mem_domain /\
      asm_ok (Jump tt) (mc_conf: ('a,'state,'b) machine_config).target.config
Proof
  fs[asm_fetch_def]
  \\ Q.SPEC_TAC (`s1.pc`,`pc`) \\ strip_tac
  \\ Q.SPEC_TAC (`s1.code`,`code1`) \\ strip_tac \\ strip_tac
  \\ mp_tac (IMP_bytes_in_memory |> Q.GENL [`m`,`dm`,`i`,`dm1`]) \\ fs[]
  \\ strip_tac \\ res_tac
  \\ Cases_on `j` \\ fs[line_similar_def] \\ srw_tac[][]
  \\ fs[line_ok_def,enc_with_nop_thm] \\ srw_tac[][]
  \\ fs[lab_inst_def,get_label_def] \\ srw_tac[][]
  \\ imp_res_tac bytes_in_mem_IMP \\ fs[]
  \\ fs[asm_fetch_aux_def,prog_to_bytes_def,LET_DEF,line_bytes_def,
         bytes_in_memory_APPEND]
QED

(* published line 1746 *)
Theorem bytes_in_mem_IMP_memory[local]:
  !xs a.
      (!a. ~(a IN dm1) ==> m a = m1 a) ==>
      bytes_in_mem a xs m dm dm1 ==>
      bytes_in_memory a xs m1 dm
Proof
  Induct \\ full_simp_tac(srw_ss())[bytes_in_memory_def,bytes_in_mem_def]
QED

(* read/write bytearrays for FFI *)

(* published line 1757 *)
Theorem read_bytearray_state_rel[local]:
  !n a x.
      state_rel (mc_conf,code2,labs,p) s1 t1 ms1 /\
      (read_bytearray a n (mem_load_byte_aux s1.mem s1.mem_domain s1.be) = SOME x) ==>
      (read_bytearray a n
        (\a. if a IN mc_conf.prog_addresses then SOME (t1.mem a) else NONE) =
       SOME x)
Proof
  Induct
  \\ full_simp_tac(srw_ss())[read_bytearray_def]
  \\ rpt strip_tac
  \\ Cases_on `mem_load_byte_aux s1.mem s1.mem_domain s1.be a` \\ full_simp_tac(srw_ss())[]
  \\ Cases_on `read_bytearray (a + 1w) n (mem_load_byte_aux s1.mem s1.mem_domain s1.be)` \\ full_simp_tac(srw_ss())[]
  \\ res_tac \\ full_simp_tac(srw_ss())[] \\ full_simp_tac(srw_ss())[state_rel_def,mem_load_byte_aux_def]
  \\ Cases_on `s1.mem (byte_align a)` \\ full_simp_tac(srw_ss())[] \\ srw_tac[][]
  \\ FIRST_X_ASSUM (Q.SPEC_THEN `a` mp_tac) \\ full_simp_tac(srw_ss())[]
  \\ rpt strip_tac \\ full_simp_tac(srw_ss())[word_loc_val_def]
  \\ rev_full_simp_tac(srw_ss())[word_loc_val_byte_def,word_loc_val_def]
QED

(* published line 1777 *)
Theorem IMP_has_io_name[local]:
  (asm_fetch s1 = SOME (LabAsm (CallFFI index) l bytes n)) ==>
    has_io_name index s1.code
Proof
  full_simp_tac(srw_ss())[asm_fetch_def]
  \\ Q.SPEC_TAC (`s1.pc`,`pc`)
  \\ Q.SPEC_TAC (`s1.code`,`code`)
  \\ HO_MATCH_MP_TAC asm_code_length_ind \\ rpt strip_tac
  \\ full_simp_tac(srw_ss())[asm_fetch_aux_def,has_io_name_def] \\ res_tac
  \\ Cases_on `is_Label y` \\ full_simp_tac(srw_ss())[]
  THEN1 (Cases_on `y` \\ full_simp_tac(srw_ss())[is_Label_def] \\ res_tac)
  \\ Cases_on `pc = 0` \\ full_simp_tac(srw_ss())[] \\ res_tac \\ full_simp_tac(srw_ss())[]
QED

(* published line 1791 *)
Theorem bytes_in_mem_asm_write_bytearray_lemma[local]:
  !xs p.
      (!a. ~(a IN k) ==> (m1 a = m2 a)) ==>
      bytes_in_mem p xs m1 d k ==>
      bytes_in_mem p xs m2 d k
Proof
  Induct \\ full_simp_tac(srw_ss())[bytes_in_mem_def]
QED

(* published line 1800 *)
Theorem bytes_in_mem_asm_write_bytearray[local]:
  (∀a. byte_align a ∈ s1.mem_domain ⇒ a ∈ s1.mem_domain) ∧
    (read_bytearray c1 (LENGTH new_bytes) (mem_load_byte_aux s1.mem s1.mem_domain s1.be) = SOME x) ==>
    bytes_in_mem p xs t1.mem t1.mem_domain s1.mem_domain ==>
    bytes_in_mem p xs
      (asm_write_bytearray c1 new_bytes t1.mem) t1.mem_domain s1.mem_domain
Proof
  STRIP_TAC \\ match_mp_tac bytes_in_mem_asm_write_bytearray_lemma
  \\ POP_ASSUM MP_TAC
  \\ Q.SPEC_TAC (`c1`,`a`)
  \\ Q.SPEC_TAC (`x`,`x`)
  \\ Q.SPEC_TAC (`t1.mem`,`m`)
  \\ Induct_on `new_bytes`
  \\ full_simp_tac(srw_ss())[asm_write_bytearray_def]
  \\ REPEAT STRIP_TAC
  \\ full_simp_tac(srw_ss())[read_bytearray_def]
  \\ BasicProvers.EVERY_CASE_TAC \\ full_simp_tac(srw_ss())[] \\ srw_tac[][]
  \\ full_simp_tac(srw_ss())[PULL_FORALL]
  \\ res_tac
  \\ POP_ASSUM (fn th => ONCE_REWRITE_TAC [GSYM th])
  \\ full_simp_tac(srw_ss())[mem_load_byte_aux_def]
  \\ BasicProvers.EVERY_CASE_TAC \\ full_simp_tac(srw_ss())[] \\ srw_tac[][]
  \\ srw_tac[][combinTheory.APPLY_UPDATE_THM]
  \\ full_simp_tac(srw_ss())[] \\ res_tac
QED

(* published line 1826 *)
Theorem write_bytearray_NOT_Loc[local]:
  !xs c1 s1 a c.
      (s1.mem a = Word c) ==>
      (write_bytearray c1 xs s1.mem s1.mem_domain s1.be) a <> Loc n n0
Proof
  Induct \\ full_simp_tac(srw_ss())[write_bytearray_def,mem_store_byte_aux_def]
  \\ rpt strip_tac \\ res_tac
  \\ BasicProvers.EVERY_CASE_TAC \\ full_simp_tac(srw_ss())[]
  \\ full_simp_tac(srw_ss())[labSemTheory.upd_mem_def] \\ srw_tac[][] \\ full_simp_tac(srw_ss())[APPLY_UPDATE_THM]
  \\ BasicProvers.EVERY_CASE_TAC \\ full_simp_tac(srw_ss())[] \\ rev_full_simp_tac(srw_ss())[]
QED

(* published line 1838 *)
Theorem CallFFI_bytearray_lemma[local]:
  byte_align (a:'a word) IN s1.mem_domain /\ good_dimindex (:'a) /\
    a IN t1.mem_domain /\
    a IN s1.mem_domain /\
    (s1.be = mc_conf.target.config.big_endian) /\
    (read_bytearray c1 (LENGTH new_bytes) (mem_load_byte_aux s1.mem s1.mem_domain s1.be) = SOME x) /\
    (word_loc_val_byte p labs s1.mem a mc_conf.target.config.big_endian =
       SOME (t1.mem a)) ==>
    (word_loc_val_byte p labs (write_bytearray c1 new_bytes s1.mem s1.mem_domain s1.be) a
       mc_conf.target.config.big_endian =
     SOME (asm_write_bytearray c1 new_bytes t1.mem a))
Proof
  Q.SPEC_TAC (`s1`,`s1`) \\ Q.SPEC_TAC (`t1`,`t1`) \\ Q.SPEC_TAC (`c1`,`c1`)
  \\ Q.SPEC_TAC (`x`,`x`) \\ Q.SPEC_TAC (`new_bytes`,`xs`) \\ Induct
  \\ full_simp_tac(srw_ss())[asm_write_bytearray_def,write_bytearray_def,read_bytearray_def]
  \\ rpt strip_tac
  \\ Cases_on `mem_load_byte_aux s1.mem s1.mem_domain s1.be c1` \\ full_simp_tac(srw_ss())[]
  \\ Cases_on `read_bytearray (c1 + 1w) (LENGTH xs) (mem_load_byte_aux s1.mem s1.mem_domain s1.be)`
  \\ full_simp_tac(srw_ss())[] \\ srw_tac[][]
  \\ qmatch_assum_rename_tac
       `read_bytearray (c1 + 1w) (LENGTH xs) (mem_load_byte_aux s1.mem s1.mem_domain s1.be) = SOME y`
  \\ FIRST_X_ASSUM (MP_TAC o Q.SPECL [`y`,`c1+1w`,`t1`,`s1`])
  \\ full_simp_tac(srw_ss())[] \\ rpt strip_tac \\ full_simp_tac(srw_ss())[mem_store_byte_aux_def]
  \\ reverse (Cases_on `(write_bytearray (c1 + 1w)
       xs s1.mem s1.mem_domain mc_conf.target.config.big_endian) (byte_align c1)`)
  \\ full_simp_tac(srw_ss())[] THEN1
   (full_simp_tac(srw_ss())[mem_load_byte_aux_def]
    \\ Cases_on `s1.mem (byte_align c1)` \\ full_simp_tac(srw_ss())[] \\ srw_tac[][]
    \\ imp_res_tac write_bytearray_NOT_Loc \\ rev_full_simp_tac(srw_ss())[] \\ full_simp_tac(srw_ss())[])
  \\ `byte_align c1 IN s1.mem_domain` by
    (full_simp_tac(srw_ss())[mem_load_byte_aux_def] \\ every_case_tac \\ full_simp_tac(srw_ss())[])
  \\ full_simp_tac(srw_ss())[labSemTheory.upd_mem_def,word_loc_val_byte_def,APPLY_UPDATE_THM]
  \\ Cases_on `a = c1` \\ full_simp_tac(srw_ss())[word_loc_val_def,good_dimindex_get_byte_set_byte]
  \\ Cases_on `byte_align c1 = byte_align a` \\ full_simp_tac(srw_ss())[word_loc_val_def]
  \\ full_simp_tac(srw_ss())[get_byte_set_byte_diff]
QED

(* inst correct *)

(* published line 2229 *)
val share_mem_state_rel_tac =
  rw[] >>
  gvs[IMP_CONJ_THM, AND_IMP_INTRO]
  >- (first_x_assum $ ho_match_mp_tac o cj 1 >> fs[] >> metis_tac[])
  >- (first_x_assum $ ho_match_mp_tac o cj 2 >> fs[] >> metis_tac[])
  >- (first_x_assum $ ho_match_mp_tac o cj 1 >> fs[] >> metis_tac[])
  >- (first_x_assum $ ho_match_mp_tac o cj 2 >> fs[] >> metis_tac[])

(* published line 3064 *)
Theorem line_length_MOD_0[local]:
  encoder_correct mc_conf.target /\
    (~EVEN p ==> (mc_conf.target.config.code_alignment = 0)) /\
    line_ok mc_conf.target.config labs ffi_names p h ==>
    (line_length h MOD 2 ** mc_conf.target.config.code_alignment = 0)
Proof
  Cases_on `h` \\ TRY (Cases_on `a`) \\ full_simp_tac(srw_ss())[line_ok_def,line_length_def]
  \\ srw_tac[][]
  \\ full_simp_tac(srw_ss())[encoder_correct_def,target_ok_def,enc_ok_def]
  \\ fs(bool_case_eq_thms)
  \\ full_simp_tac(srw_ss())[LET_DEF,enc_with_nop_thm] \\ srw_tac[][LENGTH_FLAT,LENGTH_REPLICATE]
  \\ qpat_x_assum `2 ** nn = xx:num` (ASSUME_TAC o GSYM) \\ full_simp_tac(srw_ss())[]
  \\ full_simp_tac(srw_ss())[LET_DEF,map_replicate,SUM_REPLICATE]
QED

(* published line 3079 *)
Theorem pos_val_MOD_0_lemma[local]:
  (0 MOD 2 ** mc_conf.target.config.code_alignment = 0)
Proof
  full_simp_tac(srw_ss())[]
QED

(* published line 3085 *)
val pos_val_MOD_0 = Q.prove(
  `!x pos code2.
      encoder_correct mc_conf.target /\
      (has_odd_inst code2 ==> (mc_conf.target.config.code_alignment = 0)) /\
      (~EVEN pos ==> (mc_conf.target.config.code_alignment = 0)) /\
      (pos MOD 2 ** mc_conf.target.config.code_alignment = 0) /\
      all_enc_ok mc_conf.target.config labs ffi_names pos code2 ==>
      (pos_val x pos code2 MOD 2 ** mc_conf.target.config.code_alignment = 0)`,
  reverse (Cases_on `encoder_correct mc_conf.target`)
  \\ asm_simp_tac pure_ss [] THEN1 full_simp_tac(srw_ss())[]
  \\ HO_MATCH_MP_TAC pos_val_ind
  \\ rpt strip_tac \\ full_simp_tac(srw_ss())[pos_val_def] \\ full_simp_tac(srw_ss())[all_enc_ok_def]
  THEN1 (srw_tac[][] \\ full_simp_tac(srw_ss())[PULL_FORALL,AND_IMP_INTRO,has_odd_inst_def])
  \\ Cases_on `is_Label y` \\ full_simp_tac(srw_ss())[]
  \\ Cases_on `x = 0` \\ full_simp_tac(srw_ss())[]
  \\ FIRST_X_ASSUM MATCH_MP_TAC \\ full_simp_tac(srw_ss())[] \\ srw_tac[][]
  \\ full_simp_tac(srw_ss())[has_odd_inst_def]
  \\ Cases_on `EVEN pos` \\ full_simp_tac(srw_ss())[]
  \\ full_simp_tac(srw_ss())[EVEN_ADD]
  \\ `0:num < 2 ** mc_conf.target.config.code_alignment` by full_simp_tac(srw_ss())[]
  \\ once_rewrite_tac [GSYM MOD_PLUS]
  \\ imp_res_tac line_length_MOD_0 \\ full_simp_tac(srw_ss())[])
  |> Q.SPECL [`x`,`0`,`y`] |> SIMP_RULE std_ss [GSYM AND_IMP_INTRO]
  |> SIMP_RULE std_ss [pos_val_MOD_0_lemma]
  |> REWRITE_RULE [AND_IMP_INTRO,GSYM CONJ_ASSOC];

(* published line 3111 *)
val IMP_IMP2 = METIS_PROVE [] ``a /\ (a /\ b ==> c) ==> ((a ==> b) ==> c)``

(* published line 3134 *)
Theorem word_cmp_lemma[local]:
  state_rel (mc_conf,code2,labs,p) s1 t1 ms1 /\
    (word_cmp cmp (read_reg rr s1) (reg_imm ri s1) = SOME x) ==>
    (x = word_cmp cmp (read_reg rr t1) (reg_imm ri t1))
Proof
  Cases_on `ri` \\ full_simp_tac(srw_ss())[labSemTheory.reg_imm_def,asmSemTheory.reg_imm_def]
  \\ full_simp_tac(srw_ss())[asmSemTheory.read_reg_def]
  \\ Cases_on `s1.regs rr` \\ full_simp_tac(srw_ss())[]
  \\ TRY (Cases_on `s1.regs n`) \\ full_simp_tac(srw_ss())[] \\ Cases_on `cmp`
  \\ full_simp_tac(srw_ss())[wordSemTheory.word_cmp_def,asmTheory.word_cmp_def]
  \\ srw_tac[][] \\ full_simp_tac(srw_ss())[state_rel_def]
  \\ qpat_x_assum `!bn. bn < _ ==> ~(MEM _ _)` kall_tac
  \\ first_x_assum (kall_tac o Q.SPEC `rr:num`)
  \\ first_assum (assume_tac o Q.SPEC `rr:num`)
  \\ first_x_assum (assume_tac o Q.SPEC `n:num`)
  \\ rev_full_simp_tac(srw_ss())[word_loc_val_def] \\ srw_tac[][]
  \\ BasicProvers.EVERY_CASE_TAC \\ full_simp_tac(srw_ss())[]
  \\ rpt (qpat_x_assum `1w = xxx` (fn th => full_simp_tac(srw_ss())[GSYM th]))
  \\ rpt (qpat_x_assum `p + n2w xxx = t1.regs rr` (fn th => full_simp_tac(srw_ss())[GSYM th]))
  \\ res_tac \\ full_simp_tac(srw_ss())[]
  \\ metis_tac[EVEN_add_AND]
QED

(* published line 3157 *)
Theorem list_add_if_fresh_simp[local]:
  !n s. list_add_if_fresh s l =
    if find_index s l n = NONE then
      APPEND l [s]
    else l
Proof
  Induct_on `l`
  >- fs [list_add_if_fresh_def, find_index_def]
  >-
    (rpt strip_tac
     >> FIRST_X_ASSUM (fn thm => ASSUME_TAC(Q.SPEC `n+1` thm))
     >> FIRST_X_ASSUM (fn thm => ASSUME_TAC(Q.SPEC `s` thm))
     >> fs [list_add_if_fresh_def, find_index_def]
     >> every_case_tac
     >> fs [list_add_if_fresh_def, find_index_def])
QED

(* published line 3182 *)
val list_add_if_fresh_simp = Q.SPECL [`n`,`s`] list_add_if_fresh_simp

(* published line 3184 *)
Theorem find_index_append[local]:
  !n. find_index s (l++l') n =
  (case find_index s l n of NONE => find_index s l' (n + LENGTH l) | SOME i => SOME i)
Proof
  Induct_on `l`
  >- fs [find_index_def]
  >-
  (rpt strip_tac
   >> FIRST_X_ASSUM (fn thm => ASSUME_TAC(Q.SPEC `n+1` thm))
   >> fs [find_index_def]
   >> every_case_tac
   >> fs [find_index_def,ADD1])
QED

(* published line 3198 *)
Theorem has_io_name_find_index[local]:
  !l s. has_io_name s l
  ==> ?y. find_index (ExtCall s) (find_ffi_names l) 0 = SOME y
Proof
  ho_match_mp_tac find_ffi_names_ind
  >> rpt strip_tac
  >> fs[has_io_name_def,find_index_def, find_ffi_names_def,Q.INST [`n`|->`0`] list_add_if_fresh_simp,find_index_append]
  >> every_case_tac
  >> fs[has_io_name_def,find_index_def, find_ffi_names_def,Q.INST [`n`|->`0`] list_add_if_fresh_simp,find_index_append]
  >> every_case_tac
  >> fs[has_io_name_def,find_index_def, find_ffi_names_def,Q.INST [`n`|->`0`] list_add_if_fresh_simp,find_index_append]
  >- metis_tac [NOT_NONE_SOME]
  >- (Cases_on `find_index (ExtCall s) (find_ffi_names (Section k xs md::rest)) 0`
      >> metis_tac [NOT_NONE_SOME])
QED

(* published line 3758 *)
Overload all_encd0 = ``λenc l. EVERY (sec_encd0 enc) l``

(* establishing encd0 *)

(* published line 3843 *)
Overload all_length_leq = ``λl. EVERY sec_length_leq l``

(* invariant: label annotated lengths are 0 or 1 *)

(* published line 5134 *)
Overload all_labs_exist = ``λlabs code. EVERY (sec_labs_exist labs) code``

(* Remove tail recursion from zero_labs_acc_exist *)

(* published line 6457 *)
Theorem all_enc_ok_prog_to_bytes_EVEN[local]:
  ∀code n c labs ffi pos.
   EVEN pos ∧
   all_enc_ok c labs ffi pos code ⇒
   EVEN (LENGTH (prog_to_bytes code))
Proof
  fs[prog_to_bytes_MAP]>>
  Induct>>fs[]>>Cases>>
  fs[all_enc_ok_cons]>>rw[EVEN_ADD]>>
  rfs[]>>
  fs[LENGTH_FLAT]>>
  `MAP line_length l = MAP LENGTH (MAP line_bytes l)` by
    metis_tac[lines_ok_MAP_line_byte_length]>>
  pop_assum SUBST_ALL_TAC >>simp[]>>
  metis_tac[EVEN_ADD]
QED

(* published line 6474 *)
Theorem loc_to_pc_append[local]:
  ∀l1 l2 c1 c2 conf labs ffis pos.
  EVERY sec_labels_ok (c1++c2) ⇒
  loc_to_pc l1 l2 (c1++c2) =
  case loc_to_pc l1 l2 c1 of
    SOME x => SOME x
  | NONE =>
    case loc_to_pc l1 l2 c2 of
      SOME x => SOME (x + SUM (MAP (len_no_lab o Section_lines) c1))
    | NONE => NONE
Proof
  Induct_on`c1`
  >-
    (fs[loc_to_pc_thm]>>
    rw[]>>every_case_tac>>fs[]>>metis_tac[])
  >>
  simp[Once loc_to_pc_thm,SimpLHS]>>
  simp[Once loc_to_pc_thm,SimpRHS]>>
  rw[]>>
  rpt(TOP_CASE_TAC>>fs[])
QED

(* published line 6656 *)
Theorem find_ffi_names_append[local]:
  ∀l1 l2.
  find_ffi_names (l1++l2) =
  (find_ffi_names l2) ++
  FILTER (λn. ¬ MEM n (find_ffi_names l2)) (find_ffi_names l1)
Proof
  ho_match_mp_tac find_ffi_names_ind>>rw[find_ffi_names_def]>>
  fs[FILTER_EQ_ID]>>
  TOP_CASE_TAC>>fs[]>>
  TOP_CASE_TAC>>fs[]>>
  fs[list_add_if_fresh_thm]>>rw[]>>
  fs[MEM_FILTER,FILTER_APPEND]>>
  fs[]
QED

(* published line 7129 *)
val enc_is_valid_mapped_access_tac =
    fs[is_valid_mapped_read_def,is_valid_mapped_write_def]
    \\ fs[enc_with_nop_thm]
    \\ rfs[]
    \\ drule_then assume_tac $
        cj 1 $ cj 1 $ PURE_REWRITE_RULE [EQ_IMP_THM] bytes_in_memory_APPEND
    \\ drule_then assume_tac bytes_in_memory_in_domain
    \\ irule bytes_in_memory_change_mem
    \\ qexists `t1.mem`
    \\ simp[];
(* ---- Forge additions: lab one-step function, step-closed invariants, prefix finishing lemmas ---- *)
open forge_targetInstallPrefixTheory forge_simZeroCaseTheory forge_simLayoutTheory forge_simRootTheory;
fun show_tac tag (g as (asl, w)) =
  (pr ("SHOW " ^ tag); List.app (fn a => pr ("  ASM " ^ term_to_string a)) (List.take (asl, Int.min (12, length asl)));
   pr ("  GOAL " ^ term_to_string w); ALL_TAC g);
val debug = ref false;
fun dbg tag g = if !debug then show_tac tag g else ALL_TAC g;

(* Generated from the published labSem evaluate_def: each recursive call evaluate X becomes SOME X;
   each final result becomes NONE. *)
Definition lab_step_def:
  lab_step (s:('a,'c,'ffi) labSem$state) =
    if s.clock = 0 then NONE else
    case asm_fetch s of
    | SOME (Asm (Asmi a) _ _) =>
        (case a of
         | Inst i =>
            (let s1 = asm_inst i s in
               if s1.failed then NONE
               else SOME (inc_pc (dec_clock s1)))
         | JumpReg r =>
            (case read_reg r s of
             | Loc n1 n2 =>
                 (case loc_to_pc n1 n2 s.code of
                  | NONE => NONE
                  | SOME p =>
                      SOME (upd_pc p (dec_clock s)))
             | _ => NONE)
         | _ => NONE)
    | SOME (Asm (ShareMem m r ad) _ _) =>
       (case share_mem_op m r ad s of
        | SOME (FFI_final outcome,s') => NONE
        | SOME (FFI_return _ _,s') =>
            SOME (s' with <| io_regs := shift_seq 1 s'.io_regs ;
                                 io_fp_regs := shift_seq 1 s'.io_fp_regs |>)
        | NONE => NONE)
    | SOME (LabAsm Halt _ _ _) =>
       (case s.regs s.ptr_reg of
        | Word 0w => NONE
        | Word _ => NONE
        | _ => NONE)
    | SOME (LabAsm (LocValue r lab) _ _ _) =>
       (if get_pc_value lab s = NONE then NONE else
          let s1 = upd_reg r (lab_to_loc lab) s in
            SOME (inc_pc (dec_clock s1)))
    | SOME (LabAsm (Jump l) _ _ _) =>
       (case get_pc_value l s of
        | NONE => NONE
        | SOME p => SOME (upd_pc p (dec_clock s)))
    | SOME (LabAsm (JumpCmp c r ri l) _ _ _) =>
       (case word_cmp c (read_reg r s) (reg_imm ri s) of
        | NONE => NONE
        | SOME F => SOME (inc_pc (dec_clock s))
        | SOME T =>
         (case get_pc_value l s of
          | NONE => NONE
          | SOME p => SOME (upd_pc p (dec_clock s))))
    | SOME (LabAsm (Call l) _ _ _) =>
       (case get_pc_value l s of
        | NONE => NONE
        | SOME p =>
         (case get_ret_Loc s of
          | NONE => NONE
          | SOME k =>
             let s1 = upd_reg s.link_reg k s in
               SOME (upd_pc p (dec_clock s1))))
    | SOME (LabAsm Install _ _ _) =>
       (case (code_buffer_install (SOME $ s.regs s.ptr_reg)
                                  (SOME $ s.regs s.len_reg)
                                  (SOME $ s.regs s.ptr2_reg)
                                  (mem_load_byte_aux s.mem s.mem_domain s.be)
                                  s.code_buffer,
              s.regs s.link_reg) of
        | (SOME (bytes, cb), Loc n1 n2) =>
           (case (loc_to_pc n1 n2 s.code) of
            | SOME new_pc =>
              let (cfg,prog) = s.compile_oracle 0 in (* the next oracle program *)
              let new_oracle = shift_seq 1 s.compile_oracle in
                (case (s.compile cfg prog, prog) of
                 | (SOME (bytes',cfg'), Section k _ _ :: _) =>
                   if bytes = bytes' ∧ FST(new_oracle 0) = cfg' then (* the oracle was correct *)
                     SOME
                       (s with <|
                                pc := new_pc
                              ; code_buffer := cb
                              ; code := s.code ++ prog
                              ; cc_regs := shift_seq 1 s.cc_regs
                              ; cc_fp_regs := shift_seq 1 s.cc_fp_regs
                              ; regs := (s.ptr_reg =+ Loc k 0)
                                          (λa. get_reg_value  (s.cc_regs 0 a)
                                                   (s.regs a) Word)
                              ; fp_regs := (λn. s.cc_fp_regs 0 n)
                              ; compile_oracle := new_oracle
                              ; clock := s.clock - 1
                              |>)
                   else
                     NONE
                 | _ => NONE)
                 | _ => NONE)
        | _ => NONE)
    | SOME (LabAsm (CallFFI ffi_index) _ _ _) =>
       (case (s.regs s.len_reg,s.regs s.ptr_reg,
              s.regs s.len2_reg,s.regs s.ptr2_reg,s.regs s.link_reg) of
        | (Word w, Word w2, Word w3, Word w4, Loc n1 n2) =>
         (case (read_bytearray w2 (w2n w) (mem_load_byte_aux s.mem s.mem_domain s.be),
                read_bytearray w4 (w2n w3) (mem_load_byte_aux s.mem s.mem_domain s.be),
                loc_to_pc n1 n2 s.code) of
          | (SOME bytes, SOME bytes2, SOME new_pc) =>
             (case call_FFI s.ffi (ExtCall ffi_index) bytes bytes2 of
              | FFI_final outcome => NONE
              | FFI_return new_ffi new_bytes =>
                  let new_io_regs = shift_seq 1 s.io_regs in
                  let new_io_fp_regs = shift_seq 1 s.io_fp_regs in
                  let new_m = write_bytearray w4 new_bytes s.mem s.mem_domain s.be in
                    SOME (s with <|
                                   mem := new_m ;
                                   ffi := new_ffi ;
                                   io_regs := new_io_regs ;
                                   io_fp_regs := new_io_fp_regs ;
                                   regs := (\a. get_reg_value (s.io_regs 0 (ExtCall ffi_index) a)
                                                  (s.regs a) Word);
                                   fp_regs := (\n. s.io_fp_regs 0 n);
                                   pc := new_pc ;
                                   clock := s.clock - 1 |>))
          | _ => NONE)
       | _ => NONE)
    | _ => NONE
End


(* An invariant of lab states that excludes the Install line and the shared-memory line,
   and is closed under one lab step. The shared-memory exclusion is a named premise:
   the general ShareMemOp simulation case is not proved here. *)
Definition lab_step_closed_def:
  lab_step_closed Inv <=>
    (!s i bs n. Inv s ==> asm_fetch s <> SOME (LabAsm Install i bs n)) /\
    (!s m r ad bs n. Inv s ==> asm_fetch s <> SOME (Asm (ShareMem m r ad) bs n)) /\
    (!s s'. Inv s /\ lab_step s = SOME s' ==> Inv s')
End

(* lab_step is the argument of the recursive call of the published evaluator. *)
Theorem lab_step_evaluate:
  !s s'. lab_step s = SOME s' ==> labSem$evaluate s = labSem$evaluate s'
Proof
  rpt gen_tac \\ simp[lab_step_def]
  \\ CONV_TAC (RAND_CONV (LAND_CONV (ONCE_REWRITE_CONV [labSemTheory.evaluate_def])))
  \\ rpt (TOP_CASE_TAC \\ simp[]) \\ rpt (pairarg_tac \\ gvs[])
  \\ rpt (TOP_CASE_TAC \\ gvs[]) \\ rw[] \\ gvs[]
QED

Definition nip_ctx_def:
  nip_ctx mc <=> mc.install_pc NOTIN mc.prog_addresses
End

Theorem seg_finish:
  (!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate (shift_interfer l c) io k ms2 /\
       find_next_interference c io (k + l) ms1 = find_next_interference (shift_interfer l c) io k ms2) ==>
  nip_ctx c ==> l <> 0 ==> !n. no_install_prefix (shift_interfer l c) io n ms2 ==>
  no_install_prefix c io (SUC n) ms1
Proof
  rpt strip_tac
  \\ irule no_install_prefix_mono
  \\ qexists_tac `l + n` \\ simp[]
  \\ irule segment_compose_no_install_prefix
  \\ fs[nip_ctx_def]
  \\ qexistsl_tac [`shift_interfer l c`,`io`,`ms2`]
  \\ simp[shift_interfer_def]
  \\ fs[shift_interfer_def]
QED

(* Reshape an induction hypothesis: move the two Forge premises behind the published ones. *)
fun peel ih =
  if is_imp (snd (dest_imp (concl ih))) then ih else
  let val (ante, n) = dest_imp (concl ih)
      val cs = strip_conj ante
      val k = length cs - 2
      val (pub, ext) = (List.take (cs, k), List.drop (cs, k))
      val _ = if same_const (fst (strip_comb (el 2 ext))) ``code_layout_ok`` then () else raise mk_HOL_ERR "forge" "peel" "unexpected hypothesis shape"
      val goal = mk_eq (concl ih, mk_imp (list_mk_conj pub, mk_imp (list_mk_conj ext, n)))
      val eq = prove (goal, rewrite_tac [AND_IMP_INTRO, GSYM CONJ_ASSOC])
  in EQ_MP eq ih end;

(* Split a published segment fact into the two equations, the end relation and the length fact. *)
val seg_split = qpat_x_assum `!k. targetSem$evaluate _ _ (k + _) _ = _ /\ _`
  (fn th => let val k = fst (dest_forall (concl th)); val cs = CONJUNCTS (SPEC k th)
            in assume_tac (el 3 cs) \\ assume_tac (el 4 cs) \\ assume_tac (GEN k (CONJ (el 1 cs) (el 2 cs))) end);

(* Discharge the two Forge premises of a reshaped hypothesis. inv_thms are case rewrites for lab_step. *)
fun ih_extras inv_thms (asl, w) =
  let val a = fst (dest_imp (fst (dest_imp w)))
  in (SUBGOAL_THEN a (fn th => disch_then (fn ih => assume_tac (MP ih th)))
      THENL [conj_tac
             >- (unabbrev_all_tac
                 \\ qpat_x_assum `lab_step_closed _` (strip_assume_tac o REWRITE_RULE [lab_step_closed_def])
                 \\ qpat_x_assum `!s s'. Inv s /\ lab_step s = SOME s' ==> Inv s'` irule \\ qexists_tac `s1`
                 \\ simp ([lab_step_def] @ inv_thms) \\ dbg "INV_RESIDUE")
             >- (first_assum ACCEPT_TAC), ALL_TAC]) (asl, w) end;


(* Close a case from: the split segment facts and a prefix fact at the segment end. *)
val nip_tail =
  qpat_x_assum `!k. targetSem$evaluate _ _ (k + _) _ = _ /\ _` (fn seg => mp_tac (MATCH_MP seg_finish seg))
  \\ (impl_tac >- first_assum ACCEPT_TAC)
  \\ (impl_tac >- first_assum ACCEPT_TAC)
  \\ disch_then (qspec_then `s1.clock - 1` mp_tac)
  \\ (impl_tac >- first_assum ACCEPT_TAC)
  \\ `SUC (s1.clock - 1) = s1.clock` by decide_tac
  \\ pop_assum (fn th => rewrite_tac [th]);

(* Finish a recursive case that used one published segment lemma. norm_thms normalise the next lab state. *)
fun nip_finish inv_thms norm_thms =
  dbg "BEFORE_EXTRAS"
  \\ ih_extras inv_thms
  \\ seg_split
  \\ qpat_x_assum `no_install_prefix _ _ _ _` (assume_tac o SIMP_RULE (srw_ss()) norm_thms)
  \\ dbg "FINISH"
  \\ nip_tail;

Definition halt_ctx_def:
  halt_ctx mc <=> mc.halt_pc NOTIN mc.prog_addresses /\ mc.halt_pc <> mc.install_pc
End

Theorem state_rel_ctx:
  state_rel (mc_conf,code2,labs,(p:'a word)) s1 t1 ms1 ==> nip_ctx mc_conf /\ halt_ctx mc_conf
Proof
  strip_tac
  \\ `mc_conf.install_pc NOTIN mc_conf.prog_addresses /\ mc_conf.halt_pc NOTIN mc_conf.prog_addresses /\
      p - n2w ffi_offset = mc_conf.halt_pc /\ p - n2w (2 * ffi_offset) = mc_conf.install_pc /\
      good_dimindex (:'a)` by (pop_assum mp_tac \\ simp[state_rel_def])
  \\ qpat_x_assum `state_rel _ _ _ _` kall_tac
  \\ simp[nip_ctx_def, halt_ctx_def]
  \\ spose_not_then assume_tac
  \\ `p - n2w ffi_offset = p - n2w (2 * ffi_offset)` by (rpt (qpat_x_assum `_ NOTIN _` kall_tac) \\ metis_tac[])
  \\ pop_assum mp_tac
  \\ rewrite_tac[wordsTheory.WORD_RCANCEL_SUB]
  \\ fs[lab_to_targetTheory.ffi_offset_def, good_dimindex_def, dimword_def]
QED


(* One non-ordinary step (FFI entry) followed by a prefix of the continuation. *)
Theorem step_nip:
  (!n. targetSem$evaluate c io (SUC n) ms = targetSem$evaluate c' io' n ms') ==>
  c.target.get_pc ms <> c.install_pc ==> c'.install_pc = c.install_pc ==> c'.target = c.target ==>
  !m. no_install_prefix c' io' m ms' ==> no_install_prefix c io (SUC m) ms
Proof
  rw[no_install_prefix_def]
  \\ Cases_on `j`
  >- (qpat_x_assum `evaluate _ _ 0 _ = _` mp_tac \\ simp[Once targetSemTheory.evaluate_def] \\ strip_tac \\ gvs[])
  \\ gvs[] \\ metis_tac[]
QED

(* A state off the installer entry whose every positive-clock run is final has every prefix safe. *)
Theorem final_nip:
  (!n. FST (targetSem$evaluate c io (SUC n) ms) <> TimeOut) ==>
  c.target.get_pc ms <> c.install_pc ==> !m. no_install_prefix c io m ms
Proof
  rw[no_install_prefix_def]
  \\ Cases_on `j`
  >- (qpat_x_assum `evaluate _ _ 0 _ = _` mp_tac \\ simp[Once targetSemTheory.evaluate_def] \\ strip_tac \\ gvs[])
  \\ first_x_assum (qspec_then `n` mp_tac) \\ simp[]
QED

(* Debug: print the goal and the assumptions that mention a given constant name. *)
fun dbgf tag name (g as (asl, w)) =
  (pr ("SHOWF " ^ tag);
   List.app (fn a => if String.isSubstring name (term_to_string a) andalso size (term_to_string a) < 600 then pr ("  ASM " ^ term_to_string a) else ()) asl;
   pr ("  GOAL " ^ term_to_string w); ALL_TAC g);

(* Facts about a shifted configuration, without rewriting by assumptions. *)
val shift_tac = rewrite_tac [shift_interfer_def] \\ simp_tac (srw_ss()) [] \\ TRY (first_assum ACCEPT_TAC);
val say = say0 "compile_no_install_prefix";

Theorem compile_no_install_prefix:
  lab_step_closed Inv ==>
  !^s1 res (mc_conf: ('a,'state,'b) machine_config) s2 code2 labs t1 ms1.
     oracle_tie mc_conf ms1 s1 /\
     (evaluate s1 = (res,s2)) /\ (res <> Error) /\
     encoder_correct mc_conf.target /\
     state_rel (mc_conf,code2,labs,p) s1 t1 ms1 ==>
     Inv s1 /\ code_layout_ok (:'a) code2 ==>
     no_install_prefix mc_conf s1.ffi s1.clock ms1
Proof
  strip_tac
  \\ HO_MATCH_MP_TAC labSemTheory.evaluate_ind \\ NTAC 2 STRIP_TAC
  \\ ONCE_REWRITE_TAC [labSemTheory.evaluate_def]
  \\ Cases_on `s1.clock = 0` \\ full_simp_tac(srw_ss())[]
  \\ REPEAT (Q.PAT_X_ASSUM `T` (K ALL_TAC)) \\ REPEAT STRIP_TAC
  THEN1 (qpat_assum `state_rel _ _ _ _` (mp_then Any mp_tac state_rel_no_install_prefix_layout) \\ simp[no_install_prefix_zero])
  \\ drule state_rel_ctx \\ strip_tac
  \\ Cases_on `asm_fetch s1` \\ full_simp_tac(srw_ss())[]
  \\ Cases_on `x` \\ full_simp_tac(srw_ss())[] \\ Cases_on `a` \\ full_simp_tac(srw_ss())[]
  \\ REPEAT (Q.PAT_X_ASSUM `T` (K ALL_TAC)) \\ full_simp_tac(srw_ss())[LET_DEF]
  THEN1 suspend "Asm"
  THEN1 suspend "ShareMemOp"
  THEN1 suspend "Jump"
  THEN1 suspend "JumpCmp"
  THEN1 suspend "Call"
  THEN1 suspend "LocValue"
  THEN1 suspend "CallFFI"
  THEN1 suspend "Install"
  THEN1 suspend "Halt"
QED

Theorem i2w_sub_nat[local,simp]:
  (i2w (&m - &n):'a word) = n2w m - n2w n
Proof
  rw [integerTheory.int_sub,GSYM integer_wordTheory.word_i2w_add,
      GSYM integer_wordTheory.MULT_MINUS_ONE,integer_wordTheory.i2w_pos]
  \\ metis_tac [WORD_NEG_MUL]
QED

Theorem i2w_neg_nat[local,simp]:
  (i2w (-&n):'a word) = -n2w n
Proof
  rw [GSYM integer_wordTheory.MULT_MINUS_ONE,integer_wordTheory.i2w_pos]
  \\ metis_tac [WORD_NEG_MUL]
QED

Resume compile_no_install_prefix[Asm]:
  fs[case_eq_thms]>>rw[]
  THEN1 (* Asm Inst *) (
     say "Asm Inst"
     \\ qmatch_assum_rename_tac `asm_fetch s1 = SOME (Asm (Asmi(Inst i)) bytes len)`
     \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
     \\ mp_tac IMP_bytes_in_memory_Inst
     \\ full_simp_tac(srw_ss())[]
     \\ impl_tac
     THEN1 (full_simp_tac(srw_ss())[state_rel_def])
     \\ rpt strip_tac \\ pop_assum mp_tac \\ pop_assum mp_tac
     \\ qpat_abbrev_tac `jj = asm$Inst i` \\ rpt strip_tac
     \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`,`s1.ffi`,`jj`]MP_TAC
          asm_step_IMP_evaluate_step_nop) \\ full_simp_tac(srw_ss())[]
     \\ disch_then (mp_tac o Q.SPEC `bytes'`)
     \\ impl_tac>-
      (imp_res_tac Inst_lemma \\ pop_assum (K all_tac)
       \\ full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF] \\ unabbrev_all_tac \\ full_simp_tac(srw_ss())[]
       \\ full_simp_tac(srw_ss())[asm_step_nop_def,asm_def,LET_DEF]
       \\ full_simp_tac(srw_ss())[asm_def,upd_pc_def,upd_reg_def]
       \\ conj_tac
       >- (fs[asm_fetch_def] >>
        `!op re a. Asmi (Inst i) <> ShareMem op re a` by simp[] >>
        drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_Asm >>
        simp[])
       \\ qpat_x_assum `bytes_in_mem ww bytes' t1.mem
             t1.mem_domain s1.mem_domain` mp_tac
       \\ match_mp_tac bytes_in_mem_IMP_memory \\ full_simp_tac(srw_ss())[])
     \\ rpt strip_tac \\ full_simp_tac(srw_ss())[]
     \\ rfs[] \\ fs[]
     \\ FIRST_X_ASSUM (MP_TAC o peel o Q.SPECL [`shift_interfer l mc_conf`,
          `code2`,`labs`,
          `(asm jj (t1.pc + n2w (LENGTH (bytes':word8 list))) t1)`,`ms2`])
     \\ impl_tac THEN1
      (conj_tac
       >- (irule oracle_tie_step
           \\ qpat_assum `oracle_tie _ _ _` (irule_at Any)
           \\ simp[labSemTheory.inc_pc_def,labSemTheory.dec_clock_def,
                   labSemTheory.upd_pc_def,asm_inst_consts]
           \\ metis_tac[])
       \\ unabbrev_all_tac \\ rpt strip_tac \\ full_simp_tac(srw_ss())[asm_def]
       THEN1 (full_simp_tac(srw_ss())[shift_interfer_def])
       \\ full_simp_tac(srw_ss())[GSYM PULL_FORALL]
       \\ match_mp_tac state_rel_shift_interfer
       \\ drule_then (qspecl_then [`t1`,`p`,`ms2`,`ms1`,`mc_conf`,`labs`,`code2`,`bytes'`] mp_tac)
            Inst_lemma
       \\ fs[])
     \\ nip_finish [] [inc_pc_def,dec_clock_def,asm_inst_consts])
  THEN1 (* Asm JumpReg *) (
    say "Asm JumpReg"
    \\ qmatch_assum_rename_tac `read_reg r1 s1 = Loc l1 l2`
    \\ Cases_on `loc_to_pc l1 l2 s1.code` \\ full_simp_tac(srw_ss())[]
    \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`, `s1.ffi`, `JumpReg r1`]MP_TAC
         asm_step_IMP_evaluate_step_find_next) \\ full_simp_tac(srw_ss())[]
    \\ impl_tac >-
     (full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF]
      \\ conj_tac
      >- (fs[asm_fetch_def]
        \\ drule_all $ GEN_ALL IMP_bytes_in_memory
        \\ strip_tac
        \\ fs[]
        \\ `!op re a. Asmi (JumpReg r1) <> ShareMem op re a` by simp[]
        \\ drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_Asm
        \\ `LENGTH ((mc_conf.target.config.encode (JumpReg r1))) <=
          LENGTH (line_bytes j)`
          suffices_by metis_tac[ffi_entry_pcs_disjoint_LENGTH_shorter]
        \\ Cases_on `j`
        \\ fs[line_similar_def,line_ok_def]
        \\ fs[enc_with_nop_thm,line_length_def]
        \\ Cases_on `a` >> fs[]
        \\ metis_tac[LENGTH_APPEND,LESS_EQ_ADD])
      \\ full_simp_tac(srw_ss())[asm_step_def,asm_def,LET_DEF]
      \\ imp_res_tac bytes_in_mem_IMP
      \\ full_simp_tac(srw_ss())[IMP_bytes_in_memory_JumpReg,asmSemTheory.upd_pc_def,
             asmSemTheory.assert_def]
      \\ imp_res_tac IMP_bytes_in_memory_JumpReg \\ full_simp_tac(srw_ss())[]
      \\ full_simp_tac(srw_ss())[asmSemTheory.read_reg_def]
      \\ full_simp_tac(srw_ss())[interference_ok_def,shift_seq_def]
      \\ FIRST_X_ASSUM (kall_tac o Q.SPEC `r1:num`)
      \\ qpat_x_assum `!n. n<s1.code_buffer.space_left ==> _` kall_tac
      \\ qpat_x_assum `!r. word_loc_val _ _ (read_reg r _) = _` (MP_TAC o Q.SPEC `r1:num`)
      \\ strip_tac \\ rev_full_simp_tac(srw_ss())[]
      \\ full_simp_tac(srw_ss())[word_loc_val_def]
      \\ Cases_on `lab_lookup l1 l2 labs` \\ full_simp_tac(srw_ss())[]
      \\ Q.PAT_X_ASSUM `xx = t1.regs r1` (fn th => full_simp_tac(srw_ss())[GSYM th])
      \\ FIRST_X_ASSUM (MP_TAC o Q.SPECL [`l1`,`l2`]) \\ full_simp_tac(srw_ss())[] \\ srw_tac[][]
      \\ (alignmentTheory.aligned_add_sub_cor
          |> SPEC_ALL |> UNDISCH |> CONJUNCT1 |> DISCH_ALL |> irule)
      \\ conj_tac >- fs[alignmentTheory.aligned_bitwise_and]
      \\ simp[aligned_w2n]
      \\ qmatch_goalsub_abbrev_tac`pv MOD dw MOD _`
      \\ `pv MOD dw = pv` by (
        simp[Abbr`pv`,Abbr`dw`]
        \\ irule LESS_EQ_LESS_TRANS
        \\ qexists_tac`LENGTH (prog_to_bytes code2)`
        \\ simp[]
        \\ drule pos_val_bound
        \\ disch_then(qspec_then`0`mp_tac o CONV_RULE SWAP_FORALL_CONV)
        \\ simp[] )
      \\ simp[]
      \\ qunabbrev_tac`pv`
      \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
      \\ match_mp_tac pos_val_MOD_0 \\ gvs[]
      \\ metis_tac[has_odd_inst_alignment] )
    \\ rpt strip_tac
    \\ rfs[] \\ fs[] \\ rfs[]
    \\ FIRST_X_ASSUM (mp_tac o peel o Q.SPECL [`shift_interfer l' mc_conf`,
         `code2`,`labs`,`(asm (JumpReg r1)
            (t1.pc + n2w (LENGTH (mc_conf.target.config.encode (JumpReg r1)))) t1)`,`ms2`])
    \\ impl_tac >-
     (conj_tac
       >- (irule oracle_tie_step
           \\ qpat_assum `oracle_tie _ _ _` (irule_at Any)
           \\ simp[labSemTheory.upd_pc_def,labSemTheory.dec_clock_def]
           \\ metis_tac[])
      \\ full_simp_tac(srw_ss())[shift_interfer_def,state_rel_def,asm_def,LET_DEF] \\ rev_full_simp_tac(srw_ss())[]
      \\ full_simp_tac(srw_ss())[asmSemTheory.upd_pc_def,asmSemTheory.assert_def,
             asmSemTheory.read_reg_def,dec_clock_def,labSemTheory.upd_pc_def,
             labSemTheory.assert_def]
      \\ full_simp_tac(srw_ss())[interference_ok_def,shift_seq_def]
      \\ FIRST_X_ASSUM (K ALL_TAC o Q.SPEC `r1:num`)
      \\ FIRST_X_ASSUM (K ALL_TAC o Q.SPEC `r1:num`)
      \\ FIRST_X_ASSUM (K ALL_TAC o Q.SPEC `r1:num`)
      \\ FIRST_X_ASSUM (MP_TAC o Q.SPEC `r1:num`)
      \\ strip_tac \\ rev_full_simp_tac(srw_ss())[]
      \\ full_simp_tac(srw_ss())[word_loc_val_def]
      \\ Cases_on `lab_lookup l1 l2 labs` \\ full_simp_tac(srw_ss())[]
      \\ Q.PAT_X_ASSUM `xx = t1.regs r1` (fn th => full_simp_tac(srw_ss())[GSYM th])
      \\ FIRST_X_ASSUM (MP_TAC o Q.SPECL [`l1`,`l2`]) \\ full_simp_tac(srw_ss())[] \\ srw_tac[][]
      \\ RES_TAC \\ full_simp_tac(srw_ss())[] \\ rpt strip_tac \\ res_tac \\ srw_tac[][]
      >- ((alignmentTheory.aligned_add_sub_cor
          |> SPEC_ALL |> UNDISCH |> CONJUNCT1 |> DISCH_ALL |> irule)
        \\ conj_tac >- fs[alignmentTheory.aligned_bitwise_and]
        \\ simp[aligned_w2n]
        \\ qmatch_goalsub_abbrev_tac`pv MOD dw MOD _`
        \\ `pv MOD dw = pv` by (
          simp[Abbr`pv`,Abbr`dw`]
          \\ irule LESS_EQ_LESS_TRANS
          \\ qexists_tac`LENGTH (prog_to_bytes code2)`
          \\ simp[]
          \\ drule pos_val_bound
          \\ disch_then(qspec_then`0`mp_tac o CONV_RULE SWAP_FORALL_CONV)
          \\ simp[] )
        \\ simp[]
        \\ qunabbrev_tac`pv`
        \\ match_mp_tac $ Q.GEN `ffi_names` pos_val_MOD_0 \\ fs[]
        \\ metis_tac[has_odd_inst_alignment])
      >- (fs[share_mem_state_rel_def] >> share_mem_state_rel_tac)
      >- fs[share_mem_domain_code_rel_def] )
    \\ nip_finish [] [labSemTheory.upd_pc_def,dec_clock_def])
QED
val _ = pr "CASE_PROVED Asm";

Resume compile_no_install_prefix[ShareMemOp]:
  say "ShareMemOp (excluded by the invariant premise)"
  \\ qpat_x_assum `lab_step_closed _` (strip_assume_tac o REWRITE_RULE [lab_step_closed_def])
  \\ qpat_x_assum `!s m r ad bs n. Inv s ==> _` drule
  \\ simp[]
QED
val _ = pr "CASE_PROVED ShareMemOp";

Resume compile_no_install_prefix[Jump]:
(* Jump *)
  say "Jump"
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (Jump jtarget) l1 l2 l3)`
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (Jump jtarget) l bytes n)`
  \\ Cases_on `get_pc_value jtarget s1` \\ full_simp_tac(srw_ss())[]
  \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
  \\ mp_tac IMP_bytes_in_memory_Jump \\ full_simp_tac(srw_ss())[]
  \\ match_mp_tac IMP_IMP \\ strip_tac
  THEN1 (full_simp_tac(srw_ss())[state_rel_def] \\ imp_res_tac bytes_in_mem_IMP \\ full_simp_tac(srw_ss())[])
  \\ rpt strip_tac \\ pop_assum mp_tac
  \\ qpat_abbrev_tac `jj = asm$Jump lll` \\ rpt strip_tac
  \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`,`s1.ffi`,`jj`]MP_TAC
       asm_step_IMP_evaluate_step_find_next) \\ full_simp_tac(srw_ss())[]
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
   (full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF]
    \\ full_simp_tac(srw_ss())[asm_step_def,asm_def,LET_DEF]
    \\ imp_res_tac bytes_in_mem_IMP
    \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,asmSemTheory.upd_pc_def]
    \\ rev_full_simp_tac(srw_ss())[] \\ unabbrev_all_tac
    \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,asmSemTheory.upd_pc_def,asm_def]
    \\ fs[asm_fetch_def]
    \\ drule_all $ GEN_ALL IMP_bytes_in_memory
    \\ strip_tac
    \\ fs[]
    \\ drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_LabAsm
    \\ `LENGTH
          ((mc_conf.target.config.encode
            (Jump
               (&(find_pos jtarget labs) -
                &(pos_val s1.pc 0 code2)))))
        <= LENGTH (line_bytes j)` suffices_by
      metis_tac[ffi_entry_pcs_disjoint_LENGTH_shorter]
    \\ Cases_on `j`
    \\ gvs[line_similar_def,line_ok_def,line_length_def,line_bytes_def]
    \\ fs[get_label_def]
    \\ Cases_on `jtarget`
    \\ fs[]
    \\ Cases_on `lab_lookup n'' n0 labs`
    \\ gvs[lab_inst_def,enc_with_nop_thm, LENGTH_APPEND]
    \\ drule lab_lookup_IMP
    \\ fs[]
  )
  \\ rpt strip_tac
  \\ FIRST_X_ASSUM (MP_TAC o peel o Q.SPECL [`shift_interfer l' mc_conf`,
       `code2`,`labs`,
       `(asm jj (t1.pc + n2w (LENGTH (mc_conf.target.config.encode jj))) t1)`,`ms2`])
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
   (conj_tac
     >- (irule oracle_tie_step
         \\ qpat_assum `oracle_tie _ _ _` (irule_at Any)
         \\ simp[labSemTheory.inc_pc_def,labSemTheory.dec_clock_def,
                 labSemTheory.upd_pc_def,labSemTheory.upd_reg_def,asm_inst_consts]
         \\ metis_tac[])
    \\ unabbrev_all_tac
    \\ full_simp_tac(srw_ss())[shift_interfer_def,state_rel_def,asm_def,LET_DEF] \\ rev_full_simp_tac(srw_ss())[]
    \\ full_simp_tac(srw_ss())[asmSemTheory.upd_pc_def,asmSemTheory.assert_def,
           asmSemTheory.read_reg_def, dec_clock_def,labSemTheory.upd_pc_def,
           labSemTheory.assert_def,asm_def,
           jump_to_offset_def]
    \\ full_simp_tac(srw_ss())[interference_ok_def,shift_seq_def,read_reg_def]
    \\ rewrite_tac [GSYM word_add_n2w,GSYM word_sub_def,WORD_SUB_PLUS,
          WORD_ADD_SUB] \\ full_simp_tac(srw_ss())[get_pc_value_def]
    \\ Cases_on `jtarget` \\ full_simp_tac(srw_ss())[]
    \\ qmatch_assum_rename_tac `loc_to_pc l1 l2 s1.code = SOME x`
    \\ FIRST_X_ASSUM (MP_TAC o Q.SPECL [`l1`,`l2`]) \\ full_simp_tac(srw_ss())[] \\ srw_tac[][]
    \\ imp_res_tac lab_lookup_IMP \\ full_simp_tac(srw_ss())[]
    >- metis_tac[]
    >- metis_tac[]
    >- (fs[share_mem_state_rel_def] >> share_mem_state_rel_tac)
    >- fs[share_mem_domain_code_rel_def] )
  \\ nip_finish [] [labSemTheory.upd_pc_def,dec_clock_def]
QED
val _ = pr "CASE_PROVED Jump";

Resume compile_no_install_prefix[JumpCmp]:
(* JumpCmp *)
  say "JumpCmp"
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (JumpCmp cmp rr ri jtarget) l1 l2 l3)`
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (JumpCmp cmp rr ri jtarget) l bytes n)`
  \\ `word_cmp cmp (read_reg rr s1) (labSem$reg_imm ri s1) =
      SOME (asm$word_cmp cmp (read_reg rr t1) (reg_imm ri t1))` by
   (Cases_on `word_cmp cmp (read_reg rr s1) (reg_imm ri s1)` \\ full_simp_tac(srw_ss())[]
    \\ imp_res_tac word_cmp_lemma \\ full_simp_tac(srw_ss())[])
  \\ full_simp_tac(srw_ss())[]
  \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
  \\ Cases_on `word_cmp cmp (read_reg rr t1) (reg_imm ri t1)` \\ full_simp_tac(srw_ss())[]


  THEN1
   (Cases_on `get_pc_value jtarget s1` \\ full_simp_tac(srw_ss())[]
    \\ mp_tac IMP_bytes_in_memory_JumpCmp \\ full_simp_tac(srw_ss())[]
    \\ match_mp_tac IMP_IMP \\ strip_tac
    THEN1 (full_simp_tac(srw_ss())[state_rel_def] \\ imp_res_tac bytes_in_mem_IMP \\ full_simp_tac(srw_ss())[])
    \\ rpt strip_tac \\ pop_assum mp_tac
    \\ qpat_abbrev_tac `jj = asm$JumpCmp cmp rr ri lll` \\ rpt strip_tac
    \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`,`s1.ffi`,`jj`]mp_tac
         asm_step_IMP_evaluate_step_find_next) \\ full_simp_tac(srw_ss())[]
    \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
     (full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF]
      \\ unabbrev_all_tac \\ full_simp_tac(srw_ss())[asm_step_def,asm_def,LET_DEF]
      \\ imp_res_tac bytes_in_mem_IMP
      \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,asmSemTheory.upd_pc_def]
      \\ rev_full_simp_tac(srw_ss())[] \\ unabbrev_all_tac
      \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,asmSemTheory.upd_pc_def,asm_def]
      \\ fs[asm_fetch_def]
      \\ drule_all $ GEN_ALL IMP_bytes_in_memory
      \\ strip_tac
      \\ fs[]
      \\ drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_LabAsm
      \\ ho_match_mp_tac (
        PURE_REWRITE_RULE [satTheory.AND_IMP] o
        PURE_REWRITE_RULE [Once CONJ_SYM] $
        GEN_ALL ffi_entry_pcs_disjoint_LENGTH_shorter )
      \\ Cases_on `j`
      \\ gvs[line_similar_def,line_ok_def,line_length_def,line_bytes_def]
      \\ fs[get_label_def]
      \\ Cases_on `jtarget`
      \\ fs[]
      \\ Cases_on `lab_lookup n'' n0 labs`
      \\ gvs[lab_inst_def,enc_with_nop_thm, LENGTH_APPEND]
      \\ drule lab_lookup_IMP
      \\ fs[]
    )
    \\ rpt strip_tac
    \\ FIRST_X_ASSUM (MP_TAC o peel o Q.SPECL [`shift_interfer l' mc_conf`,
         `code2`,`labs`,
         `(asm jj (t1.pc + n2w (LENGTH (mc_conf.target.config.encode jj))) t1)`,`ms2`])
    \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
     (conj_tac
       >- (irule oracle_tie_step
           \\ qpat_assum `oracle_tie _ _ _` (irule_at Any)
           \\ simp[labSemTheory.inc_pc_def,labSemTheory.dec_clock_def,
                   labSemTheory.upd_pc_def,labSemTheory.upd_reg_def,asm_inst_consts]
           \\ metis_tac[])
      \\ unabbrev_all_tac
      \\ full_simp_tac(srw_ss())[shift_interfer_def,state_rel_def,asm_def,LET_DEF] \\ rev_full_simp_tac(srw_ss())[]
      \\ full_simp_tac(srw_ss())[asmSemTheory.upd_pc_def,asmSemTheory.assert_def,
             asmSemTheory.read_reg_def, dec_clock_def,labSemTheory.upd_pc_def,
             labSemTheory.assert_def,asm_def,
             jump_to_offset_def]
      \\ full_simp_tac(srw_ss())[interference_ok_def,shift_seq_def,read_reg_def]
      \\ rewrite_tac [GSYM word_add_n2w,GSYM word_sub_def,WORD_SUB_PLUS,
            WORD_ADD_SUB] \\ full_simp_tac(srw_ss())[get_pc_value_def]
      \\ Cases_on `jtarget` \\ full_simp_tac(srw_ss())[]
      \\ qmatch_assum_rename_tac `loc_to_pc l1 l2 s1.code = SOME x`
      \\ FIRST_X_ASSUM (MP_TAC o Q.SPECL [`l1`,`l2`]) \\ full_simp_tac(srw_ss())[] \\ srw_tac[][]
      \\ imp_res_tac lab_lookup_IMP \\ full_simp_tac(srw_ss())[]
      >- metis_tac []
      >- metis_tac []
      >- (fs[share_mem_state_rel_def] >> share_mem_state_rel_tac)
      >- fs[share_mem_domain_code_rel_def] )
    \\ nip_finish [] [labSemTheory.upd_pc_def,dec_clock_def])
  \\ mp_tac (IMP_bytes_in_memory_JumpCmp_1) \\ full_simp_tac(srw_ss())[]
  \\ match_mp_tac IMP_IMP \\ strip_tac
  THEN1 (full_simp_tac(srw_ss())[state_rel_def] \\ imp_res_tac bytes_in_mem_IMP \\ full_simp_tac(srw_ss())[])
  \\ rpt strip_tac \\ pop_assum mp_tac \\ pop_assum mp_tac
  \\ qpat_abbrev_tac `jj = asm$JumpCmp cmp rr ri lll` \\ rpt strip_tac
  \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`,`s1.ffi`,`jj`]mp_tac
       asm_step_IMP_evaluate_step_nop) \\ full_simp_tac(srw_ss())[]
  \\ strip_tac \\ pop_assum (mp_tac o Q.SPEC `bytes'`)
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
   (full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF] \\ unabbrev_all_tac \\ full_simp_tac(srw_ss())[]
    \\ full_simp_tac(srw_ss())[asm_step_nop_def,asm_def,LET_DEF]
    \\ full_simp_tac(srw_ss())[asm_def,upd_pc_def,upd_reg_def]
    \\ fs[asm_fetch_def]
    \\ drule_all $ GEN_ALL IMP_bytes_in_memory
    \\ strip_tac
    \\ fs[]
    \\ drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_LabAsm
    \\ ho_match_mp_tac (
      PURE_REWRITE_RULE [satTheory.AND_IMP] o
      PURE_REWRITE_RULE [Once CONJ_SYM] $
      GEN_ALL ffi_entry_pcs_disjoint_LENGTH_shorter )
    \\ Cases_on `j`
    \\ gvs[line_similar_def,line_ok_def,line_length_def,line_bytes_def] )
  \\ rpt strip_tac
  \\ FIRST_X_ASSUM (MP_TAC o peel o Q.SPECL [`shift_interfer l' mc_conf`,
       `code2`,`labs`,
       `(asm jj (t1.pc + n2w (LENGTH (bytes':word8 list))) t1)`,`ms2`])
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
   (conj_tac
     >- (irule oracle_tie_step
         \\ qpat_assum `oracle_tie _ _ _` (irule_at Any)
         \\ simp[labSemTheory.inc_pc_def,labSemTheory.dec_clock_def,
                 labSemTheory.upd_pc_def,labSemTheory.upd_reg_def,asm_inst_consts]
         \\ metis_tac[])
    \\ unabbrev_all_tac
    \\ full_simp_tac(srw_ss())[shift_interfer_def,state_rel_def,asm_def,LET_DEF] \\ rev_full_simp_tac(srw_ss())[]
    \\ full_simp_tac(srw_ss())[asmSemTheory.upd_pc_def,asmSemTheory.assert_def,
           asmSemTheory.read_reg_def, dec_clock_def,labSemTheory.upd_pc_def,
           labSemTheory.assert_def,asm_def,
           jump_to_offset_def,inc_pc_def,asmSemTheory.upd_reg_def,
           labSemTheory.upd_reg_def]
    \\ full_simp_tac(srw_ss())[interference_ok_def,shift_seq_def,read_reg_def]
    \\ rewrite_tac [GSYM word_add_n2w,GSYM word_sub_def,WORD_SUB_PLUS,
          WORD_ADD_SUB] \\ full_simp_tac(srw_ss())[get_pc_value_def]
    \\ rpt strip_tac \\ res_tac \\ full_simp_tac(srw_ss())[]
    >- (fs[share_mem_state_rel_def] >> share_mem_state_rel_tac)
    >- fs[share_mem_domain_code_rel_def] )
  \\ nip_finish [] [inc_pc_def,dec_clock_def]
QED
val _ = pr "CASE_PROVED JumpCmp";

Resume compile_no_install_prefix[Call]:
(* Call *)
  say "Call"
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (Call lab) x1 x2 x3)`
  \\ Cases_on `lab`
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (Call (Lab l1 l2)) l bytes len)`
  \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
  \\ (Q.SPECL_THEN [`Lab l1 l2`,`len`]mp_tac
          (Q.GENL[`ww`,`n`]IMP_bytes_in_memory_Call))
  \\ match_mp_tac IMP_IMP \\ strip_tac \\ full_simp_tac(srw_ss())[]
  \\ full_simp_tac(srw_ss())[state_rel_def] \\ imp_res_tac bytes_in_mem_IMP \\ full_simp_tac(srw_ss())[]
QED
val _ = pr "CASE_PROVED Call";

Resume compile_no_install_prefix[LocValue]:
(* LocValue *)
  say "LocValue"
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (LocValue reg lab) x1 x2 x3)`
  \\ Cases_on `lab`
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (LocValue reg (Lab l1 l2)) ww bytes len)`
  \\ full_simp_tac(srw_ss())[lab_to_loc_def]
  \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
  \\ mp_tac (Q.INST [`l`|->`ww`,`n`|->`len`]
             IMP_bytes_in_memory_LocValue) \\ full_simp_tac(srw_ss())[]
  \\ match_mp_tac IMP_IMP \\ strip_tac
  THEN1 (full_simp_tac(srw_ss())[state_rel_def]
         \\ imp_res_tac bytes_in_mem_IMP \\ full_simp_tac(srw_ss())[])
  \\ rpt strip_tac \\ pop_assum mp_tac
  \\ Cases_on `get_pc_value (Lab l1 l2) s1` \\ fs []
  \\ qpat_abbrev_tac `jj = asm$Loc reg lll` \\ rpt strip_tac
  \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`,`s1.ffi`,`jj`]mp_tac
       asm_step_IMP_evaluate_step_nop) \\ full_simp_tac(srw_ss())[]
  \\ strip_tac \\ pop_assum (mp_tac o Q.SPEC `bytes'`)
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
   (full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF]
    \\ unabbrev_all_tac \\ full_simp_tac(srw_ss())[]
    \\ full_simp_tac(srw_ss())[asm_step_nop_def,asm_def,LET_DEF]
    \\ full_simp_tac(srw_ss())[asm_def,upd_pc_def,upd_reg_def]
    \\ fs[asm_fetch_def]
    \\ drule_all $ GEN_ALL IMP_bytes_in_memory
    \\ strip_tac
    \\ fs[]
    \\ drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_LabAsm
    \\ ho_match_mp_tac (
      PURE_REWRITE_RULE [satTheory.AND_IMP] o
      PURE_REWRITE_RULE [Once CONJ_SYM] $
      GEN_ALL ffi_entry_pcs_disjoint_LENGTH_shorter )
    \\ Cases_on `j`
    \\ gvs[line_similar_def,line_ok_def,line_length_def,line_bytes_def] )
  \\ rpt strip_tac
  \\ FIRST_X_ASSUM (MP_TAC o peel o Q.SPECL [`shift_interfer l mc_conf`,
       `code2`,`labs`,
       `(asm jj (t1.pc + n2w (LENGTH (bytes':word8 list))) t1)`,`ms2`])
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1
   (conj_tac
     >- (irule oracle_tie_step
         \\ qpat_assum `oracle_tie _ _ _` (irule_at Any)
         \\ simp[labSemTheory.inc_pc_def,labSemTheory.dec_clock_def,
                 labSemTheory.upd_pc_def,labSemTheory.upd_reg_def,asm_inst_consts]
         \\ metis_tac[])
    \\ unabbrev_all_tac
    \\ full_simp_tac(srw_ss())[shift_interfer_def,state_rel_def,asm_def,LET_DEF]
    \\ rev_full_simp_tac(srw_ss())[]
    \\ full_simp_tac(srw_ss())[asmSemTheory.upd_pc_def,asmSemTheory.assert_def,
           asmSemTheory.read_reg_def, dec_clock_def,labSemTheory.upd_pc_def,
           labSemTheory.assert_def,asm_def,
           jump_to_offset_def,inc_pc_def,asmSemTheory.upd_reg_def,
           labSemTheory.upd_reg_def]
    \\ full_simp_tac(srw_ss())[interference_ok_def,shift_seq_def,read_reg_def]
    \\ rewrite_tac [GSYM word_add_n2w,GSYM word_sub_def,WORD_SUB_PLUS,
          WORD_ADD_SUB] \\ full_simp_tac(srw_ss())[get_pc_value_def]
    \\ full_simp_tac(srw_ss())[APPLY_UPDATE_THM] \\ srw_tac[][word_loc_val_def]
    \\ res_tac \\ full_simp_tac(srw_ss())[]
    >- (
      Cases_on `lab_lookup l1 l2 labs` \\ full_simp_tac(srw_ss())[]
      \\ imp_res_tac lab_lookup_IMP \\ srw_tac[][] )
    >- (fs[share_mem_state_rel_def] >> share_mem_state_rel_tac)
    >- fs[share_mem_domain_code_rel_def] )
  \\ nip_finish [lab_to_loc_def] [inc_pc_def,dec_clock_def,labSemTheory.upd_reg_def]
QED
val _ = pr "CASE_PROVED LocValue";

Resume compile_no_install_prefix[CallFFI]:
  say "CallFFI"
  \\ qmatch_assum_rename_tac `asm_fetch s1 = SOME (LabAsm (CallFFI s) l1 l2 l3)`
  \\ qmatch_assum_rename_tac
       `asm_fetch s1 = SOME (LabAsm (CallFFI s) l bytes n)`
  \\ Cases_on `s1.regs s1.len_reg` \\ full_simp_tac(srw_ss())[]
  \\ Cases_on `s1.regs s1.len2_reg` \\ full_simp_tac(srw_ss())[]
  \\ Cases_on `s1.regs s1.link_reg` \\ full_simp_tac(srw_ss())[]
  \\ Cases_on `s1.regs s1.ptr_reg` \\ full_simp_tac(srw_ss())[]
  \\ Cases_on `s1.regs s1.ptr2_reg` \\ full_simp_tac(srw_ss())[]
  \\ qmatch_assum_rename_tac `read_reg _.len2_reg _ = Word c2`
  \\ qmatch_assum_rename_tac `read_reg _.ptr2_reg _ = Word c2'`
  \\ qmatch_assum_rename_tac `read_reg _.ptr_reg _ = Word c'`
  \\ Cases_on `read_bytearray c' (w2n c) (mem_load_byte_aux s1.mem s1.mem_domain s1.be)`
  \\ full_simp_tac(srw_ss())[]
  \\ Cases_on `read_bytearray c2' (w2n c2) (mem_load_byte_aux s1.mem s1.mem_domain s1.be)`
  \\ full_simp_tac(srw_ss())[]
  \\ qmatch_assum_rename_tac `s1.regs s1.link_reg = Loc n1 n2`
  \\ qmatch_asmsub_abbrev_tac `loc_to_pc a1 a2 a3`
  \\ Cases_on `loc_to_pc a1 a2 a3` >- fs[]
  \\ unabbrev_all_tac \\ fs[]
  \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
  \\ mp_tac (Q.GEN `name` IMP_bytes_in_memory_CallFFI) \\ full_simp_tac(srw_ss())[]
  \\ match_mp_tac IMP_IMP \\ strip_tac
  THEN1 (
    full_simp_tac(srw_ss())[state_rel_def]
    \\ imp_res_tac bytes_in_mem_IMP \\ full_simp_tac(srw_ss())[]
  )
  \\ rpt strip_tac \\ pop_assum mp_tac
  \\ qpat_abbrev_tac `jj = asm$Jump lll` \\ rpt strip_tac
  \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`,`s1.ffi`,`jj`]mp_tac
       asm_step_IMP_evaluate_step_find_next) \\ full_simp_tac(srw_ss())[]
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1 (
    full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF]
    \\ full_simp_tac(srw_ss())[asm_step_def,asm_def,LET_DEF]
    \\ imp_res_tac bytes_in_mem_IMP
    \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,
         asmSemTheory.upd_pc_def]
    \\ rev_full_simp_tac(srw_ss())[] \\ unabbrev_all_tac
    \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,
         asmSemTheory.upd_pc_def,asm_def]
    \\ fs[asm_fetch_def]
    \\ drule_all $ GEN_ALL IMP_bytes_in_memory
    \\ strip_tac
    \\ fs[]
    \\ drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_LabAsm
    \\ ho_match_mp_tac (
      PURE_REWRITE_RULE [satTheory.AND_IMP] o
      PURE_REWRITE_RULE [Once CONJ_SYM] $
      GEN_ALL ffi_entry_pcs_disjoint_LENGTH_shorter )
    \\ Cases_on `j`
    \\ gvs[line_similar_def,line_ok_def,line_length_def,line_bytes_def]
    \\ gvs[lab_inst_def,enc_with_nop_thm, LENGTH_APPEND]
  )
  \\ rpt strip_tac
  \\ Cases_on `loc_to_pc n1 n2 s1.code` \\ full_simp_tac(srw_ss())[]
  \\ qmatch_assum_rename_tac `loc_to_pc n1 n2 s1.code = SOME new_pc`
  \\ `mc_conf.target.get_pc ms2 = p - n2w ((3 + get_ffi_index ffi_names (ExtCall s)) * ffi_offset)` by
   (full_simp_tac(srw_ss())[GSYM PULL_FORALL]
    \\ full_simp_tac(srw_ss())[state_rel_def] \\ rev_full_simp_tac(srw_ss())[]
    \\ full_simp_tac(srw_ss())
         [encoder_correct_def,target_ok_def,target_state_rel_def]
    \\ unabbrev_all_tac
    \\ full_simp_tac(srw_ss())[asm_def,asmSemTheory.jump_to_offset_def,
         asmSemTheory.upd_pc_def]
    \\ rewrite_tac [GSYM word_sub_def,WORD_SUB_PLUS,
         GSYM word_add_n2w,WORD_ADD_SUB]) \\ full_simp_tac(srw_ss())[]
  \\ `has_io_name s s1.code` by
        (imp_res_tac IMP_has_io_name \\ NO_TAC)
  \\ `MEM (ExtCall s) mc_conf.ffi_names` by (
    imp_res_tac has_io_name_find_index>>
    imp_res_tac find_index_is_MEM>>
    gvs[list_subset_def,state_rel_def,EVERY_MEM,Abbr`ffi_names`]>>
    drule_all mmio_pcs_min_index_is_SOME >>
    strip_tac >>
    gvs[MEM_FILTER] >>
    `MEM s mc_conf.ffi_names` by (
      first_x_assum irule >> gvs[]) >>
    gvs[MEM_EL] >>
    `n'' < i` by (
      spose_not_then assume_tac >>
      `i <= n''` by decide_tac >>
      first_x_assum drule_all >>
      gvs[]
    ) >>
    qexists `n''` >>
    gvs[] >>
    irule $ GSYM EL_TAKE >>
    simp[]
  )
  \\ `~(mc_conf.target.get_pc ms2 IN mc_conf.prog_addresses) /\
      ~(mc_conf.target.get_pc ms2 = mc_conf.halt_pc) /\
      ~(mc_conf.target.get_pc ms2 = mc_conf.install_pc) /\
      (find_index (mc_conf.target.get_pc ms2) mc_conf.ffi_entry_pcs 0 =
         SOME (get_ffi_index mc_conf.ffi_names (ExtCall s))) /\
      get_ffi_index mc_conf.ffi_names (ExtCall s) = get_ffi_index ffi_names (ExtCall s)` by (
     full_simp_tac(srw_ss())[state_rel_def]>>
     first_x_assum $ qspecl_then [`ExtCall s`, `i`] drule >>
     gvs[] >>
     impl_keep_tac
     >- (irule ffi_name_NOT_Mapped >> fs[]) >>
     `get_ffi_index mc_conf.ffi_names (ExtCall s) = get_ffi_index ffi_names (ExtCall s)`
       suffices_by gvs[] >>
     gvs[get_ffi_index_def,backendPropsTheory.the_eqn] >>
     gvs[Abbr`ffi_names`] >>
     imp_res_tac find_index_MEM >>
     first_x_assum $ qspec_then `0` assume_tac >>fs[]>>
     fs[CaseEq"option"]>>irule OR_INTRO_THM2>>
     Cases_on ‘i ≤ LENGTH mc_conf.ffi_names’>>fs[]>-
      (
      drule LENGTH_TAKE>>strip_tac>>
      irule find_index_APPEND1>>fs[]>>
      qexists_tac `DROP i mc_conf.ffi_names` >>
      fs[TAKE_DROP])>>
     fs[NOT_LESS_EQUAL,TAKE_LENGTH_TOO_LONG])

  \\ `EL (get_ffi_index mc_conf.ffi_names (ExtCall s)) mc_conf.ffi_names = (ExtCall s)` by (
    irule EL_get_ffi_index_MEM >> simp[]
  )
  \\ sg `(mc_conf.target.get_reg ms2 mc_conf.ptr_reg = t1.regs mc_conf.ptr_reg) /\
      (mc_conf.target.get_reg ms2 mc_conf.len_reg = t1.regs mc_conf.len_reg) /\
      (mc_conf.target.get_reg ms2 mc_conf.ptr2_reg = t1.regs mc_conf.ptr2_reg) /\
      (mc_conf.target.get_reg ms2 mc_conf.len2_reg = t1.regs mc_conf.len2_reg) /\
      !a. a IN mc_conf.prog_addresses ==>
          (mc_conf.target.get_byte ms2 a = t1.mem a)`
  >- (
    qpat_x_assum `!k. _` (strip_assume_tac o SPEC_ALL)
    \\ gvs[asmPropsTheory.target_state_rel_def,asm_def,jump_to_offset_def,
           asmSemTheory.upd_pc_def]
    \\ unabbrev_all_tac \\ full_simp_tac(srw_ss())[state_rel_def,asm_def,
         jump_to_offset_def,asmSemTheory.upd_pc_def,AND_IMP_INTRO]
    \\ rpt strip_tac \\ first_x_assum match_mp_tac
    \\ full_simp_tac(srw_ss())[reg_ok_def]
  )
  \\ full_simp_tac(srw_ss())[]
  \\ `(t1.regs mc_conf.ptr_reg = c') /\
      (t1.regs mc_conf.len_reg = c) /\
      (t1.regs mc_conf.ptr2_reg = c2') /\
      (t1.regs mc_conf.len2_reg = c2)` by
   (full_simp_tac(srw_ss())[state_rel_def]
    \\ Q.PAT_X_ASSUM `!r. word_loc_val p labs (s1.regs r) = SOME (t1.regs r)`
         (fn th =>
        MP_TAC (Q.SPEC `(mc_conf: ('a,'state,'b) machine_config).ptr_reg` th)
        \\ MP_TAC (Q.SPEC `(mc_conf: ('a,'state,'b) machine_config).len_reg` th)
        \\ MP_TAC (Q.SPEC `(mc_conf: ('a,'state,'b) machine_config).ptr2_reg` th)
        \\ MP_TAC (Q.SPEC `(mc_conf: ('a,'state,'b) machine_config).len2_reg` th))
    \\ Q.PAT_X_ASSUM `xx = s1.ptr_reg` (ASSUME_TAC o GSYM)
    \\ Q.PAT_X_ASSUM `xx = s1.len_reg` (ASSUME_TAC o GSYM)
    \\ Q.PAT_X_ASSUM `xx = s1.ptr2_reg` (ASSUME_TAC o GSYM)
    \\ Q.PAT_X_ASSUM `xx = s1.len2_reg` (ASSUME_TAC o GSYM)
    \\ full_simp_tac(srw_ss())[word_loc_val_def] \\ NO_TAC)
  \\ full_simp_tac(srw_ss())[]
  \\ imp_res_tac read_bytearray_state_rel \\ full_simp_tac(srw_ss())[]
  \\ reverse(Cases_on `call_FFI s1.ffi (ExtCall s) x x'`) THEN1
   ((* FFI_final *)
   sg `!n. FST (targetSem$evaluate (shift_interfer l' mc_conf) s1.ffi (SUC n) ms2) <> TimeOut`
   >- (gen_tac
       \\ once_rewrite_tac [targetSemTheory.evaluate_def]
       \\ simp[shift_interfer_def]
       \\ rpt (TOP_CASE_TAC \\ simp[])
       \\ fs[shift_interfer_def,read_ffi_bytearrays_def,read_ffi_bytearray_def]
       \\ gvs[]
       \\ dbg "FFI_FINAL_RESIDUE")
   \\ seg_split
   \\ qpat_x_assum `!n. FST _ <> TimeOut` (fn th => mp_tac (MATCH_MP final_nip th))
   \\ (impl_tac >- shift_tac)
   \\ disch_then (qspec_then `s1.clock - 1` assume_tac)
   \\ nip_tail)
  (* FFI_return *)
  \\ full_simp_tac(srw_ss())[]
  \\ qmatch_assum_rename_tac
       `call_FFI s1.ffi (ExtCall s) x x' = FFI_return new_ffi new_bytes`
  \\ FIRST_X_ASSUM (Q.SPECL_THEN [
       `shift_interfer l' mc_conf with
        ffi_interfer := shift_seq 1 mc_conf.ffi_interfer`,
       `code2`,`labs`,
       `t1 with <| pc := p + n2w (pos_val new_pc 0 (code2:sec list)) ;
                   mem := asm_write_bytearray c2' new_bytes t1.mem ;
                   regs := \a. get_reg_value (s1.io_regs 0 (ExtCall s) a) (t1.regs a) I ;
                   fp_regs := \n. s1.io_fp_regs 0 n |>`,
       `mc_conf.ffi_interfer 0 (get_ffi_index mc_conf.ffi_names (ExtCall s),new_bytes,ms2)`]mp_tac)
  \\ MATCH_MP_TAC IMP_IMP \\ STRIP_TAC THEN1 (
    (conj_tac
      >- (
        sg `oracle_tie (shift_interfer l' mc_conf) ms2 s1`
        >- (
          irule oracle_tie_shift_interfer
          \\ qexists_tac `ms1`
          \\ conj_tac
          >- (gen_tac
              \\ qpat_x_assum `!k. _ /\ _ /\ _ /\ _` (qspec_then `k` strip_assume_tac)
              \\ first_assum ACCEPT_TAC)
          \\ first_assum ACCEPT_TAC
        )
        \\ `(shift_interfer l' mc_conf).ffi_interfer = mc_conf.ffi_interfer` by
             simp[shift_interfer_def]
        \\ sg `next_interference (shift_interfer l' mc_conf) s1.ffi ms2 =
            SOME (FfiApp (get_ffi_index mc_conf.ffi_names (ExtCall s)) new_bytes ms2
                    (mc_conf.ffi_interfer 0
                       (get_ffi_index mc_conf.ffi_names (ExtCall s),new_bytes,ms2)),
                  shift_interfer l' mc_conf with
                    ffi_interfer := shift_seq 1 mc_conf.ffi_interfer, new_ffi)`
        >- (
          qpat_x_assum `(shift_interfer l' mc_conf).ffi_interfer = mc_conf.ffi_interfer`
            (fn th => rewrite_tac[GSYM th])
          \\ irule next_interference_ExtCall
          \\ full_simp_tac(srw_ss())[shift_interfer_def,state_rel_def,
               read_ffi_bytearrays_def,read_ffi_bytearray_def]
          \\ rpt conj_tac
          >- (
            qpat_x_assum `mc_conf.target.get_pc ms2 = _` (fn th => rewrite_tac[GSYM th])
            \\ first_assum ACCEPT_TAC
          )
          >- (
            qpat_x_assum `mc_conf.target.get_pc ms2 = _` (fn th => rewrite_tac[GSYM th])
            \\ first_assum ACCEPT_TAC
          )
          >- (
            disj1_tac
            \\ qpat_x_assum `mc_conf.target.get_pc ms2 = _` (fn th => rewrite_tac[GSYM th])
            \\ qpat_x_assum `mc_conf.prog_addresses = _` (fn th => rewrite_tac[GSYM th])
            \\ first_assum ACCEPT_TAC
          )
          >- (
            qpat_x_assum `mc_conf.target.get_pc ms2 = _` (fn th => rewrite_tac[GSYM th])
            \\ first_assum ACCEPT_TAC
          )
          >- (
            `get_ffi_index ffi_names (ExtCall s) < i` by
               (qpat_x_assum `get_ffi_index mc_conf.ffi_names _ = _`
                  (fn th => rewrite_tac[GSYM th])
                \\ irule ffi_name_NOT_Mapped
                \\ simp[]
                \\ first_assum ACCEPT_TAC)
            \\ qpat_x_assum `!index. if _ then _ else _`
                 (qspec_then `get_ffi_index ffi_names (ExtCall s)` mp_tac)
            \\ rw[]
          )
          >- (
            qexists_tac `x` \\ qexists_tac `x'` \\ qexists_tac `s`
            \\ full_simp_tac(srw_ss())[]
            \\ rev_full_simp_tac(srw_ss())[]
          )
        )
        >- (
          irule oracle_tie_ffi_next
          \\ qpat_assum `next_interference (shift_interfer l' mc_conf) _ _ = _`
               (irule_at Any)
          \\ simp[]
          \\ first_assum ACCEPT_TAC
        )
      )
     \\ rpt strip_tac
     THEN1 (full_simp_tac(srw_ss())[encoder_correct_def,shift_interfer_def]
            \\ metis_tac [])
     >- (
       unabbrev_all_tac
       \\ imp_res_tac bytes_in_mem_asm_write_bytearray
       \\ full_simp_tac(srw_ss())[state_rel_def,shift_interfer_def,
              asm_def,jump_to_offset_def,
              asmSemTheory.upd_pc_def] \\ rev_full_simp_tac(srw_ss())[]
       \\ rewrite_tac [GSYM word_add_n2w,GSYM word_sub_def,WORD_SUB_PLUS,
             WORD_ADD_SUB] \\ full_simp_tac(srw_ss())[get_pc_value_def]
       \\ full_simp_tac bool_ss [GSYM word_add_n2w,GSYM word_sub_def,WORD_SUB_PLUS,
             WORD_ADD_SUB] \\ full_simp_tac(srw_ss())[get_pc_value_def]
       \\ `interference_ok (shift_seq l' mc_conf.next_interfer)
             (mc_conf.target.proj t1.mem_domain)` by
                (full_simp_tac(srw_ss())[interference_ok_def,shift_seq_def]
                 \\ NO_TAC) \\ full_simp_tac(srw_ss())[]
       \\ `p + n2w (pos_val new_pc 0 code2) = t1.regs s1.link_reg` by
        (Q.PAT_X_ASSUM `!r. word_loc_val p labs (s1.regs r) = SOME (t1.regs r)`
            (Q.SPEC_THEN `s1.link_reg`mp_tac)
         \\ full_simp_tac(srw_ss())[word_loc_val_def]
         \\ Cases_on `lab_lookup n1 n2 labs` \\ full_simp_tac(srw_ss())[]
         \\ ONCE_REWRITE_TAC [EQ_SYM_EQ] \\ full_simp_tac(srw_ss())[]
         \\ res_tac \\ full_simp_tac(srw_ss())[]) \\ full_simp_tac(srw_ss())[]
       \\ `w2n c2 = LENGTH new_bytes` by
        (imp_res_tac read_bytearray_LENGTH
         \\ imp_res_tac evaluatePropsTheory.call_FFI_LENGTH \\ full_simp_tac(srw_ss())[])
       \\ qmatch_goalsub_abbrev_tac`mc_conf.ffi_interfer _ (index,_,_)`
       \\ `index < i` by (
         imp_res_tac mmio_pcs_min_index_is_SOME>>gvs[]>>
         simp[get_ffi_index_def,backendPropsTheory.the_eqn] >>
        imp_res_tac find_index_MEM >>
         first_x_assum $ qspec_then `0` assume_tac >>fs[]>>
         Cases_on ‘i' < i’>>fs[NOT_LESS]>>
         first_x_assum $ qspec_then `i'` assume_tac >>gvs[]
       )
       \\ `index < LENGTH mc_conf.ffi_names` by (
         drule mmio_pcs_min_index_is_SOME >> gvs[]
         )
       \\ qunabbrev_tac`index`
       \\ conj_tac >- (
         `read_ffi_bytearrays mc_conf ms2 = (SOME x, SOME x')` by
            full_simp_tac(srw_ss())[read_ffi_bytearrays_def,read_ffi_bytearray_def]
         \\ qspecl_then [`mc_conf`,`ms1`,`s1`,`ms2`,`l'`,
                         `get_ffi_index (TAKE i mc_conf.ffi_names) (ExtCall s)`,`s`,
                         `x`,`x'`,`new_ffi`,`new_bytes`,`t1`] mp_tac
              oracle_tie_ExtCall_residues
         \\ impl_tac
         >- (
           qpat_assum `mc_conf.target.get_pc ms2 = _` $ rewrite_tac o single
           \\ rpt conj_tac
           >- first_assum ACCEPT_TAC
           >- (gen_tac
               \\ qpat_x_assum `!k. _ /\ _ /\ _ /\ _` (qspec_then `k` strip_assume_tac)
               \\ first_assum ACCEPT_TAC)
           >- (qpat_x_assum `mc_conf.prog_addresses = _` $ rewrite_tac o single
               \\ rewrite_tac[pred_setTheory.IN_DIFF]
               \\ qpat_x_assum `p + -n2w _ NOTIN t1.mem_domain` $ rewrite_tac o single)
           >- first_assum ACCEPT_TAC
           >- first_assum ACCEPT_TAC
           >- first_assum ACCEPT_TAC
           >- first_assum ACCEPT_TAC
           >- (qpat_x_assum `!index. if _ then _ else _`
                 (qspec_then `get_ffi_index (TAKE i mc_conf.ffi_names) (ExtCall s)` mp_tac)
               \\ qpat_x_assum `get_ffi_index (TAKE i mc_conf.ffi_names) (ExtCall s) < i` mp_tac
               \\ rw[])
           >- first_assum ACCEPT_TAC
           \\ first_assum ACCEPT_TAC
         )
         >- (
           strip_tac
           \\ pop_assum $ rewrite_tac o single
           \\ pop_assum $ rewrite_tac o single
           \\ qpat_x_assum `!ms2' k index new_bytes' t1' bytes' bytes2 st new_st. _`
                (qspecl_then [`ms2`,`0`,
                              `get_ffi_index (TAKE i mc_conf.ffi_names) (ExtCall s)`,
                              `new_bytes`,`t1`,`x`,`x'`,`s1.ffi`,`new_ffi`] mp_tac)
           \\ impl_tac
           >- (
             rpt conj_tac
             >- first_assum ACCEPT_TAC
             >- first_assum ACCEPT_TAC
             >- MATCH_ACCEPT_TAC relationTheory.RTC_REFL
             >- (qpat_x_assum `mc_conf.ffi_names❲_❳ = ExtCall s` $ rewrite_tac o single
                 \\ first_assum ACCEPT_TAC)
             >- rewrite_tac[]
             >- (qpat_x_assum `!k. _ /\ _ /\ _ /\ _` (qspec_then `0` strip_assume_tac)
                 \\ first_assum ACCEPT_TAC)
             \\ `aligned mc_conf.target.config.code_alignment p` by
                  fs [alignmentTheory.aligned_bitwise_and]
             \\ qpat_x_assum `_ = t1.regs s1.link_reg` (fn th => rewrite_tac [GSYM th])
             \\ simp [ONCE_REWRITE_RULE [WORD_ADD_COMM] alignmentTheory.aligned_add_sub]
             \\ drule all_enc_ok_aligned_pos_val \\ simp []
             \\ disch_then (qspec_then `new_pc` mp_tac)
             \\ impl_tac >- metis_tac[has_odd_inst_alignment]
             \\ rw[]
           )
           >- (
             qpat_x_assum `t1.regs s1.ptr2_reg = c2'` (fn th => rewrite_tac[GSYM th])
             \\ qpat_x_assum `new_pc = x''` (fn th => rewrite_tac[GSYM th])
             \\ qpat_x_assum `p + n2w (pos_val new_pc 0 code2) = t1.regs s1.link_reg`
                  $ rewrite_tac o single
             \\ rewrite_tac[LET_THM]
             \\ BETA_TAC
             \\ disch_then ACCEPT_TAC
           )
         )
       )
       \\ conj_tac >- (
         rpt gen_tac \\ strip_tac
         \\ qpat_x_assum `!ms2'' k' index' new_bytes'' t1'' bytes'' bytes2' st' new_st'. _`
              (qspecl_then [`ms2'`,`k+1`,`index`,`new_bytes'`,`t1'`,`bytes'`,`bytes2`,
                            `st`,`new_st`] mp_tac)
         \\ impl_tac
         >- (
           rpt conj_tac
           >- first_assum ACCEPT_TAC
           >- first_assum ACCEPT_TAC
           >- (once_rewrite_tac[RTC_CASES1]
               \\ disj2_tac
               \\ qexists_tac `new_ffi`
               \\ conj_tac
               >- (rewrite_tac[evaluatePropsTheory.call_FFI_rel_def]
                   \\ goal_assum (first_assum o mp_then Any mp_tac))
               \\ first_assum ACCEPT_TAC)
           \\ first_assum ACCEPT_TAC
         )
         >- (
           rewrite_tac[shift_seq_def, LET_THM]
           \\ BETA_TAC
           \\ disch_then ACCEPT_TAC
         )
       )
       \\ conj_tac THEN1 metis_tac[]
       \\ conj_tac THEN1
        (Cases_on `s1.io_regs 0 (ExtCall s) r`
         \\ full_simp_tac(srw_ss())[get_reg_value_def,word_loc_val_def])
       \\ conj_tac THEN1
        (rpt strip_tac \\ qpat_x_assum `!a.
            byte_align a IN s1.mem_domain ==> bbb` (MP_TAC o Q.SPEC `a`)
         \\ full_simp_tac(srw_ss())[] \\ REPEAT STRIP_TAC
         \\ match_mp_tac (SIMP_RULE std_ss [] (Q.INST [`x` |-> `x'`] CallFFI_bytearray_lemma))
         \\ full_simp_tac(srw_ss())[])
       \\ rw[]
       >- (
         match_mp_tac (MP_CANON (Q.INST [`x`|->`x'`] bytes_in_mem_asm_write_bytearray))
         \\ simp[] \\ fs[])
       >- (
         match_mp_tac (MP_CANON (Q.INST [`x`|->`x'`] bytes_in_mem_asm_write_bytearray))
         \\ simp[] \\ fs[])
       >- (
           fs[share_mem_state_rel_def] >>
           gvs[]>>
           rpt gen_tac>>strip_tac>>fs[]>>
           gvs[IMP_CONJ_THM,AND_IMP_INTRO,shift_seq_def] >>
           first_assum $ irule_at Any>>
           fs[]>>
           irule $ cj 2 RTC_RULES >>
           qexists `new_ffi` >>
           gvs[evaluatePropsTheory.call_FFI_rel_def] >>
           metis_tac[]
       )
       >- fs[share_mem_domain_code_rel_def]
     ))
  )
  \\ ih_extras []
  \\ qpat_x_assum `no_install_prefix _ _ _ _` (assume_tac o SIMP_RULE (srw_ss()) [])
  \\ dbg "FFI_RETURN"
  \\ sg `!n. targetSem$evaluate (shift_interfer l' mc_conf) s1.ffi (SUC n) ms2 =
              targetSem$evaluate (shift_interfer l' mc_conf with ffi_interfer := shift_seq 1 mc_conf.ffi_interfer) new_ffi n
                (mc_conf.ffi_interfer 0 (get_ffi_index mc_conf.ffi_names (ExtCall s),new_bytes,ms2))`
  >- (gen_tac
      \\ CONV_TAC (LAND_CONV (ONCE_REWRITE_CONV [targetSemTheory.evaluate_def]))
  \\ full_simp_tac(srw_ss())[shift_interfer_def]
  \\ full_simp_tac(srw_ss())[AC ADD_COMM ADD_ASSOC,AC MULT_COMM MULT_ASSOC]
  \\ rev_full_simp_tac(srw_ss())[LET_DEF]
  \\ rewrite_tac[read_ffi_bytearrays_def, read_ffi_bytearray_def]
      \\ dbg "FFI_STEP"
      \\ TOP_CASE_TAC>>fs[]
      \\ TRY (TOP_CASE_TAC>>fs[])
      \\ TRY (TOP_CASE_TAC>>fs[])
      >- (pairarg_tac>>fs[apply_oracle_def])>>
  qabbrev_tac ‘j = get_ffi_index ffi_names (ExtCall s)’>>
  fs[state_rel_def]>>
  drule mmio_pcs_min_index_is_SOME>>
  strip_tac>>fs[]>>
  last_x_assum $ qspec_then ‘j’ assume_tac>>fs[]>>
  Cases_on ‘j < i’>>fs[NOT_LESS]>>
  drule find_index_LESS_LENGTH>>strip_tac>>fs[]>>
  first_x_assum $ qspec_then ‘j’ assume_tac>>gvs[])
  \\ seg_split
  \\ qpat_x_assum `!n. targetSem$evaluate _ _ (SUC n) _ = _` (fn th => mp_tac (MATCH_MP step_nip th))
  \\ (impl_tac >- shift_tac)
  \\ (impl_tac >- shift_tac)
  \\ (impl_tac >- shift_tac)
  \\ disch_then (qspec_then `s1.clock - 1` mp_tac)
  \\ (impl_tac >- first_assum ACCEPT_TAC)
  \\ strip_tac
  \\ `no_install_prefix (shift_interfer l' mc_conf) s1.ffi (s1.clock - 1) ms2` by
       (irule no_install_prefix_mono \\ qexists_tac `SUC (s1.clock - 1)` \\ simp[])
  \\ nip_tail
QED
val _ = pr "CASE_PROVED CallFFI";

Resume compile_no_install_prefix[Install]:
  say "Install"
  \\ qpat_x_assum `lab_step_closed _` (strip_assume_tac o REWRITE_RULE [lab_step_closed_def])
  \\ qpat_x_assum `!s i bs n. Inv s ==> _` drule
  \\ simp[]
QED
val _ = pr "CASE_PROVED Install";

Resume compile_no_install_prefix[Halt]:
(* Halt *)
  say "Halt"
  \\ srw_tac[][]
  \\ qmatch_assum_rename_tac `asm_fetch s1 = SOME (LabAsm Halt l1 l2 l3)`
  \\ qmatch_assum_rename_tac `asm_fetch s1 = SOME (LabAsm Halt l bytes n)`
  \\ qabbrev_tac `ffi_names = TAKE (THE (mmio_pcs_min_index mc_conf.ffi_names)) mc_conf.ffi_names`
  \\ mp_tac IMP_bytes_in_memory_Halt \\ full_simp_tac(srw_ss())[]
  \\ match_mp_tac IMP_IMP \\ strip_tac
  THEN1 (full_simp_tac(srw_ss())[state_rel_def]
         \\ imp_res_tac bytes_in_mem_IMP \\ full_simp_tac(srw_ss())[])
  \\ rpt strip_tac \\ pop_assum mp_tac
  \\ qpat_abbrev_tac `jj = asm$Jump lll` \\ rpt strip_tac
  \\ (Q.ISPECL_THEN [`mc_conf`,`t1`,`ms1`,`s1.ffi`,`jj`]mp_tac
       asm_step_IMP_evaluate_step_find_next) \\ full_simp_tac(srw_ss())[]
  \\ MATCH_MP_TAC IMP_IMP2 \\ STRIP_TAC THEN1
   (full_simp_tac(srw_ss())[state_rel_def,asm_def,LET_DEF]
    \\ full_simp_tac(srw_ss())[asm_step_def,asm_def,LET_DEF]
    \\ imp_res_tac bytes_in_mem_IMP
    \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,
          asmSemTheory.upd_pc_def]
    \\ rev_full_simp_tac(srw_ss())[] \\ unabbrev_all_tac
    \\ full_simp_tac(srw_ss())[asmSemTheory.jump_to_offset_def,
          asmSemTheory.upd_pc_def,asm_def]
    \\ fs[asm_fetch_def]
    \\ drule_all $ GEN_ALL IMP_bytes_in_memory
    \\ strip_tac
    \\ fs[]
    \\ drule_all $ GEN_ALL IMP_ffi_entry_pcs_disjoint_LabAsm
    \\ ho_match_mp_tac (
      PURE_REWRITE_RULE [satTheory.AND_IMP] o
      PURE_REWRITE_RULE [Once CONJ_SYM] $
      GEN_ALL ffi_entry_pcs_disjoint_LENGTH_shorter )
    \\ Cases_on `j`
    \\ gvs[line_similar_def,line_ok_def,line_length_def,line_bytes_def]
    \\ gvs[enc_with_nop_thm,LENGTH_APPEND]
  )
  \\ rpt strip_tac
  \\ unabbrev_all_tac \\ full_simp_tac(srw_ss())[asm_def]
  \\ FIRST_ASSUM (Q.SPEC_THEN `s1.clock`mp_tac) \\ srw_tac[][]
  \\ `mc_conf.target.get_pc ms2 = mc_conf.halt_pc` by
   (full_simp_tac(srw_ss())
      [encoder_correct_def,target_ok_def,target_state_rel_def]
    \\ res_tac
    \\ full_simp_tac(srw_ss())[]
    \\ full_simp_tac(srw_ss())[jump_to_offset_def,asmSemTheory.upd_pc_def]
    \\ full_simp_tac(srw_ss())[state_rel_def]
    \\ rewrite_tac [GSYM word_add_n2w,GSYM word_sub_def,WORD_SUB_PLUS,
         WORD_ADD_SUB] \\ full_simp_tac(srw_ss())[])
  \\ seg_split
  \\ `no_install_prefix (shift_interfer l' mc_conf) s1.ffi (s1.clock - 1) ms2` by
       (irule no_install_prefix_halt \\ fs[halt_ctx_def, shift_interfer_def])
  \\ nip_tail
QED
val _ = pr "CASE_PROVED Halt";

Finalise compile_no_install_prefix;

(* The published conclusion and the prefix property together. The first conjunct is the published theorem. *)
Theorem compile_correct_no_install_prefix:
  lab_step_closed Inv ==>
  !^s1 res (mc_conf: ('a,'state,'b) machine_config) s2 code2 labs t1 ms1.
     oracle_tie mc_conf ms1 s1 /\
     (evaluate s1 = (res,s2)) /\ (res <> Error) /\
     encoder_correct mc_conf.target /\
     state_rel (mc_conf,code2,labs,p) s1 t1 ms1 /\
     Inv s1 /\ code_layout_ok (:'a) code2 ==>
     (?k t2 ms2. evaluate mc_conf s1.ffi (s1.clock + k) ms1 = (res,ms2,s2.ffi)) /\
     no_install_prefix mc_conf s1.ffi s1.clock ms1
Proof
  rpt strip_tac
  >- (mp_tac (Q.SPECL [`s1`,`res`,`mc_conf`,`s2`,`code2`,`labs`,`t1`,`ms1`] lab_to_targetProofTheory.compile_correct)
      \\ simp[])
  \\ qpat_x_assum `lab_step_closed _` (fn c => mp_tac (MATCH_MP compile_no_install_prefix c))
  \\ disch_then (fn th => mp_tac (SPEC_ALL th))
  \\ simp[]
QED

(* All-clock form: a conditional target-level exclusion for the run from ms1. *)
Theorem target_install_exclusion_conditional:
  lab_step_closed Inv /\
  (!k. Inv (^s1 with clock := k)) /\
  (!k. FST (labSem$evaluate (s1 with clock := k)) <> Error) /\
  oracle_tie (mc_conf: ('a,'state,'b) machine_config) ms1 s1 /\ encoder_correct mc_conf.target /\
  state_rel (mc_conf,code2,labs,p) s1 t1 ms1 /\ code_layout_ok (:'a) code2 ==>
  !n. no_install_prefix mc_conf s1.ffi n ms1
Proof
  rpt strip_tac
  \\ qpat_x_assum `lab_step_closed _` (fn c => assume_tac (MATCH_MP compile_no_install_prefix c))
  \\ first_x_assum (qspecl_then [`s1 with clock := n`,`FST (evaluate (s1 with clock := n))`,`mc_conf`,
        `SND (evaluate (s1 with clock := n))`,`code2`,`labs`,`t1`,`ms1`] mp_tac)
  \\ simp[]
  \\ disch_then irule
  \\ conj_tac >- (irule oracle_tie_clock \\ first_assum ACCEPT_TAC)
  \\ irule state_rel_clock \\ first_assum ACCEPT_TAC
QED

val _ = List.app (fn n => let val th = DB.fetch "forge_simReplay" n in tags n th; pr ("CHECKED " ^ n ^ "\n" ^ thm_to_string th) end)
  ["lab_step_evaluate", "seg_finish", "state_rel_ctx", "step_nip", "final_nip", "compile_no_install_prefix", "compile_correct_no_install_prefix", "target_install_exclusion_conditional"];
val _ = List.app (fn n => pr ("DEFINITION " ^ n ^ "\n" ^ thm_to_string (DB.fetch "forge_simReplay" n)))
  ["lab_step_closed_def", "nip_ctx_def", "halt_ctx_def"];
(* Fidelity: the premises before the two added ones are the published premises, and the first conclusion is the published one. *)
val _ = let
    val pub = concl lab_to_targetProofTheory.compile_correct
    val (pv, pb) = strip_forall pub; val (pa, pc) = dest_imp pb
    val mine = snd (dest_imp (concl (DB.fetch "forge_simReplay" "compile_correct_no_install_prefix")))
    val (mv, mb) = strip_forall mine; val (ma, mc) = dest_imp mb
    val mcs = strip_conj ma
    val back = list_mk_forall (mv, mk_imp (list_mk_conj (List.take (mcs, length mcs - 2)), hd (strip_conj mc)))
  in if aconv back pub then pr "FIDELITY published compile_correct recovered by removing the two added premises and the added conclusion"
     else raise Fail "Fidelity check failed" end;
val _ = export_theory ();
val _ = pr "REPLAY_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
