(* r6_common.sml (worker A30, round 4). NOT RUN as a file. Shared by R6x-0004.sml (exploration) and R6ffi-0001.sml (proof);
   both read it with use AFTER new_theory. The caller must define: pr, trunc, fth, and
   R6_PROOF_MODE : bool (true = a failed definition or statement raises; false = it prints and goes on).
   Contents: the grammar fix of R6x-0003 (unchanged), the definitions IOxV, IOFS_V, STDIO_V (text of R6x-0003 lines
   193-203, now as [QUOTE] strings), the theorem shortcuts, the invariant tactics (NEW INV_ZIP family, built from the
   goal printed in R6x-0003/stdout.log 2262-2275 and 3546-3560), and the four statements. Every tactic UNCHECKED. *)
(* ================= GRAMMAR (R6x-0003 lines 36-65, unchanged; it worked: GRAMMAR_FIX B) ================= *)
val _ = pr "MARK GRAMMAR";
fun v_thy () : string = #Thy (dest_thy_type (Parse.Type [QUOTE ":v"]))
  handle e => "PARSE_FAILED " ^ trunc 200 (General.exnMessage e);
fun dummy_ok () : string = (ignore (Parse.Term [QUOTE "POSTv (v:v). &T"]); "OK")
  handle e => "FAILED " ^ trunc 400 (General.exnMessage e);
val _ = pr ("GRAMMAR_BEFORE type_v_from " ^ v_thy () ^ " ; xlet_auto_dummy_spec " ^ dummy_ok ());
fun privileged_thy (nm : string) : string option =
  Symtab.lookup (type_grammar.privileged_abbrevs (Parse.type_grammar ())) nm;
fun reprivilege (thy : string) : unit =
  let
    val tys = Theory.types thy
      handle e => (pr ("TYPES_FAILED " ^ thy ^ " " ^ trunc 200 (General.exnMessage e)); [])
    fun one ((nm, _) : string * int) : unit =
      (case privileged_thy nm of
         SOME t => if t = thy then ()
                   else (Parse.temp_add_qtype {Thy = thy, Name = nm};
                         pr ("TYPE_REPRIVILEGED " ^ nm ^ " was " ^ t ^ " now " ^ thy))
       | NONE => (Parse.temp_add_qtype {Thy = thy, Name = nm};
                  pr ("TYPE_PRIVILEGED " ^ nm ^ " was none now " ^ thy)))
      handle e => pr ("TYPE_REPRIVILEGE_FAILED " ^ thy ^ "$" ^ nm ^ " " ^ trunc 200 (General.exnMessage e))
  in List.app one tys end;
val _ = List.app reprivilege ["ffi", "namespace", "ast", "semanticPrimitives"];
val _ = pr ("GRAMMAR_AFTER_B type_v_from " ^ v_thy () ^ " ; xlet_auto_dummy_spec " ^ dummy_ok ());
val _ =
  if dummy_ok () = "OK" andalso v_thy () = "semanticPrimitives" then pr "GRAMMAR_FIX B"
  else (case Parse.grammarDB {thyname = "TextIOProof"} of
          SOME g => (Parse.temp_set_grammars g;
                     pr ("GRAMMAR_FIX A type_v_from " ^ v_thy () ^ " ; xlet_auto_dummy_spec " ^ dummy_ok ()))
        | NONE => pr "GRAMMAR_FIX_FAILED grammarDB TextIOProof = NONE");

(* ================= DEFINITIONS ================= *)
val _ = pr "MARK DEFS";
fun r6_define (name : string) (q : string) : thm =
  new_definition (name, Parse.Term [QUOTE q])
  handle e => (pr ("DEFINITION_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e));
               if R6_PROOF_MODE then raise e else TRUTH);
(* binder name "events" as in cfHeapsBase IO_def, so that copied tactics that name events still match *)
val IOxV_def = r6_define "IOxV_def"
  ("IOxV (Inv:io_event -> bool) (fs:IO_fs) = " ^
   "SEP_EXISTS events. one (FFI_part (fsFFI$encode fs) (mk_ffi_next fs_ffi_part) " ^
   "(MAP FST (SND (SND fs_ffi_part))) events) * " ^
   "&(EVERY Inv events) * &(~MEM \194\171\194\187 (MAP FST (SND (SND fs_ffi_part))))");
val IOFS_V_def = r6_define "IOFS_V_def"
  ("IOFS_V (Inv:io_event -> bool) (fs:IO_fs) = " ^
   "IOxV Inv fs * (SEP_EXISTS v. W8ARRAY iobuff_loc v * &(LENGTH v = 2052)) * &wfFS fs");
val STDIO_V_def = r6_define "STDIO_V_def"
  ("STDIO_V (Inv:io_event -> bool) (fs:IO_fs) = " ^
   "(SEP_EXISTS ll. IOFS_V Inv (fs with numchars := ll)) * &STD_streams fs");
val _ = List.app (fn th => pr ("DEFINITION " ^ thm_to_string th)) [IOxV_def, IOFS_V_def, STDIO_V_def];

(* ================= theorem shortcuts ================= *)
val SIR = fth "set_sep" "SEP_IMP_REFL";
val IOxD = fth "cfHeapsBase" "IOx_def";
val IOD = fth "cfHeapsBase" "IO_def";
val FFP = fth "fsFFI" "fs_ffi_part_def";
val FPH = fth "cfMain" "FFI_part_hprop_def";
val SEPC = fth "set_sep" "SEP_CLAUSES";
val SEPE = fth "set_sep" "SEP_EXISTS_THM";
val STARD = fth "set_sep" "STAR_def";
val CONDD = fth "set_sep" "cond_def";
val ONED = fth "set_sep" "one_def";
val ONES = fth "set_sep" "one_STAR";
val SPLD = fth "set_sep" "SPLIT_def";
val W8AD = fth "cfHeapsBase" "W8ARRAY_def";
val CELLD = fth "cfHeapsBase" "cell_def";
val INU = fth "pred_set" "IN_UNION";
val EVA = fth "list" "EVERY_APPEND";
val ZIPD = fth "list" "ZIP_def";
val LTE = fth "list" "LENGTH_TAKE_EQ";
val ABD = fth "marker" "Abbrev_def";
val N2W2D = fth "Marshalling" "n2w2_def";
val MIND = fth "arithmetic" "MIN_DEF";

(* ================= invariant tactics =================
   The only new obligation at an xffi site is the pure goal EVERY Inv new_events, with
   Abbrev (new_events = events ++ [IO_event (ExtCall nm) conf zs]); app_ffi_def (cfScript.sml 1777) adds
   IO_event (ExtCall nm) conf (ZIP (ws, vs)). R6x-0003 FINDING: fs has already evaluated that ZIP, so zs is a cons list
   of pairs (ws_k, vs_k) ending in ZIP (rest, tail) (log 2262-2275 write; 3546-3560 read). H_inv is stated with
   ZIP (ws, nb) for a variable nb, so irule/rewriting with H_inv cannot match (R6x-0003 INV_C1-C5 all failed:
   STEP_FAILED ... NO_TAC, log 1663, 1947, 3545, 3823; the "working" alt 1 was the non-closing INV_DIAG, which left
   the goal Inv (...) open; that open goal is why writei step 11 (log 2233) and read_into step 13 (log 4109) failed).
   NEW: read the bytes vs back from the goal (snd_list), instantiate H_inv with them (SPEC), prove the length/head
   side condition, and let simp evaluate ZIP (ws, vs) in H_inv to the same cons list. *)
val _ = pr "MARK INV_HELPERS";
fun is_inv_var (t : term) : bool = is_var t andalso fst (dest_var t) = "Inv";
fun is_inv_app (t : term) : bool = is_comb t andalso is_inv_var (rator t);
fun is_every_inv (t : term) : bool =
  is_comb t andalso is_comb (rator t) andalso is_inv_var (rand (rator t)) andalso
  (let val c = rator (rator t) in is_const c andalso fst (dest_const c) = "EVERY" end);
val HEAP_CONSTS = ["SEP_IMP", "app", "cf_let", "cf_app", "cf_if", "cf_ffi", "app_ffi", "IOxV", "FFI_part", "W8ARRAY"];
fun mentions_heap (w : term) : bool =
  can (find_term (fn t => is_const t andalso Lib.mem (fst (dest_const t)) HEAP_CONSTS)) w;
fun is_inv_goal ((_, w) : goal) : bool =
  not (mentions_heap w) andalso can (find_term (fn t => is_inv_app t orelse is_every_inv t)) w;
(* ON_INV tac: tac on a pure invariant goal, ALL_TAC on any other goal *)
fun ON_INV (tac : tactic) : tactic = fn g => if is_inv_goal g then tac g else ALL_TAC g;
fun closing (t : tactic) : tactic = t \\ NO_TAC;
(* snd_list: (a1,b1)::...::(ak,bk)::ZIP (x, y)  |->  b1::...::bk::y ;  [] |-> [] *)
fun snd_list (t : term) : term =
  if listSyntax.is_cons t then
    let val (h, tl) = listSyntax.dest_cons t in listSyntax.mk_cons (snd (pairSyntax.dest_pair h), snd_list tl) end
  else if listSyntax.is_nil t then listSyntax.mk_nil (snd (pairSyntax.dest_prod (listSyntax.dest_list_type (type_of t))))
  else if is_comb t andalso is_const (rator t) andalso fst (dest_const (rator t)) = "ZIP"
  then snd (pairSyntax.dest_pair (rand t))
  else raise mk_HOL_ERR "r6_common" "snd_list" "unexpected tail of the event byte list";
(* the new-bytes list of the (first) event Inv (IO_event nm conf zs) in w *)
fun event_nb (w : term) : term = snd_list (rand (rand (find_term is_inv_app w)));
(* mp_tac (SPEC nb H_inv); the head goal must be Inv (IO_event ...) *)
val ZIP_SPEC_TAC : tactic = fn (g as (_, w)) =>
  qpat_x_assum [QUOTE "!nb. _"] (mp_tac o SPEC (event_nb w)) g;
val INV_Z1 = fs [ABD, EVA] \\ ZIP_SPEC_TAC \\ impl_tac >- (simp [LTE] \\ rw [MIND] \\ fs []) \\ simp [ZIPD];
val INV_Z2 = fs [ABD, EVA] \\ ZIP_SPEC_TAC \\ simp [ZIPD, LTE] \\ rw [MIND] \\ fs [ZIPD];
val INV_Z3 = fs [ABD, EVA] \\ ZIP_SPEC_TAC \\ impl_tac >- (rw [LTE, MIND] \\ fs [] \\ rw [] \\ fs []) \\
             simp [ZIPD] \\ fs [ZIPD];
(* the R6x-0003 variants (all failed there; kept last) *)
val INV_C1 = fs [ABD, EVA, N2W2D];
val INV_C2 = fs [ABD, EVA] \\ first_x_assum irule \\ rw [] \\ fs [];
val INV_C5 = fs [ABD, EVA] \\ metis_tac [];
val INV_ALL : tactic = FIRST (map closing [INV_Z1, INV_Z2, INV_Z3, INV_C1, INV_C2, INV_C5]);
val INV_ZONLY : tactic = FIRST (map closing [INV_Z2, INV_Z3]);

(* ================= statements (R6x-0002/0003 text; built from the stored specs) ================= *)
val _ = pr "MARK STATEMENTS";
fun r6_term (name : string) (f : unit -> term) : term =
  f () handle e => (pr ("STATEMENT_PARSE_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e));
                    if R6_PROOF_MODE then raise e else T);
val X9_STMT = r6_term "X9" (fn () =>
  Parse.Term [QUOTE "!(Inv:io_event -> bool) fs. FFI_part_hprop (IOFS_V Inv fs)"]);
val X8_STMT = r6_term "X8" (fn () =>
  Parse.Term [QUOTE "!(Inv:io_event -> bool) fs. IOxV Inv fs ==>> IOx fs_ffi_part fs"]);
val IOX_FS = Parse.Term [QUOTE "IOx fs_ffi_part"];
val IOXV_INV = Parse.Term [QUOTE "IOxV (Inv:io_event -> bool)"];
(* writei_spec_V: writei_spec (TextIOProofScript.sml 1406-1421) with IOx fs_ffi_part := IOxV Inv; H_inv last *)
val WRITEI_V = r6_term "writei_spec_V" (fn () =>
  let val (hs, c) = strip_imp (concl (fth "TextIOProof" "writei_spec"))
      val hinv = Parse.Term [QUOTE ("!nb:word8 list. LENGTH nb = 4 + LENGTH (rest:word8 list) /\\ HD nb = 0w ==> " ^
                   "Inv (IO_event (ExtCall \194\171write\194\187) (n2w8 fd) (ZIP (n2w2 n ++ n2w2 i ++ rest, nb)))")]
  in list_mk_imp (hs @ [hinv], subst [IOX_FS |-> IOXV_INV] c) end);
(* read_into_spec_V: read_into_spec (2132-2149); two hypotheses exclude the error paths; H_inv last *)
val READ_INTO_V = r6_term "read_into_spec_V" (fn () =>
  let val (vs, body) = strip_forall (concl (fth "TextIOProof" "read_into_spec"))
      val (hs, c) = strip_imp body
      val extra = [Parse.Term [QUOTE "get_fd_content fs fd <> NONE"],
                   Parse.Term [QUOTE "get_mode fs fd = SOME ReadMode"],
                   Parse.Term [QUOTE ("!nb:word8 list. LENGTH nb = 4 + LENGTH (rest:word8 list) /\\ HD nb = 0w ==> " ^
                     "Inv (IO_event (ExtCall \194\171read\194\187) (n2w8 fd) (ZIP (n2w2 n ++ h3::h4::rest, nb)))")]]
  in list_mk_forall (vs, list_mk_imp (hs @ extra, subst [IOX_FS |-> IOXV_INV] c)) end);
val _ = List.app (fn (n, t) => pr ("STATEMENT " ^ n ^ "\n" ^ term_to_string t))
          [("X9", X9_STMT), ("X8", X8_STMT), ("writei_spec_V", WRITEI_V), ("read_into_spec_V", READ_INTO_V)];
