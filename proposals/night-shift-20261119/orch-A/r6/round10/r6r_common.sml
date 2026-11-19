(* r6r_common.sml (worker A35, round 10). NOT RUN as a file. Shared by R6rx-0001.sml (exploration) and R6r-0001.sml (proof);
   both read it with use AFTER new_theory, with the theories forge_refundR6Ffi (R6ffi-0002) and forge_refundR6Write
   (R6w-0004) loaded by the runner (deps-R6r.txt). The caller must define: pr, trunc, fth, showg, tlim, R6R_PROOF_MODE.
   Base: round9/r6w_common.sml (ran in R6wx-0004 and R6w-0004: exit 0). Kept: the grammar fix (byte-identical lines),
   the theorem table TH, LATE, step_tac, head_replay (names A33 -> A35). NEW: four definitions (read_event_ok and the
   pinned instream predicates), the shortcuts of the parents, the registration of the two parent HPROP_INJ theorems
   as frame theorems (only if absent), and the read-side statements. Every tactic UNCHECKED. ASCII only. *)
(* ================= GRAMMAR (round9/r6w_common.sml lines 10-38, unchanged; it worked: GRAMMAR_FIX B) ================= *)
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

(* ================= DEFINITIONS (NEW) ================= *)
(* read_event_ok Inv fd: Inv accepts every successful read event on descriptor fd whose byte array is
   n2w2 n ++ h3::h4::rest with n = 4096 and LENGTH rest = 4096 (array of 4100 bytes, as made by openStdIn,
   TextIOProgScript.sml 298-305: Word8Array.array (min 65535 (max (4096+4) 1028)) = 4100 bytes; refillBuffer_with_read
   389 asks for (length surplus) - 4 = 4096 bytes). The event text is the H_inv text of read_into_spec_V
   (round5/r6_common.sml line 151), so both parse the same. *)
val _ = pr "MARK DEFS";
fun r6r_define (name : string) (q : string) : thm =
  new_definition (name, Parse.Term [QUOTE q])
  handle e => (pr ("DEFINITION_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e));
               if R6R_PROOF_MODE then raise e else TRUTH);
val read_event_ok_def = r6r_define "read_event_ok_def"
  ("read_event_ok (Inv:io_event -> bool) (fd:num) <=> " ^
   "!(n:num) (h3:word8) (h4:word8) (rest:word8 list) (nb:word8 list). " ^
   "n = 4096 /\\ LENGTH rest = 4096 /\\ LENGTH nb = 4 + LENGTH rest /\\ HD nb = 0w ==> " ^
   "Inv (IO_event (ExtCall \194\171read\194\187) (n2w8 fd) (ZIP (n2w2 n ++ h3::h4::rest, nb)))");
(* INSTREAM_BUFFERED_FD_V: INSTREAM_BUFFERED_FD (TextIOProofScript.sml 1009-1018) with the buffer length PINNED to 4100.
   The standard predicate hides the buffer as an existential bcontent, bounded only (instream_buffered_inv_def 956-968:
   1028 <= LENGTH bcontent < 256**2). Written through INSTREAM_BUFFERED_BL_FD (1020-1029, bcontent is a parameter there),
   so that unfolding both definitions gives the flat shape of INSTREAM_BUFFERED_FD_def plus one pure fact. *)
val INSTREAM_BUFFERED_FD_V_def = r6r_define "INSTREAM_BUFFERED_FD_V_def"
  ("INSTREAM_BUFFERED_FD_V (bactive:word8 list) (fd:num) is = " ^
   "SEP_EXISTS (bcontent:word8 list). INSTREAM_BUFFERED_BL_FD bcontent bactive fd is * &(LENGTH bcontent = 4100)");
(* INSTREAM_STR_V: INSTREAM_STR (5773-5780) with INSTREAM_BUFFERED_FD := INSTREAM_BUFFERED_FD_V. Binder names as in
   the original (read active left), so that copied tactics that name read' still match. *)
val INSTREAM_STR_V_def = r6r_define "INSTREAM_STR_V_def"
  ("INSTREAM_STR_V (fd:num) is (s:string) (fs:IO_fs) = " ^
   "SEP_EXISTS read active left. INSTREAM_BUFFERED_FD_V (MAP (n2w o ORD) active) fd is * " ^
   "&(s = active ++ left /\\ get_fd_content fs fd = SOME (read ++ s, LENGTH read + LENGTH active) /\\ " ^
   "get_mode fs fd = SOME ReadMode)");
(* INSTREAM_STRP_V: INSTREAM_STR' (5811-5819) with INSTREAM_BUFFERED_FD := INSTREAM_BUFFERED_FD_V *)
val INSTREAM_STRP_V_def = r6r_define "INSTREAM_STRP_V_def"
  ("INSTREAM_STRP_V (fd:num) is (s:string) (fs:IO_fs) (non_empty:bool) (is_empty:bool) = " ^
   "SEP_EXISTS read active left. INSTREAM_BUFFERED_FD_V (MAP (n2w o ORD) active) fd is * " ^
   "&(s = active ++ left /\\ (non_empty ==> active <> []) /\\ (is_empty ==> active = []) /\\ " ^
   "get_fd_content fs fd = SOME (read ++ s, LENGTH read + LENGTH active) /\\ get_mode fs fd = SOME ReadMode)");
val _ = List.app (fn th => pr ("DEFINITION " ^ thm_to_string th))
  [read_event_ok_def, INSTREAM_BUFFERED_FD_V_def, INSTREAM_STR_V_def, INSTREAM_STRP_V_def];

(* ================= theorem shortcuts (parents forge_refundR6Ffi, forge_refundR6Write; L2c) ================= *)
val _ = pr "MARK SHORTCUTS";
val IOxV_def = fth "forge_refundR6Ffi" "IOxV_def";
val IOFS_V_def = fth "forge_refundR6Ffi" "IOFS_V_def";
val STDIO_V_def = fth "forge_refundR6Ffi" "STDIO_V_def";
val READ_INTO_V_TH = fth "forge_refundR6Ffi" "read_into_spec_V";
val RVE_def = fth "forge_refundRouteA2c" "refund_valid_event_def";
val IOFS_V_HPROP_INJ = fth "forge_refundR6Write" "IOFS_V_HPROP_INJ";
val STDIO_V_HPROP_INJ = fth "forge_refundR6Write" "STDIO_V_HPROP_INJ";
(* the [hprop_inj] data of forge_refundR6Write (its .dat line 363) is applied on load only if cfLetAutoLib's exporter
   exists then; register the two theorems only if they are absent. export_frame_thms takes "Thy.Name"
   (HOL src/1/ThmSetData.sml toKName lines 17-21); cfLetAutoLib.add_frame_thms is not in the signature. *)
val _ = List.app (fn (nm, th) =>
          (if List.exists (fn t => aconv (concl t) (concl th)) (cfLetAutoLib.get_frame_thms ())
           then pr ("FRAME_THM_PRESENT " ^ nm)
           else (cfLetAutoLib.export_frame_thms ["forge_refundR6Write." ^ nm]; pr ("FRAME_THM_EXPORTED " ^ nm)))
          handle e => pr ("FRAME_THM_FAILED " ^ nm ^ " " ^ trunc 300 (General.exnMessage e)))
        [("IOFS_V_HPROP_INJ", IOFS_V_HPROP_INJ), ("STDIO_V_HPROP_INJ", STDIO_V_HPROP_INJ)];

(* ================= theorem table: prerequisites by name (round9, unchanged) ================= *)
val R6R_TH = ref ([] : (string * thm) list);
fun TH (nm : string) : thm =
  case List.find (fn (n, _) => n = nm) (!R6R_TH) of
    SOME (_, th) => th
  | NONE => raise mk_HOL_ERR "r6r_common" "TH" ("no theorem " ^ nm);
fun set_TH (nm : string) (th : thm) : unit =
  R6R_TH := (nm, th) :: List.filter (fn (n, _) => n <> nm) (!R6R_TH);
(* LATE f: build the tactic only when it runs, so TH is read at run time, not at use time *)
fun LATE (f : unit -> tactic) : tactic = fn g => f () g;

(* ================= replay (round9/r6w_common.sml step_tac and head_replay; names A33 -> A35) ================= *)
val STEP_LIMIT = 240;
fun step_tac (lemma : string) (i : int) ((label, t, alts) : string * tactic * tactic list) : tactic =
  fn (g : goal) => fn (ctxt : Context.t) =>
    let
      fun go (_ : int) ([] : tactic list) =
            (showg ("STEP_ALL_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label) g;
             raise mk_HOL_ERR "A35" "step_tac" ("all candidates failed at " ^ lemma ^ " step " ^ Int.toString i))
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
fun r6r_term (name : string) (f : unit -> term) : term =
  f () handle e => (pr ("STATEMENT_PARSE_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e));
                    if R6R_PROOF_MODE then raise e else T);
fun PT (s : string) : term = Parse.Term [QUOTE s];
fun front_last (l : term list) : term list * term = (List.take (l, length l - 1), List.last l);
fun stored (thy : string) (nm : string) : term = concl (DB.fetch thy nm);
fun ROK_FD () = PT "read_event_ok (Inv:io_event -> bool) (fd:num)";

(* --- helpers --- *)
val ROK_READ_INTO = r6r_term "read_event_ok_read_into" (fn () => PT
  ("!(Inv:io_event -> bool) (fd:num) (n:num) (h3:word8) (h4:word8) (rest:word8 list). " ^
   "read_event_ok Inv fd /\\ n = LENGTH rest /\\ LENGTH rest = 4096 ==> " ^
   "!nb:word8 list. LENGTH nb = 4 + LENGTH rest /\\ HD nb = 0w ==> " ^
   "Inv (IO_event (ExtCall \194\171read\194\187) (n2w8 fd) (ZIP (n2w2 n ++ h3::h4::rest, nb)))"));
val ROK_REFUND = r6r_term "read_event_ok_refund" (fn () => PT "read_event_ok refund_valid_event 0");
(* round9 STD_streams_fd0 (r6w_common.sml line 145), same text; it was removed there after two failures *)
val FD0 = r6r_term "STD_streams_fd0" (fn () => PT
  "!fs. wfFS fs /\\ STD_streams fs ==> get_fd_content fs 0 <> NONE /\\ get_mode fs 0 = SOME ReadMode");
(* copy of INSTREAM_STR'_F_F (TextIOProofScript.sml 5821-5826, [local] there, so not in the theory) *)
val STRP_FF = r6r_term "INSTREAM_STRP_V_F_F" (fn () => PT
  "!(fd:num) is (s:string) (fs:IO_fs). INSTREAM_STRP_V fd is s fs F F = INSTREAM_STR_V fd is s fs");
(* weakening: the pinned predicates imply the standard ones *)
val FDV_IMP = r6r_term "INSTREAM_BUFFERED_FD_V_IMP" (fn () => PT
  "!(bactive:word8 list) (fd:num) is. INSTREAM_BUFFERED_FD_V bactive fd is ==>> INSTREAM_BUFFERED_FD bactive fd is");
val STRV_IMP = r6r_term "INSTREAM_STR_V_IMP" (fn () => PT
  "!(fd:num) is (s:string) (fs:IO_fs). INSTREAM_STR_V fd is s fs ==>> INSTREAM_STR fd is s fs");

(* --- specifications, by term surgery on the STORED specs --- *)
(* read_into_spec_R: read_into_spec_V (stored, R6ffi-0002; TextIOProofScript.sml 2132-2149 + 3 hypotheses) with its last
   hypothesis H_inv replaced by: n = LENGTH rest, LENGTH rest = 4096, read_event_ok Inv fd *)
val READ_INTO_R = r6r_term "read_into_spec_R" (fn () =>
  let val (vs, body) = strip_forall (concl READ_INTO_V_TH)
      val (hs, c) = strip_imp body
      val (hs0, hinv) = front_last hs
      val _ = if is_forall hinv then () else raise mk_HOL_ERR "r6r_common" "READ_INTO_R" "last hypothesis is not H_inv"
      val extra = [PT "n = LENGTH (rest:word8 list)", PT "LENGTH (rest:word8 list) = 4096", ROK_FD ()]
  in list_mk_forall (vs, list_mk_imp (hs0 @ extra, c)) end);
(* refillBuffer_with_read_spec_V: refillBuffer_with_read_spec (2725-2743); IOFS := IOFS_V Inv; two hypotheses added
   last: LENGTH bcontent = 4100 (the pinned buffer) and read_event_ok Inv fd *)
val REFILL_V = r6r_term "refillBuffer_with_read_spec_V" (fn () =>
  let val (vs, body) = strip_forall (stored "TextIOProof" "refillBuffer_with_read_spec")
      val (hs, c) = strip_imp body
      val extra = [PT "LENGTH (bcontent:word8 list) = 4100", ROK_FD ()]
  in list_mk_forall (vs, list_mk_imp (hs @ extra,
       subst [PT "IOFS" |-> PT "IOFS_V (Inv:io_event -> bool)"] c)) end);
(* refillBuffer_with_read_spec_STR_V: refillBuffer_with_read_spec_STR (6824-6831); STDIO := STDIO_V Inv,
   INSTREAM_STR' := INSTREAM_STRP_V; hypothesis read_event_ok Inv fd added *)
val REFILL_STR_V = r6r_term "refillBuffer_with_read_spec_STR_V" (fn () =>
  let val (vs, body) = strip_forall (stored "TextIOProof" "refillBuffer_with_read_spec_STR")
      val strp = prim_mk_const {Thy = "TextIOProof", Name = "INSTREAM_STR'"}
  in list_mk_forall (vs, mk_imp (ROK_FD (),
       subst [PT "STDIO" |-> PT "STDIO_V (Inv:io_event -> bool)", strp |-> PT "INSTREAM_STRP_V"] body)) end);

(* full statements, printed without depth limit *)
val _ =
  let val d = !Globals.max_print_depth
  in Globals.max_print_depth := ~1;
     List.app (fn (n, t) => pr ("STATEMENT " ^ n ^ "\n" ^ term_to_string t))
       [("read_event_ok_read_into", ROK_READ_INTO), ("read_event_ok_refund", ROK_REFUND), ("STD_streams_fd0", FD0),
        ("INSTREAM_STRP_V_F_F", STRP_FF), ("INSTREAM_BUFFERED_FD_V_IMP", FDV_IMP), ("INSTREAM_STR_V_IMP", STRV_IMP),
        ("read_into_spec_R", READ_INTO_R), ("refillBuffer_with_read_spec_V", REFILL_V),
        ("refillBuffer_with_read_spec_STR_V", REFILL_STR_V)];
     Globals.max_print_depth := d
  end;
