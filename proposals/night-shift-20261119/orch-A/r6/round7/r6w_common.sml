(* r6w_common.sml (worker A33, round 6). NOT RUN as a file. Shared by R6wx-0001.sml (exploration) and R6w-0001.sml (proof);
   both read it with use AFTER new_theory and AFTER the theory forge_refundR6Ffi (case R6ffi-0002) is loaded.
   The caller must define: pr, trunc, fth, showg, tlim, R6W_PROOF_MODE : bool.
   It does NOT re-use round5/r6_common.sml, because that file calls new_definition for IOxV/IOFS_V/STDIO_V; those
   constants now come from the parent theory forge_refundR6Ffi.
   Contents: the grammar fix (round5/r6_common.sml lines 7-36, byte-identical), the ONE new definition write_event_ok,
   theorem shortcuts, the theorem table TH (prerequisites), the replay function (round5/r6_prove.sml step_tac and
   head_replay, names A30 -> A33), and all statements. Every tactic UNCHECKED. ASCII only. *)
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

(* ================= DEFINITION (NEW, the only one of this theory) ================= *)
(* write_event_ok Inv fd: Inv accepts every successful write event on descriptor fd whose byte array is
   n2w2 n ++ n2w2 i ++ rest with LENGTH rest = 2048 (iobuff of exactly 2052 bytes, as pinned by IOFS_V) and i + n <= 2048.
   The event text is the text of the H_inv of writei_spec_V (round5/r6_common.sml line 145), so both parse the same. *)
val _ = pr "MARK DEFS";
fun r6w_define (name : string) (q : string) : thm =
  new_definition (name, Parse.Term [QUOTE q])
  handle e => (pr ("DEFINITION_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e));
               if R6W_PROOF_MODE then raise e else TRUTH);
val write_event_ok_def = r6w_define "write_event_ok_def"
  ("write_event_ok (Inv:io_event -> bool) (fd:num) <=> " ^
   "!(n:num) (i:num) (rest:word8 list) (nb:word8 list). " ^
   "LENGTH rest = 2048 /\\ i + n <= 2048 /\\ LENGTH nb = 4 + LENGTH rest /\\ HD nb = 0w ==> " ^
   "Inv (IO_event (ExtCall \194\171write\194\187) (n2w8 fd) (ZIP (n2w2 n ++ n2w2 i ++ rest, nb)))");
val _ = pr ("DEFINITION " ^ thm_to_string write_event_ok_def);

(* ================= theorem shortcuts (parent theory forge_refundR6Ffi; L2c) ================= *)
val _ = pr "MARK SHORTCUTS";
val IOxV_def = fth "forge_refundR6Ffi" "IOxV_def";
val IOFS_V_def = fth "forge_refundR6Ffi" "IOFS_V_def";
val STDIO_V_def = fth "forge_refundR6Ffi" "STDIO_V_def";
val WRITEI_V_TH = fth "forge_refundR6Ffi" "writei_spec_V";
val RVE_def = fth "forge_refundRouteA2c" "refund_valid_event_def";

(* ================= theorem table: prerequisites by name ================= *)
(* Proof mode: filled by save after each stored lemma. Exploration: filled first with ASSUME of each statement
   (so each lemma is explored independently), then replaced by real theorems where a helper proof closes. *)
val R6W_TH = ref ([] : (string * thm) list);
fun TH (nm : string) : thm =
  case List.find (fn (n, _) => n = nm) (!R6W_TH) of
    SOME (_, th) => th
  | NONE => raise mk_HOL_ERR "r6w_common" "TH" ("no theorem " ^ nm);
fun set_TH (nm : string) (th : thm) : unit =
  R6W_TH := (nm, th) :: List.filter (fn (n, _) => n <> nm) (!R6W_TH);
(* LATE f: build the tactic only when it runs, so TH is read at run time, not at use time *)
fun LATE (f : unit -> tactic) : tactic = fn g => f () g;

(* ================= replay (round5/r6_prove.sml step_tac and head_replay; names A30 -> A33) ================= *)
val STEP_LIMIT = 240;
fun step_tac (lemma : string) (i : int) ((label, t, alts) : string * tactic * tactic list) : tactic =
  fn (g : goal) => fn (ctxt : Context.t) =>
    let
      fun go (_ : int) ([] : tactic list) =
            (showg ("STEP_ALL_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label) g;
             raise mk_HOL_ERR "A33" "step_tac" ("all candidates failed at " ^ lemma ^ " step " ^ Int.toString i))
        | go k (c :: cs) =
            (let val r = tlim STEP_LIMIT c g ctxt
             in pr ("STEP_USED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " candidate " ^ Int.toString k ^
                    " goals_out " ^ Int.toString (length (#1 r)));
                r
             end
             handle e => (pr ("STEP_CANDIDATE_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " candidate " ^
                              Int.toString k ^ " " ^ trunc 300 (General.exnMessage e));
                          go (k + 1) cs))
    in go 0 (t :: alts) end;
fun head_replay (lemma : string) (steps : (string * tactic * tactic list) list) : tactic =
  let fun loop (_ : int) (acc : tactic) [] = acc
        | loop i acc (s :: rest) = loop (i + 1) (Tactical.THEN_LT (acc, HEADGOAL (step_tac lemma i s))) rest
  in loop 1 ALL_TAC steps end;

(* ================= statements ================= *)
val _ = pr "MARK STATEMENTS";
fun r6w_term (name : string) (f : unit -> term) : term =
  f () handle e => (pr ("STATEMENT_PARSE_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e));
                    if R6W_PROOF_MODE then raise e else T);
fun PT (s : string) : term = Parse.Term [QUOTE s];
fun IOX_FS () = PT "IOx fs_ffi_part";
fun IOXV_INV () = PT "IOxV (Inv:io_event -> bool)";
fun IOFS_C () = PT "IOFS";
fun IOFS_V_INV () = PT "IOFS_V (Inv:io_event -> bool)";
fun STDIO_C () = PT "STDIO";
fun STDIO_V_INV () = PT "STDIO_V (Inv:io_event -> bool)";
fun LEN_REST () = PT "LENGTH (rest:word8 list) = 2048";
fun WOK_FD () = PT "write_event_ok (Inv:io_event -> bool) (fd:num)";
fun WOK_1 () = PT "write_event_ok (Inv:io_event -> bool) 1";
fun front_last (l : term list) : term list * term = (List.take (l, length l - 1), List.last l);
fun stored (thy : string) (nm : string) : term = concl (DB.fetch thy nm);

(* --- helpers --- *)
val WOK_WRITEI = r6w_term "write_event_ok_writei" (fn () => PT
  ("!(Inv:io_event -> bool) (fd:num) (n:num) (i:num) (rest:word8 list). " ^
   "write_event_ok Inv fd /\\ LENGTH rest = 2048 /\\ i + n <= 2048 ==> " ^
   "!nb:word8 list. LENGTH nb = 4 + LENGTH rest /\\ HD nb = 0w ==> " ^
   "Inv (IO_event (ExtCall \194\171write\194\187) (n2w8 fd) (ZIP (n2w2 n ++ n2w2 i ++ rest, nb)))"));
val WOK_REFUND = r6w_term "write_event_ok_refund" (fn () => PT "write_event_ok refund_valid_event 1");
(* copy of TextIOProofScript.sml SEG_APPEND3 (local there, so not in the theory) *)
val SEG3 = r6w_term "SEG_APPEND3_W" (fn () => PT
  ("!len off z (l:'a list). len + off <= z /\\ z <= LENGTH l ==> " ^
   "SEG len off l ++ SEG (z - (off + len)) (off + len) l = SEG (z - off) off l"));
val FFIIN = r6w_term "IOxV_FFI_part_IN" (fn () => PT
  ("!(Inv:io_event -> bool) fs (H:hprop) h. (IOxV Inv fs * H) h ==> " ^
   "?ev. FFI_part (fsFFI$encode fs) (mk_ffi_next fs_ffi_part) (MAP FST (SND (SND fs_ffi_part))) ev IN h"));
val UNIQ = r6w_term "UNIQUE_IOFS_V" (fn () => PT
  ("!s. VALID_HEAP s ==> !(Inv1:io_event -> bool) (Inv2:io_event -> bool) fs1 fs2 (H1:hprop) (H2:hprop). " ^
   "(IOFS_V Inv1 fs1 * H1) s /\\ (IOFS_V Inv2 fs2 * H2) s ==> fs1 = fs2"));
val HINJ = r6w_term "IOFS_V_HPROP_INJ" (fn () => PT
  "!(Inv:io_event -> bool) fs1 fs2. HPROP_INJ (IOFS_V Inv fs1) (IOFS_V Inv fs2) (fs2 = fs1)");
val NUMCH = r6w_term "STDIO_V_numchars" (fn () => PT
  "!(Inv:io_event -> bool) fs x. STDIO_V Inv (fs with numchars := x) = STDIO_V Inv fs");
val USTDIO = r6w_term "UNIQUE_STDIO_V" (fn () => PT
  ("!s. VALID_HEAP s ==> !fs1 fs2 (Inv:io_event -> bool) (H1:hprop) (H2:hprop). " ^
   "(STDIO_V Inv fs1 * H1) s /\\ (STDIO_V Inv fs2 * H2) s ==> " ^
   "fs1.infds = fs2.infds /\\ fs1.files = fs2.files /\\ fs1.maxFD = fs2.maxFD /\\ fs1.inode_tbl = fs2.inode_tbl"));
val SHINJ = r6w_term "STDIO_V_HPROP_INJ" (fn () => PT
  ("!(Inv:io_event -> bool) fs1 fs2. HPROP_INJ (STDIO_V Inv fs1) (STDIO_V Inv fs2) " ^
   "(fs1.infds = fs2.infds /\\ fs1.files = fs2.files /\\ fs1.maxFD = fs2.maxFD /\\ fs1.inode_tbl = fs2.inode_tbl)"));
val FD0 = r6w_term "STD_streams_fd0" (fn () => PT
  "!fs. wfFS fs /\\ STD_streams fs ==> get_fd_content fs 0 <> NONE /\\ get_mode fs 0 = SOME ReadMode");

(* --- specifications, by term surgery on the STORED specs --- *)
(* writei_spec_W: writei_spec_V (stored, R6ffi-0002) with its last hypothesis H_inv replaced by
   LENGTH rest = 2048 and write_event_ok Inv fd (a corollary; callers can discharge both from assumptions). *)
val WRITEI_W = r6w_term "writei_spec_W" (fn () =>
  let val (hs, c) = strip_imp (concl WRITEI_V_TH)
      val (hs0, hinv) = front_last hs
      val _ = if is_forall hinv then () else raise mk_HOL_ERR "r6w_common" "WRITEI_W" "last hypothesis is not H_inv"
  in list_mk_imp (hs0 @ [LEN_REST (), WOK_FD ()], c) end);
(* write_spec_V: write_spec (TextIOProofScript.sml 1554-1566); IOx fs_ffi_part := IOxV Inv, IOFS := IOFS_V Inv;
   two hypotheses added last: LENGTH rest = 2048 (IOFS_V pins the iobuff to 2052 bytes) and write_event_ok Inv fd *)
val WRITE_V = r6w_term "write_spec_V" (fn () =>
  let val (vs, body) = strip_forall (stored "TextIOProof" "write_spec")
      val (hs, c) = strip_imp body
  in list_mk_forall (vs, list_mk_imp (hs @ [LEN_REST (), WOK_FD ()],
       subst [IOX_FS () |-> IOXV_INV (), IOFS_C () |-> IOFS_V_INV ()] c)) end);
(* output_aux_spec_V: output_aux_spec (1730-1742); IOFS := IOFS_V Inv; conjunct write_event_ok Inv fd added last *)
val OUTPUT_AUX_V = r6w_term "output_aux_spec_V" (fn () =>
  let val (vs, body) = strip_forall (stored "TextIOProof" "output_aux_spec")
      val (a, c) = dest_imp body
  in list_mk_forall (vs, mk_imp (list_mk_conj (strip_conj a @ [WOK_FD ()]),
       subst [IOFS_C () |-> IOFS_V_INV ()] c)) end);
(* output_spec_V: output_spec (1817-1825); hypothesis write_event_ok Inv fd added last *)
val OUTPUT_V = r6w_term "output_spec_V" (fn () =>
  let val (vs, body) = strip_forall (stored "TextIOProof" "output_spec")
      val (hs, c) = strip_imp body
  in list_mk_forall (vs, list_mk_imp (hs @ [WOK_FD ()], subst [IOFS_C () |-> IOFS_V_INV ()] c)) end);
(* output_STDIO_spec_V: output_STDIO_spec (1838-1843); STDIO := STDIO_V Inv; conjunct write_event_ok Inv fd added last *)
val OUTPUT_STDIO_V = r6w_term "output_STDIO_spec_V" (fn () =>
  let val (vs, body) = strip_forall (stored "TextIOProof" "output_STDIO_spec")
      val (a, c) = dest_imp body
  in list_mk_forall (vs, mk_imp (list_mk_conj (strip_conj a @ [WOK_FD ()]),
       subst [STDIO_C () |-> STDIO_V_INV ()] c)) end);
(* print_spec_V: print_spec (1868-1873); STDIO := STDIO_V Inv; hypothesis write_event_ok Inv 1 added last *)
val PRINT_V = r6w_term "print_spec_V" (fn () =>
  let val (vs, body) = strip_forall (stored "TextIOProof" "print_spec")
      val (hs, c) = strip_imp body
  in list_mk_forall (vs, list_mk_imp (hs @ [WOK_1 ()], subst [STDIO_C () |-> STDIO_V_INV ()] c)) end);
(* print_spec_refund: print_spec with STDIO := STDIO_V refund_valid_event; no added hypothesis *)
val PRINT_R = r6w_term "print_spec_refund" (fn () =>
  let val (vs, body) = strip_forall (stored "TextIOProof" "print_spec")
      val (hs, c) = strip_imp body
  in list_mk_forall (vs, list_mk_imp (hs, subst [STDIO_C () |-> PT "STDIO_V refund_valid_event"] c)) end);

(* full statements, printed without depth limit (Orchestrator A note: depth 60 elides them) *)
val _ =
  let val d = !Globals.max_print_depth
  in Globals.max_print_depth := ~1;
     List.app (fn (n, t) => pr ("STATEMENT " ^ n ^ "\n" ^ term_to_string t))
       [("write_event_ok_writei", WOK_WRITEI), ("write_event_ok_refund", WOK_REFUND), ("SEG_APPEND3_W", SEG3),
        ("IOxV_FFI_part_IN", FFIIN), ("UNIQUE_IOFS_V", UNIQ), ("IOFS_V_HPROP_INJ", HINJ),
        ("STDIO_V_numchars", NUMCH), ("UNIQUE_STDIO_V", USTDIO), ("STDIO_V_HPROP_INJ", SHINJ),
        ("STD_streams_fd0", FD0), ("writei_spec_W", WRITEI_W), ("write_spec_V", WRITE_V),
        ("output_aux_spec_V", OUTPUT_AUX_V), ("output_spec_V", OUTPUT_V),
        ("output_STDIO_spec_V", OUTPUT_STDIO_V), ("print_spec_V", PRINT_V), ("print_spec_refund", PRINT_R)];
     Globals.max_print_depth := d
  end;
