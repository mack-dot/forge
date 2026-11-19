(* round14 (worker W-top): MAINV and INITV are parsed through parse_free (below); the reason is in CHANGES.txt (C2).
   The intended statements do not change. Nothing else in this file changed. UNCHECKED. *)
(* r6t_common.sml (worker A36, round 11). NOT RUN as a file. Shared by R6tx-0001.sml (exploration) and R6t-0001.sml (proof);
   both read it with use AFTER new_theory and AFTER the theories of deps-R6t.txt are loaded (forge_refundR6Write and its
   ancestors forge_refundR6Ffi, forge_refundR6Base, forge_refundRouteA2c).
   The caller must define: pr, trunc, fth, showg, tlim, R6T_PROOF_MODE : bool.
   Contents: the grammar fix (round9/r6w_common.sml lines 9-38, byte-identical), theorem shortcuts, the theorem table TH
   and the replay function (round9/r6w_common.sml lines 64-98; names R6W -> R6T, A33 -> A36), and all statements.
   NO new definition. Statements that need the main-call program text take it by term surgery from the STORED theorem
   basis_ffi.whole_prog_spec_semantics_prog (basis_ffiScript.sml 634-662). Every tactic UNCHECKED. ASCII only. *)
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

(* ================= theorem shortcuts (parents forge_refundR6Ffi, forge_refundR6Base) ================= *)
val _ = pr "MARK SHORTCUTS";
val IOxV_def = fth "forge_refundR6Ffi" "IOxV_def";
val IOFS_V_def = fth "forge_refundR6Ffi" "IOFS_V_def";
val STDIO_V_def = fth "forge_refundR6Ffi" "STDIO_V_def";
val IOFS_V_HPROP_TH = fth "forge_refundR6Ffi" "IOFS_V_FFI_part_hprop";
val EOTP_TH = fth "forge_refundR6Base" "every_of_three_parts";
val WPS_TH = fth "basis_ffi" "whole_prog_spec_semantics_prog";

(* ================= theorem table: prerequisites by name ================= *)
(* Proof mode: filled by save after each stored lemma. Exploration: filled first with ASSUME of each statement
   (so each lemma is explored independently), then replaced by real theorems where a helper proof closes. *)
val R6T_TH = ref ([] : (string * thm) list);
fun TH (nm : string) : thm =
  case List.find (fn (n, _) => n = nm) (!R6T_TH) of
    SOME (_, th) => th
  | NONE => raise mk_HOL_ERR "r6t_common" "TH" ("no theorem " ^ nm);
fun set_TH (nm : string) (th : thm) : unit =
  R6T_TH := (nm, th) :: List.filter (fn (n, _) => n <> nm) (!R6T_TH);
(* LATE f: build the tactic only when it runs, so TH is read at run time, not at use time *)
fun LATE (f : unit -> tactic) : tactic = fn g => f () g;

(* ================= replay (round5/r6_prove.sml step_tac and head_replay; names A30 -> A33 -> A36) ================= *)
val STEP_LIMIT = 240;
fun step_tac (lemma : string) (i : int) ((label, t, alts) : string * tactic * tactic list) : tactic =
  fn (g : goal) => fn (ctxt : Context.t) =>
    let
      fun go (_ : int) ([] : tactic list) =
            (showg ("STEP_ALL_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label) g;
             raise mk_HOL_ERR "A36" "step_tac" ("all candidates failed at " ^ lemma ^ " step " ^ Int.toString i))
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
fun r6t_term (name : string) (f : unit -> term) : term =
  f () handle e => (pr ("STATEMENT_PARSE_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e));
                    if R6T_PROOF_MODE then raise e else T);
fun PT (s : string) : term = Parse.Term [QUOTE s];
(* close_over: quantify a parsed body over its free variables in the given order; any other free variable is an error *)
fun close_over (names : string list) (body : term) : term =
  let val fvs = free_vars body
      fun get (n : string) : term =
        case List.find (fn v => fst (dest_var v) = n) fvs of
          SOME v => v
        | NONE => raise mk_HOL_ERR "r6t_common" "close_over" ("no free variable " ^ n)
      val vs = map get names
      val left = List.filter (fn v => not (op_mem aconv v vs)) fvs
  in if null left then list_mk_forall (vs, body)
     else raise mk_HOL_ERR "r6t_common" "close_over"
                  ("free variables left: " ^ String.concatWith " " (map (fst o dest_var) left))
  end;
(* text pieces (all statements use these; ASCII only) *)
val ST_TY = "(mlstring list # IO_fs) semanticPrimitives$state";
val BP = "(basis_proj1,basis_proj2)";
val CL_NS = "(MAP FST (SND (SND cl_ffi_part)))";
val FS_NS = "(MAP FST (SND (SND fs_ffi_part)))";
val RT_NS = "(MAP FST (SND (SND runtime_ffi_part)))";
fun XFS (ev : string) : string = "FFI_part (fsFFI$encode fs) (mk_ffi_next fs_ffi_part) " ^ FS_NS ^ " " ^ ev;
val XCL = "FFI_part (clFFI$encode cl) (mk_ffi_next cl_ffi_part) " ^ CL_NS ^ " []";
val XRT = "FFI_part (runtimeFFI$encode ()) (mk_ffi_next runtime_ffi_part) " ^ RT_NS ^ " []";
fun FHI (ns : string) : string = "cfStore$ffi_has_index_in " ^ ns;
val APP_V = "cfApp$app " ^ BP ^ " fv [Conv NONE []] (STDIO_V Inv fs) (POSTv uv. &UNIT_TYPE () uv * STDIO_V Inv fs')";
val EVERY_LAM = "(\\behavior. ?io_events. behavior = Terminate Success io_events /\\ EVERY Inv io_events)";

(* ---- surgery on basis_ffi.whole_prog_spec_semantics_prog (basis_ffiScript.sml 634-662):
   !fname fv. Decls env1 (init_state (basis_ffi ext cl fs) with eval_state := es) prog env2 st2 ==>
   lookup_var fname env2 = SOME fv ==> whole_prog_spec ... ==> (?h1 h2. ...) ==>
   sem_satisfies (semantics_dec_list (init_state ...) env1 (SNOC main_call prog)) (...) ---- *)
fun wps_parts () : term * term * term =
  let val (hs, c) = strip_imp (snd (strip_forall (concl WPS_TH)))
  in (List.nth (hs, 0), List.nth (hs, 1), rand (rator c)) end;
val _ = (let val (d, l, s) = wps_parts () in
           pr ("SURGERY_DECLS " ^ term_to_string d);
           pr ("SURGERY_LOOKUP " ^ term_to_string l);
           pr ("SURGERY_SEM " ^ term_to_string s);
           pr ("SURGERY_FREE " ^ String.concatWith " " (map (fst o dest_var) (free_varsl [d, l, s])))
         end) handle e => pr ("SURGERY_FAILED " ^ trunc 400 (General.exnMessage e));

(* ---- (c) INITIAL HEAP ---- *)
(* T1: copy of the inner parts_ok proof of IMP_STDIO_general (basis_ffiScript.sml 871-948, local there) *)
val PARTS = r6t_term "parts_ok_basis_ffi" (fn () => PT
  ("!(st:" ^ ST_TY ^ ") ext cl fs. st.ffi = basis_ffi ext cl fs ==> cfStore$parts_ok st.ffi " ^ BP));
(* T2: the three FFI parts of the initial heap, each with the EMPTY event list (ffi2heap_def, cfStoreScript.sml 49-59;
   basis_ffi_def io_events := [], basis_ffiScript.sml 94-99) *)
val FSIN = r6t_term "init_fs_part_IN" (fn () => PT
  ("!(st:" ^ ST_TY ^ ") ext cl fs. st.ffi = basis_ffi ext cl fs ==> " ^ XFS "[]" ^ " IN cfStore$st2heap " ^ BP ^ " st"));
val CLIN = r6t_term "init_cl_part_IN" (fn () => PT
  ("!(st:" ^ ST_TY ^ ") ext cl fs. st.ffi = basis_ffi ext cl fs ==> " ^ XCL ^ " IN cfStore$st2heap " ^ BP ^ " st"));
val RTIN = r6t_term "init_rt_part_IN" (fn () => PT
  ("!(st:" ^ ST_TY ^ ") ext cl fs. st.ffi = basis_ffi ext cl fs ==> " ^ XRT ^ " IN cfStore$st2heap " ^ BP ^ " st"));
(* T3: the iobuff cell (second reference; iobuff_loc = Loc T 1, basis_ffiScript.sml 847-852) *)
val IOBIN = r6t_term "init_iobuff_IN" (fn () => PT
  ("!(st:" ^ ST_TY ^ ") bs1 bs2 rest. st.refs = W8array bs1 :: W8array bs2 :: rest ==> " ^
   "Mem 1 (W8array bs2) IN cfStore$st2heap " ^ BP ^ " st"));
(* T4: V-form of IOFS_precond (basis_ffiScript.sml 495-505): events visible, iobuff EXACTLY 2052 bytes *)
val IOFSI = r6t_term "IOFS_V_init" (fn () => PT
  ("!(Inv:io_event -> bool) fs (v:word8 list) (events:io_event list). " ^
   "wfFS fs /\\ LENGTH v = 2052 /\\ EVERY Inv events ==> " ^
   "IOFS_V Inv fs ({" ^ XFS "events" ^ "} UNION {Mem 1 (W8array v)})"));
(* T5: STDIO_V from IOFS_V (numchars := fs.numchars; fsFFIScript.sml 97 with_same_numchars) *)
val STDOF = r6t_term "STDIO_V_of_IOFS_V" (fn () => PT
  "!(Inv:io_event -> bool) fs h. STD_streams fs /\\ IOFS_V Inv fs h ==> STDIO_V Inv fs h");
(* T6 = deliverable (c). V-form of IMP_STDIO (basis_ffiScript.sml 950-961, local there). is_refs_basis
   (854-858: 2052 <= LENGTH bs2) is replaced by the exact LENGTH bs2 = 2052 that IOFS_V pins; the command-line and the
   runtime FFI parts with EMPTY event lists are put in the FRAME h2 (not in the precondition). *)
val INITH = r6t_term "init_heap_V" (fn () => PT
  ("!(Inv:io_event -> bool) (st:" ^ ST_TY ^ ") ext cl fs bs1 bs2 rest. " ^
   "st.ffi = basis_ffi ext cl fs /\\ st.refs = W8array bs1 :: W8array bs2 :: rest /\\ LENGTH bs2 = 2052 /\\ " ^
   "wfFS fs /\\ STD_streams fs ==> " ^
   "?h1 h2. SPLIT (cfStore$st2heap " ^ BP ^ " st) (h1,h2) /\\ STDIO_V Inv fs h1 /\\ " ^
   XCL ^ " IN h2 /\\ " ^ XRT ^ " IN h2"));

(* ---- (d) EVENT LINK ---- *)
(* D1: FFI_part_IN_st2heap_IMP (cfDivScript.sml 3747-3755) plus parts_ok *)
val FILT = r6t_term "FFI_part_IN_st2heap_FILTER" (fn () => PT
  ("!p st s u ns events. FFI_part s u ns events IN cfStore$st2heap p st ==> " ^
   "cfStore$parts_ok st.ffi p /\\ FILTER (" ^ FHI "ns" ^ ") st.ffi.io_events = events"));
(* D2: the names of basis_proj2 (basis_ffiScript.sml 116-121) *)
val NAMES = r6t_term "basis_proj2_names" (fn () => PT
  ("FLAT (MAP FST basis_proj2) = " ^ CL_NS ^ " ++ " ^ FS_NS ^ " ++ " ^ RT_NS));
(* D3: every event is valid when the fs part's events are valid and the other two parts have none *)
val EVB = r6t_term "every_basis_events" (fn () => PT
  ("!(Inv:io_event -> bool) f. cfStore$parts_ok f " ^ BP ^ " /\\ " ^
   "FILTER (" ^ FHI CL_NS ^ ") f.io_events = [] /\\ FILTER (" ^ FHI RT_NS ^ ") f.io_events = [] /\\ " ^
   "EVERY Inv (FILTER (" ^ FHI FS_NS ^ ") f.io_events) ==> EVERY Inv f.io_events"));
(* D5: copy of sem_satisfies_imp (basis_ffiScript.sml 569-575, local there) *)
val SEMIMP = r6t_term "sem_satisfies_imp_V" (fn () => PT
  "!s P Q. sem_satisfies s P ==> (!b. P b ==> Q b) ==> sem_satisfies s Q");
(* D0: V-form of the FFI_part_hprop step of whole_prog_spec2_semantics_prog (basis_ffiScript.sml 600-608) *)
val SHPROP = r6t_term "STDIO_V_FFI_part_hprop" (fn () => PT
  "!(Inv:io_event -> bool) fs. FFI_part_hprop (STDIO_V Inv fs)");
(* IOxV_FFI_part_IN (R6w-0004) with the event invariant kept *)
val IOXEV = r6t_term "IOxV_events_IN" (fn () => PT
  ("!(Inv:io_event -> bool) fs (H:hprop) h. (IOxV Inv fs * H) h ==> ?ev. " ^ XFS "ev" ^ " IN h /\\ EVERY Inv ev"));
val SEV = r6t_term "STDIO_V_events" (fn () => PT
  ("!(Inv:io_event -> bool) fs h. STDIO_V Inv fs h ==> ?s u ev. FFI_part s u " ^ FS_NS ^ " ev IN h /\\ EVERY Inv ev"));
(* D6: the final heap of call_main_thm2 (cfMainScript.sml 260-285): SPLIT3 (st2heap st3) (h3,h2,h4) keeps the frame h2 *)
val FINAL = r6t_term "final_heap_events" (fn () => PT
  ("!(Inv:io_event -> bool) fs' (st3:" ^ ST_TY ^ ") h2 h3 h4 s1 u1 s3 u3. " ^
   "SPLIT3 (cfStore$st2heap " ^ BP ^ " st3) (h3,h2,h4) /\\ STDIO_V Inv fs' h3 /\\ " ^
   "FFI_part s1 u1 " ^ CL_NS ^ " [] IN h2 /\\ FFI_part s3 u3 " ^ RT_NS ^ " [] IN h2 ==> EVERY Inv st3.ffi.io_events"));
(* round14 parse_free: R6tx-0001 stdout 51-52: STATEMENT_PARSE_FAILED for MAINV and INITV, because the text name "fv"
   parses as a CONSTANT of this heap (type num -> closLang$exp list -> bool), not as the variable fv : v of the
   antiquoted lookup_var term. parse_free parses the quotation as the body of a lambda over the given names (a bound
   name is always a variable), then removes exactly these lambdas. A bound name that is the same name and type as a free
   variable of an antiquoted term is the same variable after the lambdas are removed (as without the lambda). *)
fun parse_free (ns : string list) (q : term frag list) : term =
  let val t = Parse.Term (QUOTE ("(\\" ^ String.concatWith " " ns ^ ". ") :: q @ [QUOTE ")"])
      fun strip 0 x = x
        | strip k x = strip (k - 1) (snd (dest_abs x))
  in strip (length ns) t end;
(* names of the text parts of MAINV/INITV that are also constants in this heap (diagnostic only) *)
val _ = List.app (fn n => case Term.decls n of
                            [] => ()
                          | cs => pr ("NAME_IS_CONST " ^ n ^ " " ^ String.concatWith " "
                                        (map (fn c => #Thy (dest_thy_const c)) cs)))
          ["Inv", "fv", "fs", "fs'", "st2", "h1", "h2", "s1", "u1", "s3", "u3", "ext", "cl", "bs1", "bs2", "rest", "uv"];
(* D4 = deliverable (d). Mirror of whole_prog_spec_semantics_prog with STDIO_V and the frame parts *)
val MAINV = r6t_term "whole_prog_spec_V_events" (fn () =>
  let val (d, l, s) = wps_parts ()
      val body = parse_free ["Inv", "fv", "fs", "fs'", "st2", "h1", "h2", "s1", "u1", "s3", "u3"] [QUOTE "", ANTIQUOTE d, QUOTE " /\\ ", ANTIQUOTE l,
        QUOTE (" /\\ " ^ APP_V ^ " /\\ SPLIT (cfStore$st2heap " ^ BP ^ " st2) (h1,h2) /\\ STDIO_V Inv fs h1 /\\ " ^
               "FFI_part s1 u1 " ^ CL_NS ^ " [] IN h2 /\\ FFI_part s3 u3 " ^ RT_NS ^ " [] IN h2 ==> sem_satisfies "),
        ANTIQUOTE s, QUOTE (" " ^ EVERY_LAM)]
  in close_over ["Inv", "fv", "fs", "fs'", "ext", "cl", "es", "env1", "prog", "env2", "st2", "fname",
                 "h1", "h2", "s1", "u1", "s3", "u3"] body end);
(* T7 (composite, optional): (c) + (d) *)
val INITV = r6t_term "whole_prog_spec_V_init" (fn () =>
  let val (d, l, s) = wps_parts ()
      val body = parse_free ["Inv", "fv", "fs", "fs'", "st2", "ext", "cl", "bs1", "bs2", "rest"] [QUOTE "", ANTIQUOTE d, QUOTE " /\\ ", ANTIQUOTE l,
        QUOTE (" /\\ st2.ffi = basis_ffi ext cl fs /\\ st2.refs = W8array bs1 :: W8array bs2 :: rest /\\ " ^
               "LENGTH bs2 = 2052 /\\ wfFS fs /\\ STD_streams fs /\\ " ^ APP_V ^ " ==> sem_satisfies "),
        ANTIQUOTE s, QUOTE (" " ^ EVERY_LAM)]
  in close_over ["Inv", "fv", "fs", "fs'", "ext", "cl", "es", "env1", "prog", "env2", "st2", "fname",
                 "bs1", "bs2", "rest"] body end);

(* full statements, printed without depth limit; then the theory of selected constants in each statement *)
val R6T_STATEMENTS =
  [("parts_ok_basis_ffi", PARTS), ("init_fs_part_IN", FSIN), ("init_cl_part_IN", CLIN), ("init_rt_part_IN", RTIN),
   ("init_iobuff_IN", IOBIN), ("IOFS_V_init", IOFSI), ("STDIO_V_of_IOFS_V", STDOF), ("init_heap_V", INITH),
   ("FFI_part_IN_st2heap_FILTER", FILT), ("basis_proj2_names", NAMES), ("every_basis_events", EVB),
   ("sem_satisfies_imp_V", SEMIMP), ("STDIO_V_FFI_part_hprop", SHPROP), ("IOxV_events_IN", IOXEV),
   ("STDIO_V_events", SEV), ("final_heap_events", FINAL), ("whole_prog_spec_V_events", MAINV),
   ("whole_prog_spec_V_init", INITV)];
val WATCH = ["encode", "st2heap", "parts_ok", "ffi_has_index_in", "app", "Terminate", "Success", "Dlet", "Var",
             "Short", "Con", "Conv", "SPLIT", "SPLIT3", "sem_satisfies", "semantics_dec_list", "init_state", "Decls"];
fun const_report (n : string, t : term) : unit =
  let val cs = op_mk_set aconv (find_terms (fn x => is_const x andalso Lib.mem (fst (dest_const x)) WATCH) t)
  in List.app (fn c => let val {Thy = thy, Name = nm, ...} = dest_thy_const c
                       in pr ("CONST " ^ n ^ " " ^ thy ^ "$" ^ nm) end) cs end;
val _ =
  let val d = !Globals.max_print_depth
  in Globals.max_print_depth := ~1;
     List.app (fn (n, t) => pr ("STATEMENT " ^ n ^ "\n" ^ term_to_string t)) R6T_STATEMENTS;
     Globals.max_print_depth := d;
     List.app const_report R6T_STATEMENTS
  end;
