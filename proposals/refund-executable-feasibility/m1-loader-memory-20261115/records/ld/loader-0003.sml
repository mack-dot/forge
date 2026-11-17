(* U389: bytes of the linked refund executable against the stored compiled code and bitmaps; loader-memory clauses
   composed with the 27 cml_main steps. Link addresses, slide 0 for the composition. The loader is NOT modelled:
   refund_image_mem is an explicit assumption about memory at entry to cml_main. *)
open preamble backendTheory targetSemTheory targetPropsTheory asmPropsTheory arm8_targetTheory alignmentTheory arm8_stepTheory set_sepTheory
     miscTheory backendProofTheory arm8_configProofTheory forge_refundArm8CompileTheory forge_refundExclusionRealTheory
     forge_refundStartupClauseTheory forge_refundCmlMainStepTheory forge_refundCmlMainFrameTheory forge_refundStartupBridgeTheory
     forge_loaderMemLemmasTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundLoaderMemory";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun named nm tm = can (find_term (fn x => is_const x andalso fst (dest_const x) = nm)) tm;
val code_tm = ``forge_refundArm8Compile$code``; val data_tm = ``forge_refundArm8Compile$data``;
val code_def = DB.fetch "forge_refundArm8Compile" "code_def"; val data_def = DB.fetch "forge_refundArm8Compile" "data_def";
val _ = if aconv (lhs (concl code_def)) code_tm andalso aconv (lhs (concl data_def)) data_tm then () else raise Fail "stored definitions";
(* The stored terms are to_list applications on compute values. Kernel evaluation gives the list literals. *)
val code_def = TRANS code_def (EVAL (rhs (concl code_def))); val data_def = TRANS data_def (EVAL (rhs (concl data_def)));
val _ = (tags "code literal" code_def; tags "data literal" data_def);
val codeL = rhs (concl code_def); val dataL = rhs (concl data_def);
val _ = pr ("STORED_TERMS_EVALUATED code " ^ Int.toString (length (fst (listSyntax.dest_list codeL))) ^ " data " ^ Int.toString (length (fst (listSyntax.dest_list dataL))));
val comp = DB.fetch "forge_refundArm8Compile" "refund_arm8_compiled";
fun len_of c = valOf (List.find (fn th => is_eq (concl th) andalso aconv (lhs (concl th)) ``LENGTH ^c``) (CONJUNCTS comp));
val len_code = len_of code_tm; val len_data = len_of data_tm;
val _ = pr ("STORED " ^ thm_to_string len_code ^ " ; " ^ thm_to_string len_data);
(* ---- 1. The executable file as a HOL constant. The bytes are read here, by ML. ---- *)
val image_path = valOf (OS.Process.getEnv "FORGE_IMAGE");
val bytes = let val i = BinIO.openIn image_path val v = BinIO.inputAll i val _ = BinIO.closeIn i in v end;
val nbytes = Word8Vector.length bytes;
val _ = pr ("IMAGE_PATH " ^ image_path ^ " BYTES " ^ Int.toString nbytes);
val _ = if nbytes = 238776 then () else raise Fail "unexpected file size";
val tab = Vector.tabulate (256, fn n => wordsSyntax.mk_wordii (n, 8));
fun lit get (a, n) = listSyntax.mk_list (List.tabulate (n, fn k => Vector.sub (tab, get (a + k))), ``:word8``);
fun fileb k = Word8.toInt (Word8Vector.sub (bytes, k));
val file_tm = lit fileb (0, nbytes);
val file_def = new_definition ("refund_file_def", ``refund_file = ^file_tm``);
val file_c = lhs (concl file_def);
(* Round trip: the bytes of the stored term are written back; the runner's wrapper compares the SHA256 with the executable. *)
val _ = let val (els, _) = listSyntax.dest_list (rhs (concl (DB.fetch "-" "refund_file_def")))
            val out = BinIO.openOut "roundtrip.bin"
        in List.app (fn t => BinIO.output1 (out, Word8.fromInt (wordsSyntax.uint_of_word t))) els; BinIO.closeOut out;
           pr ("ROUNDTRIP_WRITTEN " ^ Int.toString (length els)) end;
(* ---- 2. Layout: file = P ++ STUB ++ Q ++ code ++ T2 ++ M ++ bitmap bytes ++ E, checked by kernel evaluation of APPEND. ---- *)
val cuts = [(0,16384),(16384,108),(16492,100),(16592,130436),(147028,16812),(163840,16408),(180248,20248),(200496,38280)];
val Dc = ``FLAT (MAP dword_bytes (MAP n2w ^data_tm)) : word8 list``;
val d_eval = (RAND_CONV (RAND_CONV (RAND_CONV (REWR_CONV data_def))) THENC EVAL) Dc;
val _ = pr ("BITMAP_BYTES_EVALUATED " ^ Int.toString (length (fst (listSyntax.dest_list (rhs (concl d_eval))))));
fun mk_layout get whole cs =
  let val [P,S,Q,C,T2,M,D,E] = map (lit get) cs
      val _ = if aconv C codeL then () else raise Fail "code slice differs from the stored code"
      val _ = if aconv D (rhs (concl d_eval)) then () else raise Fail "bitmap slice differs from the stored bitmaps"
      val rhs_c = ``^P ++ (^S ++ (^Q ++ (^code_tm ++ (^T2 ++ (^M ++ (^Dc ++ ^E))))))``
      val r3 = RAND_CONV o RAND_CONV o RAND_CONV
      val unfold = (r3 (LAND_CONV (REWR_CONV code_def)) THENC (r3 o r3) (LAND_CONV (K d_eval))) rhs_c
      val ev = EVAL (rhs (concl unfold))
      val _ = if aconv (rhs (concl ev)) whole then () else raise Fail "evaluated layout differs from the file term"
  in ([P,S,Q,C,T2,M,D,E], TRANS unfold ev) end;
val ([P,STUB,Q,_,T2,M,D,E], lay0) = mk_layout fileb file_tm cuts;
val layout = TRANS file_def (SYM lay0);
val _ = pr "LAYOUT_OK refund_file = P ++ STUB ++ Q ++ code ++ T2 ++ M ++ FLAT (MAP dword_bytes (MAP n2w data)) ++ E";
fun lenth t = EVAL ``LENGTH ^t``;
val [lenP, lenS, lenQ, lenT, lenM] = map lenth [P, STUB, Q, T2, M];
val lenD = TRANS (AP_TERM ``LENGTH : word8 list -> num`` d_eval) (lenth D);
val _ = List.app (fn th => pr ("LEN " ^ term_to_string (rhs (concl th)))) [lenP, lenS, lenQ, len_code, lenT, lenM, lenD];
(* Control at ML level: a changed code byte, a changed bitmap byte and a shifted code offset do not pass the layout check. *)
fun ctl name get cs = let val r = (mk_layout get file_tm cs; "ACCEPTED") handle Fail m => "REJECTED: " ^ m | HOL_ERR _ => "REJECTED: HOL_ERR"
  in if String.isPrefix "REJECTED" r then pr ("CONTROL_OK " ^ name ^ " " ^ r) else raise Fail ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ name) end;
fun flip at k = if k = at then (fileb k + 1) mod 256 else fileb k;
val _ = ctl "changed code byte (file offset 17592)" (flip 17592) cuts;
val _ = ctl "changed bitmap byte (file offset 180248)" (flip 180248) cuts;
val _ = ctl "code offset shifted by 4" fileb [(0,16384),(16384,108),(16492,104),(16596,130436),(147032,16808),(163840,16408),(180248,20248),(200496,38280)];
val _ = ctl "bitmap offset shifted by 8" fileb [(0,16384),(16384,108),(16492,100),(16592,130436),(147028,16812),(163840,16416),(180256,20248),(200504,38272)];
(* List lemmas with variables in place of the large literals. *)
val V = thm "layout_slices"
  ``!f p s q c t mm d e. f = p ++ (s ++ (q ++ (c ++ (t ++ (mm ++ (d ++ e)))))) /\ LENGTH p = 16384 /\ LENGTH s = 108 /\ LENGTH q = 100 /\
      LENGTH c = 130436 /\ LENGTH t = 16812 /\ LENGTH mm = 16408 /\ LENGTH (d:word8 list) = 20248 ==>
      TAKE 130436 (DROP 16592 f) = c /\ TAKE 20248 (DROP 180248 f) = d /\ TAKE 108 (DROP 16384 f) = s /\
      LENGTH (TAKE 163840 f) = 163840 /\ LENGTH (TAKE 20248 (DROP 180248 f)) = 20248 /\
      !(a:word64) m. bytes_in_memory a (TAKE 163840 f) m UNIV ==>
        bytes_in_memory (a + 16384w) s m UNIV /\ bytes_in_memory (a + 16592w) c m UNIV``
  (rpt gen_tac >> strip_tac >>
   `TAKE 163840 f = p ++ (s ++ (q ++ (c ++ t)))` by (asm_rewrite_tac [] >> simp [TAKE_APPEND, TAKE_LENGTH_TOO_LONG]) >>
   `DROP 16592 f = c ++ (t ++ (mm ++ (d ++ e)))` by (asm_rewrite_tac [] >> simp [DROP_APPEND, DROP_LENGTH_TOO_LONG]) >>
   `DROP 180248 f = d ++ e` by (asm_rewrite_tac [] >> simp [DROP_APPEND, DROP_LENGTH_TOO_LONG]) >>
   `DROP 16384 f = s ++ (q ++ (c ++ (t ++ (mm ++ (d ++ e)))))` by (asm_rewrite_tac [] >> simp [DROP_APPEND, DROP_LENGTH_TOO_LONG]) >>
   asm_rewrite_tac [] >> simp [TAKE_APPEND, TAKE_LENGTH_TOO_LONG, bytes_in_memory_APPEND] >> show_tac "V");
val Vi = MATCH_MP V (LIST_CONJ [layout, lenP, lenS, lenQ, len_code, lenT, lenM, lenD]);
val [f_code0, f_bm, f_stub, len_text, len_bm, f_mem] = CONJUNCTS Vi;
val f_code = save_thm ("refund_file_code", CONV_RULE (LAND_CONV (LAND_CONV (K (SYM len_code)))) f_code0);
val _ = chk "refund_file_code" f_code;
val f_bm = save_thm ("refund_file_bitmaps", f_bm); val _ = chk "refund_file_bitmaps" f_bm;
val f_stub = save_thm ("refund_file_cml_main", f_stub); val _ = chk "refund_file_cml_main" f_stub;
val len_file = save_thm ("refund_file_length", (RAND_CONV (REWR_CONV file_def) THENC EVAL) ``LENGTH ^file_c``);
val _ = chk "refund_file_length" len_file;
(* ---- 3. Mach-O header fields, evaluated from the file constant. ---- *)
val le_num_def = Define `(le_num [] = 0n) /\ (le_num ((b:word8)::bs) = w2n b + 256 * le_num bs)`;
fun field (off, len) = (RAND_CONV (RAND_CONV (RAND_CONV (REWR_CONV file_def))) THENC EVAL)
      ``le_num (TAKE ^(numSyntax.term_of_int len) (DROP ^(numSyntax.term_of_int off) ^file_c))``;
val fields = map field [(0,4),(12,4),(16,4),(24,4), (104,4),(128,8),(136,8),(144,8),(152,8),(164,4),
                        (648,4),(672,8),(680,8),(688,8),(696,8),(708,4), (1192,4),(1200,8)];
val expect = [0xFEEDFACF, 2, 18, 0x200085, 0x19, 0x100000000, 163840, 0, 163840, 5, 0x19, 0x10002C000, 32768, 180224, 32768, 3, 0x80000028, 152900];
val _ = ListPair.app (fn (th, v) => if numSyntax.int_of_term (rhs (concl th)) = v then () else raise Fail ("header field: " ^ thm_to_string th)) (fields, expect);
fun name_at off str = (LAND_CONV (RAND_CONV (RAND_CONV (REWR_CONV file_def))) THENC EVAL)
      ``TAKE ^(numSyntax.term_of_int (size str)) (DROP ^(numSyntax.term_of_int off) ^file_c) = MAP (n2w o ORD) ^(stringSyntax.fromMLstring str)``;
val names = map (EQT_ELIM o (fn (o', s) => name_at o' s)) [(112, "__TEXT"), (656, "__DATA")];
val macho = save_thm ("refund_macho_fields", LIST_CONJ (fields @ names));
val _ = chk "refund_macho_fields" macho;
(* ---- 4. The image predicate (ASSUMED of the entry state; nothing here proves that a loader establishes it). ---- *)
val image_def = new_definition ("refund_image_mem_def",
  ``refund_image_mem (sl:word64) (m:word64 -> word8) <=>
      bytes_in_memory (0x100000000w + sl) (TAKE 163840 refund_file) m UNIV /\
      bytes_in_memory (0x10002C018w + sl) (TAKE 20248 (DROP 180248 refund_file)) m UNIV``);
val _ = pr ("DEFINITION " ^ thm_to_string image_def);
val img_code = thm "refund_image_code"
  ``!sl m. refund_image_mem sl m ==> bytes_in_memory (0x1000040D0w + sl) ^code_tm m UNIV``
  (rw [image_def] >> drule f_mem >> simp [] >> show_tac "IMGCODE");
val img_stub = thm "refund_image_cml_main"
  ``!sl m. refund_image_mem sl m ==> bytes_in_memory (0x100004000w + sl) ^STUB m UNIV``
  (rw [image_def] >> drule f_mem >> simp [] >> show_tac "IMGSTUB");
val img_bm = thm "refund_image_bitmaps"
  ``!sl m i. refund_image_mem sl m /\ i < LENGTH ^data_tm ==> mem_dword m (0x10002C018w + sl + n2w (8 * i)) = n2w (EL i ^data_tm)``
  (rw [image_def, f_bm] >> drule dword_bytes_in_memory >> disch_then (qspec_then `i` mp_tac) >> simp [EL_MAP] >> show_tac "IMGBM");
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
(* ---- 5. Clauses for a memory that holds the image at slide 0. ---- *)
val dm_def = new_definition ("refund_bitmaps_dm_def",
  ``refund_bitmaps_dm = {x:word64 | ?i. i < LENGTH ^data_tm /\ byte_align x = 0x10002C018w + n2w i * 8w}``);
val ba64 = prove (``byte_aligned (a:word64) <=> aligned 3 a``, simp [byte_aligned_def] >> EVAL_TAC);
val dm_al = thm "refund_bitmaps_dm_aligned"
  ``!x. x IN byte_aligned INTER refund_bitmaps_dm <=> ?i. i < LENGTH ^data_tm /\ x = 0x10002C018w + n2w i * 8w``
  (gen_tac >> `x IN byte_aligned <=> byte_aligned x` by simp [IN_DEF] >> asm_simp_tac std_ss [IN_INTER, dm_def, GSPECIFICATION] >>
   eq_tac >> strip_tac
   >- (qexists_tac `i` >> fs [byte_aligned_def, byte_align_def, aligned_def] >> show_tac "DM1" >> metis_tac [])
   >- (`byte_aligned x` by (asm_rewrite_tac [ba64, aligned_bitwise_and] >> qspec_tac (`n2w i:word64`, `v`) >> blastLib.BBLAST_TAC) >>
       asm_rewrite_tac [] >> qexists_tac `i` >> fs [byte_aligned_def, byte_align_def, aligned_def] >> metis_tac []));
val dm_closed = thm "refund_bitmaps_dm_closed" ``!a. byte_align a IN refund_bitmaps_dm ==> a IN refund_bitmaps_dm``
  (simp [dm_def, byte_align_def, align_align] >> show_tac "DMC");
val clause_tm = ``\(m:word64 -> word8). (word_list 0x10002C018w (MAP (Word o n2w) ^data_tm) *
     word_list_exists (0x10002C018w + bytes_in_word * n2w (LENGTH ^data_tm)) 0)
       (fun2set ((\a. Word (mem_dword m a) : 64 word_loc), byte_aligned INTER refund_bitmaps_dm))``;
val bm_clause = thm "refund_image_bitmap_clause" ``!m. refund_image_mem 0w m ==> ^clause_tm m``
  (rpt strip_tac >> BETA_TAC >> simp [word_list_exists_0, SEP_CLAUSES] >> match_mp_tac word_list_fun2set >>
   simp [len_data, dm_al] >> rpt strip_tac >> simp [EL_MAP, len_data] >>
   mp_tac (Q.SPECL [`0w`, `m`, `i`] img_bm) >> simp [len_data, word_mul_n2w] >> show_tac "BMC");
val cl = thm "code_loaded_from_memory"
  ``!bs mc0 (ms:arm8_state). is_arm8_machine_config mc0 /\ bytes_in_memory ms.PC bs ms.MEM UNIV /\
      (!i. i < LENGTH bs ==> ms.PC + n2w i IN mc0.prog_addresses) ==> code_loaded bs mc0 ms``
  (rw [code_loaded_def, is_arm8_machine_config_def] >> simp [arm8_target_def] >> match_mp_tac read_bytearray_from_EL >>
   fs [bytes_in_memory_univ_EL] >> show_tac "CL");
val b1 = prove (``i < 163840 ==> 0x100000000w <=+ 0x100000000w + n2w i:word64 /\ 0x100000000w + n2w i <+ 0x100030F30w:word64``,
  strip_tac >> simp [word_add_n2w, word_ls_n2w, word_lo_n2w]);
val b2 = prove (``i < 20248 ==> 0x100000000w <=+ 0x10002C018w + n2w i:word64 /\ 0x10002C018w + n2w i <+ 0x100030F30w:word64``,
  strip_tac >> simp [word_add_n2w, word_ls_n2w, word_lo_n2w]);
val sep_tm = ``!i (a:word64). i < 40 /\ 0x100000000w <=+ a /\ a <+ 0x100030F30w ==> (h:word64) + n2w i <> a``;
val pres = thm "refund_image_preserved"
  ``!m m' h. refund_image_mem 0w m /\ ^sep_tm /\ (!a. (!i. i < 40 ==> a <> h + n2w i) ==> m' a = m a) ==> refund_image_mem 0w m'``
  (rw [image_def] >> match_mp_tac bytes_in_memory_univ_frame >> qexists_tac `m` >> asm_rewrite_tac [len_text, len_bm] >>
   rpt strip_tac >> first_x_assum match_mp_tac >> rpt strip_tac >> imp_res_tac b1 >> imp_res_tac b2 >> metis_tac []);
(* ---- 6. Entry pre-state and the composition with the 27 steps. ---- *)
val entry_def = new_definition ("refund_entry_pre_def", ``refund_entry_pre (s:arm8_state) (h:word64) (stk:word64) (e:word64) <=>
   ~s.SCTLR_EL1.E0E /\ ~s.SCTLR_EL1.SA0 /\ ~s.TCR_EL1.TBI0 /\ ~s.TCR_EL1.TBI1 /\ s.PSTATE.EL = 0w /\ s.exception = NoException /\
   s.PC = 0x100004000w /\ mem_dword s.MEM 0x10002C000w = h /\ mem_dword s.MEM 0x10002C008w = stk /\ mem_dword s.MEM 0x10002C010w = e /\
   aligned 3 h /\ ^sep_tm /\ refund_image_mem 0w s.MEM``);
val _ = pr ("DEFINITION " ^ thm_to_string entry_def);
val hb1 = prove (``0x100004000w <=+ a ==> 0x100000000w <=+ (a:word64)``, blastLib.BBLAST_TAC);
val hb2 = prove (``a <+ 0x10002C018w ==> a <+ 0x100030F30w:word64``, blastLib.BBLAST_TAC);
val entry_pre = thm "refund_entry_pre_IMP_cml_main_pre" ``refund_entry_pre s h stk e ==> cml_main_pre s h stk e``
  (rewrite_tac [entry_def] >> strip_tac >> drule img_stub >> simp [bytes_in_memory_def] >> strip_tac >>
   asm_simp_tac (srw_ss()) [cml_main_pre_def] >> rpt gen_tac >> CCONTR_TAC >> fs [] >> imp_res_tac hb1 >> imp_res_tac hb2 >>
   first_x_assum (qspecl_then [`i`, `h + n2w i`] mp_tac) >> asm_rewrite_tac []);
val est = DB.fetch "forge_refundStartupBridge" "refund_startup_established";
val runf = DB.fetch "forge_refundCmlMainFrame" "cml_main_run_frame";
val ms = ``ms:arm8_state``;
val startup_conj = el 3 (strip_conj (snd (dest_exists (snd (dest_imp (concl est))))));
val main_goal = ``refund_entry_pre s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h ==>
  ?ms. arm8_run 27 s = SOME ms /\ ms.PC = 0x1000040D0w /\ ms.REG 1w = h /\ ms.REG 3w = e /\
       refund_image_mem 0w ms.MEM /\ bytes_in_memory ms.PC ^code_tm ms.MEM UNIV /\
       (!md k. (!i. i < LENGTH ^code_tm ==> ms.PC + n2w i IN md /\ ms.PC + n2w i NOTIN k) ==> bytes_in_mem ms.PC ^code_tm ms.MEM md k) /\
       (!mc0. is_arm8_machine_config mc0 /\ (!i. i < LENGTH ^code_tm ==> ms.PC + n2w i IN mc0.prog_addresses) ==>
              code_loaded ^code_tm mc0 ms) /\
       ^clause_tm ms.MEM /\
       (!a. ?w. ms.MEM a = get_byte a w F /\ (\a. Word (mem_dword ms.MEM a) : 64 word_loc) (byte_align a) = Word w) /\
       ^startup_conj``;
val main = thm "refund_loader_startup" main_goal
  (strip_tac >> imp_res_tac entry_pre >>
   mp_tac est >> impl_tac >- asm_rewrite_tac [] >> strip_tac >>
   mp_tac runf >> impl_tac >- asm_rewrite_tac [] >> strip_tac >>
   `s1 = ms` by fs [] >> rpt BasicProvers.VAR_EQ_TAC >>
   qexists_tac `s1` >>
   `refund_image_mem 0w s1.MEM` by (match_mp_tac pres >> qexistsl_tac [`s.MEM`, `h`] >> fs [entry_def] >> show_tac "MAIN1") >>
   `bytes_in_memory s1.PC ^code_tm s1.MEM UNIV` by (drule img_code >> asm_simp_tac (srw_ss()) []) >>
   asm_rewrite_tac [] >> rpt conj_tac
   >- (rpt strip_tac >> asm_simp_tac std_ss [bytes_in_mem_iff] >> fs [])
   >- (rpt strip_tac >> match_mp_tac cl >> fs [])
   >- (mp_tac (Q.SPEC `s1.MEM` bm_clause) >> asm_rewrite_tac [])
   >- (MATCH_ACCEPT_TAC (Q.SPEC `s1.MEM` mem_dword_word_memory_clause))
   >- (show_tac "MAIN2" >> first_assum ACCEPT_TAC));
(* ---- 7. Negative controls (theorems). ---- *)
val n1 = thm "code_byte_change_rejected"
  ``!i a (m:word64 -> word8) md k. i < LENGTH ^code_tm /\ m (a + n2w i) <> EL i ^code_tm ==> ~bytes_in_mem a ^code_tm m md k``
  (simp [bytes_in_mem_iff, bytes_in_memory_univ_EL] >> metis_tac []);
val n4a = thm "code_overlap_rejected"
  ``!i a (m:word64 -> word8) md k. i < LENGTH ^code_tm /\ a + n2w i IN k ==> ~bytes_in_mem a ^code_tm m md k``
  (simp [bytes_in_mem_iff] >> metis_tac []);
val n2 = thm "bitmap_word_change_rejected"
  ``!(m:word64 -> word8) dm r i. i < LENGTH ^data_tm /\ mem_dword m (0x10002C018w + n2w (8 * i)) <> n2w (EL i ^data_tm) ==>
      ~(word_list 0x10002C018w (MAP (Word o n2w) ^data_tm) * r) (fun2set ((\a. Word (mem_dword m a) : 64 word_loc), dm))``
  (rpt strip_tac >> drule_at (Pos (el 2)) word_list_clause_read >> simp [len_data] >> qexists_tac `i` >>
   fs [len_data, EL_MAP, word_mul_n2w] >> show_tac "N2");
val el_code = map (fn k => (RAND_CONV (REWR_CONV code_def) THENC EVAL) ``EL ^(numSyntax.term_of_int k) ^code_tm``) [0, 4];
val el_data = map (fn k => (RAND_CONV (REWR_CONV data_def) THENC EVAL) ``EL ^(numSyntax.term_of_int k) ^data_tm``) [0, 1];
val _ = List.app (fn th => pr ("EL " ^ thm_to_string th)) (el_code @ el_data);
val n3a = thm "code_wrong_offset_rejected" ``!m md k. refund_image_mem 0w m ==> ~bytes_in_mem 0x1000040D4w ^code_tm m md k``
  (rpt strip_tac >> drule img_code >> fs [bytes_in_mem_iff, bytes_in_memory_univ_EL] >>
   rpt (first_x_assum (fn th => if is_forall (concl th) then (assume_tac (Q.SPEC `0` th) >> assume_tac (Q.SPEC `4` th)) else NO_TAC)) >>
   rfs (len_code :: el_code) >> show_tac "N3A");
val n3b = thm "bitmap_wrong_offset_rejected"
  ``!m dm r. refund_image_mem 0w m ==>
      ~(word_list 0x10002C020w (MAP (Word o n2w) ^data_tm) * r) (fun2set ((\a. Word (mem_dword m a) : 64 word_loc), dm))``
  (rpt strip_tac >> drule_at (Pos (el 2)) word_list_clause_read >> simp [len_data] >> qexists_tac `0` >>
   mp_tac (Q.SPECL [`0w`, `m`, `1`] img_bm) >> asm_simp_tac (srw_ss()) ([len_data, EL_MAP] @ el_data) >> show_tac "N3B");
val run0 = DB.fetch "forge_refundCmlMainStep" "cml_main_run";
val n4b = thm "header_on_bitmaps_refuted"
  ``cml_main_pre s 0x10002C018w stk e ==> ?ms. arm8_run 27 s = SOME ms /\
      !dm r. ~(word_list 0x10002C018w (MAP (Word o n2w) ^data_tm) * r) (fun2set ((\a. Word (mem_dword ms.MEM a) : 64 word_loc), dm))``
  (strip_tac >> imp_res_tac run0 >> qexists_tac `s1` >> asm_rewrite_tac [] >> rpt gen_tac >>
   match_mp_tac (SIMP_RULE (srw_ss()) [] (Q.SPECL [`s1.MEM`, `dm`, `r`, `0`] n2)) >> asm_simp_tac (srw_ss()) (len_data :: el_data) >> show_tac "N4B");
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val closure = "forge_refundLoaderMemory" :: Theory.ancestry "forge_refundLoaderMemory";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
