(* published line 11 *)
val _ = temp_delsimps ["NORMEQ_CONV"]

(* published line 12 *)
val _ = diminish_srw_ss ["ABBREV"]

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

(* published line 1338 *)
Theorem UPDATE_COND_PUSH[local]:
  ∀cs rc ar (regs:num -> 'a word) g k v.
    (λa. if MEM a cs ∨ ¬(a < rc) ∨ MEM a ar then regs a else g a)⦇ k ↦ v ⦈ =
    (λa. if MEM a cs ∨ a = k ∨ ¬(a < rc) ∨ MEM a ar
         then (if a = k then v else regs a) else g a)
Proof
  rpt gen_tac \\ once_rewrite_tac[FUN_EQ_THM]
  \\ qx_gen_tac `aa` \\ rewrite_tac[APPLY_UPDATE_THM] \\ BETA_TAC
  \\ Cases_on `aa = k` \\ simp[]
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

(* published line 8007 *)
Theorem i2w_sub_nat[local,simp]:
  (i2w (&m - &n):'a word) = n2w m - n2w n
Proof
  rw [integerTheory.int_sub,GSYM integer_wordTheory.word_i2w_add,
      GSYM integer_wordTheory.MULT_MINUS_ONE,integer_wordTheory.i2w_pos]
  \\ metis_tac [WORD_NEG_MUL]
QED

(* published line 8015 *)
Theorem i2w_neg_nat[local,simp]:
  (i2w (-&n):'a word) = -n2w n
Proof
  rw [GSYM integer_wordTheory.MULT_MINUS_ONE,integer_wordTheory.i2w_pos]
  \\ metis_tac [WORD_NEG_MUL]
QED

(* published line 10173 *)
Theorem find_index_MAP_w2n[local]:
  !l (x:'a word) n. find_index (w2n x) (MAP w2n l) n = find_index x l n
Proof
  Induct >> simp[find_index_def] >> rw[] >> fs[w2n_11]
QED

(* This is set up for the very first compile call *)

(* published line 10612 *)
Theorem all_enc_ok_pre_filter_skip[local]:
  ∀code c.
  all_enc_ok_pre c code ⇒
  all_enc_ok_pre c (filter_skip code)
Proof
  Induct>>TRY(Cases)>>fs[lab_filterTheory.filter_skip_def]>>rw[]>>
  Induct_on`l`>>fs[]>>rw[]
QED
