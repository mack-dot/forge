(* Forge additions. No published statement is changed. *)
Definition lab_guard_def:
  lab_guard (x:behaviour set) Q = if Q then x else x UNION {Fail}
End

(* The lab-level facts that the published proof establishes on its way. *)
Definition lab_facts_def:
  lab_facts asm_conf c prog bytes c' (mc:('a,'b,'c) machine_config) (ffi:'ffi ffi_state) ms cbspace <=>
    ?t m dm sdm coracle tl.
      tl = backend$to_lab asm_conf c prog /\
      good_init_state mc ms bytes cbspace t m dm sdm /\
      lab_to_targetProof$compiler_oracle_ok coracle c'.lab_conf.labels (LENGTH bytes) asm_conf mc.ffi_names /\
      lab_to_target$compile asm_conf (FST (SND tl)).lab_conf (SND (SND tl)) = SOME (bytes, c'.lab_conf) /\
      labSem$semantics
        (lab_to_targetProof$make_init mc ffi t m dm sdm ms (SND (SND tl))
           (lab_to_target$compile asm_conf) (mc.target.get_pc ms + n2w (LENGTH bytes)) cbspace coracle) <> Fail
End

Theorem lab_guard_elim:
  lab_guard x Q SUBSET extend_with_resource_limit' b y /\ Fail NOTIN y ==> Q /\ x SUBSET extend_with_resource_limit' b y
Proof
  Cases_on `Q` \\ simp [lab_guard_def]
  \\ Cases_on `b`
  \\ simp [extend_with_resource_limit'_def, extend_with_resource_limit_def, SUBSET_DEF]
  \\ metis_tac []
QED

Theorem lab_guard_true:
  Q ==> lab_guard x Q = x
Proof
  rw [lab_guard_def]
QED

Theorem lab_nonfail_unaligned:
  good_dimindex (:'a) /\
  labSem$semantics (lab_to_targetProof$make_init (mc:('a,'b,'c) machine_config) (ffi:'ffi ffi_state) t m
     (dm INTER byte_aligned) (sdm INTER byte_aligned) ms lcode cmp cbpos cbspace coracle) <> Fail ==>
  labSem$semantics (lab_to_targetProof$make_init mc ffi t m dm sdm ms lcode cmp cbpos cbspace coracle) <> Fail
Proof
  strip_tac
  \\ qabbrev_tac `st0 = lab_to_targetProof$make_init mc ffi t m dm sdm ms lcode cmp cbpos cbspace coracle`
  \\ `lab_to_targetProof$make_init mc ffi t m (dm INTER byte_aligned) (sdm INTER byte_aligned) ms lcode cmp cbpos cbspace coracle =
      align_dm (align_sdm st0)` by
        simp [Abbr `st0`, labPropsTheory.align_dm_def, labPropsTheory.align_sdm_def, lab_to_targetProofTheory.make_init_def]
  \\ `implements' T {labSem$semantics (align_sdm st0)} {labSem$semantics (align_dm (align_sdm st0))}` by
       (irule labPropsTheory.implements_align_dm \\ simp [])
  \\ `implements' T {labSem$semantics st0} {labSem$semantics (align_sdm st0)}` by
       (irule labPropsTheory.implements_align_sdm \\ simp [])
  \\ rpt (qpat_x_assum `implements' _ _ _` mp_tac)
  \\ simp [implements'_def, extend_with_resource_limit'_def]
  \\ metis_tac []
QED

(* Marker kept through the published proof: the word program of the published proof is that of to_word. *)
Definition lab_keep_word_def:
  lab_keep_word asm_conf c prog p5 <=> SND (backend$to_word asm_conf c prog) = p5
End

Theorem to_word_confs:
  backend$to_word asm_conf c prog = (c1,p5) ==>
  c1.stack_conf = c.stack_conf /\ c1.data_conf = c.data_conf /\ c1.lab_conf = c.lab_conf
Proof
  rw [to_word_def, to_data_def, to_bvi_def, to_bvl_def, to_clos_def, to_flat_def]
  \\ rpt (pairarg_tac \\ fs []) \\ rveq \\ fs []
QED
val _ = pr ("LEMMA lab_nonfail_unaligned\n" ^ thm_to_string lab_nonfail_unaligned);
