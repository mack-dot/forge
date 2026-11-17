(* U389: general lemmas for the loader-memory clauses. No program-specific fact. 64-bit, little-endian. *)
open preamble alignmentTheory wordsTheory wordsLib set_sepTheory miscTheory byteTheory arm8_stepTheory stack_removeProofTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_loaderMemLemmas";
val failed = ref ([] : string list);
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th); th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
val bim_el = thm "bytes_in_memory_univ_EL"
  ``!bs a (m:'a word -> word8). bytes_in_memory a bs m UNIV <=> !i. i < LENGTH bs ==> m (a + n2w i) = EL i bs``
  (Induct >> simp [bytes_in_memory_def] >> rpt gen_tac >> eq_tac >> strip_tac
   >- (Cases >> simp [] >> strip_tac >> first_x_assum drule >> simp [n2w_SUC] >> show_tac "EL1")
   >- (conj_tac >- (first_x_assum (qspec_then `0` mp_tac) >> simp []) >>
       rpt strip_tac >> first_x_assum (qspec_then `SUC i` mp_tac) >> simp [n2w_SUC] >> show_tac "EL2"));
val bim_frame = thm "bytes_in_memory_univ_frame"
  ``!bs a (m:'a word -> word8) m'. bytes_in_memory a bs m UNIV /\ (!i. i < LENGTH bs ==> m' (a + n2w i) = m (a + n2w i)) ==>
      bytes_in_memory a bs m' UNIV``
  (simp [bim_el]);
val suc_all = thm "forall_lt_SUC_word"
  ``!P (a:'a word) n. (!i. i < SUC n ==> P (a + n2w i)) <=> P a /\ !i. i < n ==> P (a + 1w + n2w i)``
  (rpt gen_tac >> eq_tac >> rpt strip_tac
   >- (first_x_assum (qspec_then `0` mp_tac) >> simp [])
   >- (first_x_assum (qspec_then `SUC i` mp_tac) >> simp [n2w_SUC] >> metis_tac [WORD_ADD_ASSOC, WORD_ADD_COMM])
   >- (Cases_on `i` >> fs [n2w_SUC] >> metis_tac [WORD_ADD_ASSOC, WORD_ADD_COMM]));
val bim_mem = thm "bytes_in_mem_iff"
  ``!bs a (m:'a word -> word8) md k. bytes_in_mem a bs m md k <=>
      bytes_in_memory a bs m UNIV /\ !i. i < LENGTH bs ==> a + n2w i IN md /\ a + n2w i NOTIN k``
  (Induct >> simp [bytes_in_mem_def, bytes_in_memory_def] >> rpt gen_tac >>
   qspecl_then [`\x. x IN md /\ x NOTIN k`, `a`, `LENGTH bs`] (assume_tac o SIMP_RULE (srw_ss()) []) suc_all >>
   asm_rewrite_tac [] >> metis_tac []);
val rba = thm "read_bytearray_from_EL"
  ``!bs a (f:'a word -> word8 option). (!i. i < LENGTH bs ==> f (a + n2w i) = SOME (EL i bs)) ==>
      read_bytearray a (LENGTH bs) f = SOME bs``
  (Induct >> simp [read_bytearray_def] >> rpt strip_tac >>
   first_assum (qspec_then `0` mp_tac) >> simp_tac (srw_ss()) [] >> strip_tac >> simp [] >>
   first_x_assum (qspecl_then [`a + 1w`, `f`] mp_tac) >> impl_tac
   >- (rpt strip_tac >> first_x_assum (qspec_then `SUC i` mp_tac) >> simp [n2w_SUC] >> show_tac "RBA") >> simp []);
(* Little-endian bytes of a 64-bit word. *)
val dword_bytes_def = Define `dword_bytes (w:word64) =
  [w2w w; w2w (w >>> 8); w2w (w >>> 16); w2w (w >>> 24); w2w (w >>> 32); w2w (w >>> 40); w2w (w >>> 48); w2w (w >>> 56)] : word8 list`;
val dword_len = thm "LENGTH_dword_bytes" ``LENGTH (dword_bytes w) = 8`` (simp [dword_bytes_def]);
val join = thm "mem_dword_join"
  ``!(m:word64 -> word8) a w. m a = w2w w /\ m (a + 1w) = w2w (w >>> 8) /\ m (a + 2w) = w2w (w >>> 16) /\ m (a + 3w) = w2w (w >>> 24) /\
      m (a + 4w) = w2w (w >>> 32) /\ m (a + 5w) = w2w (w >>> 40) /\ m (a + 6w) = w2w (w >>> 48) /\ m (a + 7w) = w2w (w >>> 56) ==>
      mem_dword m a = w``
  (rpt strip_tac >> asm_rewrite_tac [mem_dword_def] >> blastLib.BBLAST_TAC);
val dword_mem = thm "dword_bytes_in_memory"
  ``!ws a (m:word64 -> word8). bytes_in_memory a (FLAT (MAP dword_bytes ws)) m UNIV ==>
      !i. i < LENGTH ws ==> mem_dword m (a + n2w (8 * i)) = EL i ws``
  (Induct >> simp [bytes_in_memory_APPEND, dword_len] >> rpt gen_tac >> strip_tac >> Cases
   >- (simp [] >> match_mp_tac join >> fs [dword_bytes_def, bytes_in_memory_def] >> show_tac "DW0")
   >- (simp [] >> strip_tac >> first_x_assum drule >> disch_then drule >> simp [MULT_CLAUSES, GSYM word_add_n2w] >> show_tac "DW1"));
(* Byte memory against the word memory \a. mem_dword m a. *)
val al3 = thm "byte_align_64" ``byte_align (a:word64) = align 3 a`` (simp [byte_align_def] >> EVAL_TAC);
val lo = thm "byte_align_split" ``!a:word64. a = byte_align a + n2w (w2n a MOD 8)``
  (gen_tac >> simp [al3, align_w2n, word_add_n2w] >>
   `8 * (w2n a DIV 8) + w2n a MOD 8 = w2n a` by (mp_tac (Q.SPEC `8` DIVISION) >> simp [] >> disch_then (qspec_then `w2n a` mp_tac) >> simp []) >>
   simp [] >> show_tac "SPLIT");
val bytes8 = thm "mem_dword_bytes"
  ``!(m:word64 -> word8) b. w2w (mem_dword m b) = m b /\ w2w (mem_dword m b >>> 8) = m (b + 1w) /\ w2w (mem_dword m b >>> 16) = m (b + 2w) /\
      w2w (mem_dword m b >>> 24) = m (b + 3w) /\ w2w (mem_dword m b >>> 32) = m (b + 4w) /\ w2w (mem_dword m b >>> 40) = m (b + 5w) /\
      w2w (mem_dword m b >>> 48) = m (b + 6w) /\ w2w (mem_dword m b >>> 56) = m (b + 7w)``
  (rpt gen_tac >> rewrite_tac [mem_dword_def] >>
   map_every (fn (t, v) => SPEC_TAC (t, v)) [(``(m:word64 -> word8) (b + 7w)``, ``b7:word8``), (``(m:word64 -> word8) (b + 6w)``, ``b6:word8``),
     (``(m:word64 -> word8) (b + 5w)``, ``b5:word8``), (``(m:word64 -> word8) (b + 4w)``, ``b4:word8``), (``(m:word64 -> word8) (b + 3w)``, ``b3:word8``),
     (``(m:word64 -> word8) (b + 2w)``, ``b2:word8``), (``(m:word64 -> word8) (b + 1w)``, ``b1:word8``), (``(m:word64 -> word8) b``, ``b0:word8``)] >>
   blastLib.BBLAST_TAC);
val gb = thm "mem_dword_get_byte" ``!(m:word64 -> word8) a. m a = get_byte a (mem_dword m (byte_align a)) F``
  (rpt gen_tac >> simp [get_byte_def, byte_index_def] >>
   qabbrev_tac `b = byte_align a` >> qabbrev_tac `k = w2n a MOD 8` >>
   `a = b + n2w k` by metis_tac [lo] >> `k < 8` by simp [Abbr `k`] >>
   `k = 0 \/ k = 1 \/ k = 2 \/ k = 3 \/ k = 4 \/ k = 5 \/ k = 6 \/ k = 7` by decide_tac >>
   qpat_x_assum `a = _` SUBST1_TAC >> asm_rewrite_tac [] >> simp [bytes8] >> show_tac "GB");
val gb_clause = thm "mem_dword_word_memory_clause"
  ``!(m:word64 -> word8) a. ?w. m a = get_byte a w F /\ (\a. Word (mem_dword m a) : 64 word_loc) (byte_align a) = Word w``
  (rpt gen_tac >> qexists_tac `mem_dword m (byte_align a)` >> simp [GSYM gb]);
(* Separation-logic word lists on a function memory. *)
val gd64 = prove (``good_dimindex (:64)``, simp [good_dimindex_def]);
val biw = prove (``bytes_in_word = 8w:word64``, EVAL_TAC);
val wl_fun2set = thm "word_list_fun2set"
  ``!(xs:'b list) (a:word64) m dm. w2n a + LENGTH xs * 8 < dimword (:64) /\ (!x. x IN dm <=> ?i. i < LENGTH xs /\ x = a + n2w i * 8w) /\
      (!i. i < LENGTH xs ==> m (a + n2w i * 8w) = EL i xs) ==> word_list a xs (fun2set (m, dm))``
  (rpt strip_tac >> mp_tac (Q.SPECL [`xs`, `a`] (INST_TYPE [alpha |-> ``:64``] word_list_seteq)) >>
   impl_tac >- fs [gd64, biw] >> disch_then (fn th => rewrite_tac [th]) >>
   simp [fun2set_def, EXTENSION, MEM_GENLIST, FORALL_PROD, biw] >> show_tac "WL" >> metis_tac [WORD_MULT_COMM]);
val wl_read = thm "word_list_clause_read"
  ``!(xs:'b list) (a:word64) m dm r i. w2n a + LENGTH xs * 8 < dimword (:64) /\ (word_list a xs * r) (fun2set (m, dm)) /\ i < LENGTH xs ==>
      m (a + n2w i * 8w) = EL i xs``
  (rpt strip_tac >> mp_tac (Q.INST [`r1` |-> `emp`, `r2` |-> `r`] (INST_TYPE [alpha |-> ``:64``] word_list_EL_in_memory)) >>
   fs [gd64, biw, SEP_CLAUSES] >> show_tac "WLR" >> metis_tac [WORD_MULT_COMM]);
val wle0 = thm "word_list_exists_0" ``word_list_exists a 0 = emp``
  (simp [word_list_exists_def, FUN_EQ_THM, SEP_EXISTS_THM, cond_STAR, word_list_def] >> show_tac "WLE");
val _ = if null (!failed) then () else raise Fail ("failed lemmas: " ^ String.concatWith " " (rev (!failed)));
val closure = "forge_loaderMemLemmas" :: Theory.ancestry "forge_loaderMemLemmas";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
