(* U389: bytes of the linked refund executable (Mach-O) against the stored compiled code and bitmaps. Image predicate with a slide.
   The loader is NOT modelled: refund_image_mem is a predicate on a memory, to be assumed of the state at entry to cml_main. *)
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
val _ = new_theory "forge_refundImage";
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
val _ = save_thm ("refund_file_text_length", len_text); val _ = save_thm ("refund_file_bitmap_length", len_bm);
val _ = save_thm ("refund_file_text_memory", f_mem); val _ = chk "refund_file_text_memory" f_mem;
val samples = LIST_CONJ (map (fn k => (RAND_CONV (REWR_CONV code_def) THENC EVAL) ``EL ^(numSyntax.term_of_int k) ^code_tm``) [0, 4] @
                         map (fn k => (RAND_CONV (REWR_CONV data_def) THENC EVAL) ``EL ^(numSyntax.term_of_int k) ^data_tm``) [0, 1] @
                         [(RAND_CONV (REWR_CONV data_def) THENC EVAL) ``HD ^data_tm``]);
val _ = save_thm ("refund_code_data_samples", samples); val _ = chk "refund_code_data_samples" samples;
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val closure = "forge_refundImage" :: Theory.ancestry "forge_refundImage";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
