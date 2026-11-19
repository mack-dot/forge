(* Worker Y1. FALLBACK TACTIC VARIANTS for routeA-L1.sml (X7, sha256 9ddf6746...8830). DRAFT: NOT RUN.
   These are ALTERNATIVES, to paste in ONLY after attempt 1 prints LEMMA_FAILED for the named lemma.
   Each one is TACTIC-ONLY: the goal term of every lemma stays exactly as in routeA-L1.sml. No statement changes.
   No cheat, no mk_thm. Names (on_def, contract_at_def, tot_def, AB, TOT_T, TOT_F, L1, N2a2, ...) are the ML
   values of routeA-L1.sml. Static review found NO concrete defect; so there is no routeA-L1-v2.sml. *)

(* ---- ALT-L1-a (if Cases_on gives the cases in another order or another form). ASM_CASES_TAC is what Cases_on
        calls here (BasicProvers.sml 313/318: bool term not free in goal -> Alien -> ASM_CASES_TAC). ---- *)
val L1_alt_a =
  (rpt gen_tac >> rewrite_tac [on_def, contract_at_def] >> disch_then (fn ON =>
     rpt gen_tac >> strip_tac >> ASM_CASES_TAC ``Vok (index:num) (new_bytes:word8 list) (ms2:arm8_state) : bool``
     >- (first_assum (fn th => rewrite_tac [MATCH_MP TOT_T th]) >>
         mp_tac (Q.SPECL [`k`, `index`, `new_bytes`, `ms2`, `t1`, `bytes`, `bytes2`] ON) >> asm_rewrite_tac [])
     >- (first_assum (fn th => rewrite_tac [MATCH_MP TOT_F th]) >>
         mp_tac (Q.SPECL [`k`, `index`, `new_bytes`, `ms2`, `t1`, `bytes`, `bytes2`]
                   (REWRITE_RULE [contract_at_def] (Q.SPECL [`b`, `dm`] AB))) >> asm_rewrite_tac [])));

(* ---- ALT-L1-b (no MATCH_MP, no named case split: unfold tot and split the conditional). ---- *)
val L1_alt_b =
  (rpt gen_tac >> rewrite_tac [on_def, contract_at_def] >> disch_then (fn ON =>
     rpt gen_tac >> strip_tac >>
     `!g. refund_ffi_tot Vok g k (index,new_bytes,ms2) =
          if Vok index new_bytes ms2 then g k (index,new_bytes,ms2) else refund_abs_ffi k (index,new_bytes,ms2)`
        by simp [tot_def] >>
     pop_assum (fn th => rewrite_tac [th]) >> IF_CASES_TAC
     >- (mp_tac (Q.SPECL [`k`, `index`, `new_bytes`, `ms2`, `t1`, `bytes`, `bytes2`] ON) >> asm_rewrite_tac [])
     >- (mp_tac (Q.SPECL [`k`, `index`, `new_bytes`, `ms2`, `t1`, `bytes`, `bytes2`]
                   (REWRITE_RULE [contract_at_def] (Q.SPECL [`b`, `dm`] AB))) >> asm_rewrite_tac [])));

(* ---- ALT-close (for any branch above where asm_rewrite_tac [] leaves "C ==> C" with a changed C):
        replace the final asm_rewrite_tac [] by:  (impl_tac >- (rpt conj_tac >> first_assum ACCEPT_TAC) >> simp [])
        or by:  asm_simp_tac bool_ss []  ---- *)

(* ---- ALT-S1 / ALT-N1-impl / ALT-N1b (if rewrite_tac + BETA_TAC + rewrite_tac [] does not close): simp beta-reduces. ---- *)
val S1_alt  = (rpt gen_tac >> simp [on_def, contract_at_def]);
(* N1 impl_tac branch:            (simp [on_def])
   N1b after match_mp_tac L1:     (simp [on_def]) *)

(* ---- ALT-SHIFT ---- *)
val SHIFT_alt_a = (rw [FUN_EQ_THM, shift_seq_def, tot_def, abs_def]);
val SHIFT_alt_b = (simp [FUN_EQ_THM, shift_seq_def] >> rpt gen_tac >> simp [tot_def, abs_def] >> rw []);

(* ---- ALT-L1C (simp does the record field selections; L1 used as a conditional rewrite; assumption discharges it) ---- *)
val L1C_alt = (strip_tac >> asm_simp_tac (srw_ss()) [ok_sl_def, L1]);

(* ---- ALT-N2b-hyps (if EVAL_TAC does not close the index-2 hypotheses): prove the stub address first. ---- *)
val stub2 = prove (``0x1000040D0w - n2w ((3 + 2) * 16) = (0x100004080w:word64)``, EVAL_TAC);
(* impl_tac branch:
   (simp [msw_def, read_bytearray_def, target_state_rel_def, tg, arm8_ok_def, stub2] >>
    simp [arm8_target_def, arm8_config_def] >> rpt conj_tac >> EVAL_TAC)
   the second branch, if `simp []` does not reduce the record selection:
   (strip_tac >> asm_rewrite_tac [] >> EVAL_TAC) *)

(* ---- ALT-N2d (use the proved rejection N2a2 instead of re-deriving it; EVAL decides the word literal) ---- *)
val N2d_alt = (gen_tac >> strip_tac >> drule N2b >> simp [abort_def, N2a2] >> EVAL_TAC);

(* ---- ALT-N2a2 ---- *)
val N2a2_alt = (simp [vclose_def, msw_def] >> EVAL_TAC);
