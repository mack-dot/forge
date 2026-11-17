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
