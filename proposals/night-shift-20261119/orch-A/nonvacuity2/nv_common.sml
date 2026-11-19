(* nv_common.sml (worker W-nv, Night-Shift Orchestrator A). NOT RUN. Every line UNCHECKED by HOL. ASCII only.
   Shared by NVx-0001.sml (exploration) and NV-0001.sml (proof); both read it with use AFTER new_theory.
   The caller must define: pr, trunc, fth, showg, tlim, guarded_apply, NV_PROOF_MODE.
   Parents (loaded by the runner, deps-NV.txt = deps-MG.txt + forge_refundRouteA2d (L2d-0001) + forge_refundInputSat
   (round4 fs-r4-0001)). Every statement is BUILT FROM STORED THEOREMS (DB.fetch / concl / dest_imp / strip_conj / subst);
   no constant name is parsed (two constants are named arm8_run).
   nonvacuity2 copy (worker W-nv2): see CHANGES.txt C1-C6. Callers are NVx-0003.sml and NV-0003.sml. *)
val _ = pr "MARK COMMON";
type step = string * tactic * tactic list;
fun nv_tmem (x : term) (l : term list) : bool = List.exists (fn y => aconv x y) l;
fun head_name (t : term) : string =
  let val (f, _) = strip_comb t in if is_const f then fst (dest_const f) else "" end;
fun args_of (t : term) : term list = snd (strip_comb t);
(* C2: REQUIRED item: a construction failure is FATAL (marker REQUIRED_STATEMENT_FAILED, then raise).
       OPTIONAL item: a construction failure is NOT fatal (marker OPTIONAL_STATEMENT_FAILED; the value is NONE and
       every optional item that depends on it is also NONE). *)
fun nv_stmt (name : string) (f : unit -> 'a) : 'a =
  f () handle e => (pr ("STATEMENT_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e));
                    pr ("REQUIRED_STATEMENT_FAILED " ^ name ^ " (fatal)");
                    raise Fail ("required statement item failed: " ^ name ^ ": " ^ trunc 300 (General.exnMessage e)));
fun nv_opt (name : string) (f : unit -> 'a) : 'a option =
  SOME (f ()) handle e => (pr ("OPTIONAL_STATEMENT_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e) ^
                               " (not fatal; dependent optional items are skipped)"); NONE);
fun need (name : string) (x : 'a option) : 'a =
  case x of SOME v => v | NONE => raise mk_HOL_ERR "nv_common" "need" ("optional item not available: " ^ name);
fun nv_control (ok : bool) (msg : string) : unit =
  if ok then pr ("CONTROL_OK " ^ msg)
  else (pr ("CONTROL_FAILED " ^ msg);
        if NV_PROOF_MODE then raise Fail ("control failed: " ^ msg) else ());

(* ================= stored theorems ================= *)
val _ = pr "MARK FETCH";
val SHAPE = fth "forge_refundRouteA2d" "refund_profile_a_sl_shape";
val DEC = fth "forge_refundRouteA2d" "refund_model_frame_decision_shape";
val REM2 = fth "forge_refundRouteA2d" "remaining_premise_met_by_the_abstract_effect";
val JS = fth "forge_refundInputSat" "refund_profile_a_sl_all_premises_satisfiable_at_0x4000";
val NVOLD = fth "forge_refundInputSat" "refund_profile_a_sl_conclusion_holds_for_a_constructed_model_state_at_0x4000";
val SATFS_WF = fth "forge_refundInputSat" "sat_fs_wfFS";
val SATFS_STD = fth "forge_refundInputSat" "sat_fs_STD_streams";
val SATFS_STDIN = fth "forge_refundInputSat" "sat_fs_stdin_content";
val SATCL = fth "forge_refundInputSat" "sat_cl_wfcl";
val WIT = fth "forge_refundSlideSat" "refund_entry_pre_sl_witness_0x4000";
val HEAP_SAT = fth "forge_refundSlideSat" "sat_sl_heap_premises";
val ENV_OK_SL_DEF = fth "forge_refundSlideProfileA" "refund_env_ok_sl_def";
val AT_DEF = fth "forge_refundSlideProfileA" "refund_ffi_contract_at_def";
val ON_DEF = fth "forge_refundRouteA1" "refund_ffi_contract_on_def";
val ENV_DEF = fth "forge_refundEnvModel" "refund_abs_env_def";
val IDOK = fth "forge_refundEnvModel" "refund_id_interfer_ok";
val MST = fth "targetProps" "machine_sem_total";
val _ = List.app (fn (n, th) => pr ("USED " ^ n ^ "\n" ^ thm_to_string th))
  [("refund_env_ok_sl_def", ENV_OK_SL_DEF), ("refund_ffi_contract_at_def", AT_DEF),
   ("refund_ffi_contract_on_def", ON_DEF), ("refund_abs_env_def", ENV_DEF), ("refund_id_interfer_ok", IDOK),
   ("remaining_premise_met_by_the_abstract_effect", REM2), ("machine_sem_total", MST),
   ("refund_profile_a_sl_all_premises_satisfiable_at_0x4000", JS)];

(* ================= terms from the stored theorems ================= *)
val _ = pr "MARK TERMS";
(* the antecedent of refund_profile_a_sl_shape (12 conjuncts; ext does not occur in it) *)
val ANTE = nv_stmt "ANTE" (fn () => fst (dest_imp (snd (strip_forall (concl SHAPE)))));
val DEC_BODY = nv_stmt "DEC_BODY" (fn () => snd (strip_forall (concl DEC)));
val ANTE_DEC = nv_stmt "ANTE_DEC" (fn () => fst (dest_imp DEC_BODY));
val CONCL3 = nv_stmt "CONCL3" (fn () => snd (dest_imp DEC_BODY));
fun var_named (n : string) : term =
  case List.find (fn v => fst (dest_var v) = n) (free_vars ANTE) of
    SOME v => v
  | NONE => raise mk_HOL_ERR "nv_common" "var_named" ("no free variable " ^ n ^ " in the antecedent");
val OTH_NAMES = ["sl", "s", "h", "stk", "e", "envmc", "fs", "cl"];
val REQ_NAMES = ["charge", "request", "original", "remaining", "enabled", "opened", "candidate", "amount", "reason"];
val OTH = nv_stmt "OTH" (fn () => map var_named OTH_NAMES);
val REQ = nv_stmt "REQ" (fn () => map var_named REQ_NAMES);
val slV = el 1 OTH;
val envmcV = el 6 OTH;
val _ = pr ("ANTE_CONJUNCTS " ^ Int.toString (length (strip_conj ANTE)));
val _ = pr ("ANTE_FREE_VARS " ^ String.concatWith " " (map (fst o dest_var) (free_vars ANTE)));
val _ = nv_control (length (free_vars ANTE) = 17) "the antecedent has exactly 17 free variables (8 premise + 9 request)";
val _ = nv_control (aconv ANTE ANTE_DEC)
          "antecedent of refund_profile_a_sl_shape = antecedent of refund_model_frame_decision_shape";
val _ = nv_control (not (List.exists (fn v => fst (dest_var v) = "ext") (free_vars ANTE)))
          "no free ext in the antecedent (ext := no_ext changes nothing in it)";
(* VokS: the third argument of the refund_ffi_contract_on conjunct *)
val VOKS = nv_stmt "VOKS" (fn () =>
  case List.find (fn c => head_name c = "refund_ffi_contract_on") (strip_conj ANTE) of
    SOME c => el 3 (args_of c)
  | NONE => raise mk_HOL_ERR "nv_common" "VOKS" "no refund_ffi_contract_on conjunct");
val _ = pr ("VOKS " ^ term_to_string VOKS);
(* the older witness: JS = ?s h stk e envmc fs cl. refund_entry_pre_sl 16384w s h stk e /\ ... *)
val (JS_VARS, JS_BODY) = strip_exists (concl JS);
val SLV = nv_stmt "SLV" (fn () =>
  let val c = hd (strip_conj JS_BODY)
  in if head_name c = "refund_entry_pre_sl" then hd (args_of c)
     else raise mk_HOL_ERR "nv_common" "SLV" "first conjunct of the old witness is not refund_entry_pre_sl" end);
val _ = pr ("SLIDE_OF_OLD_WITNESS " ^ term_to_string SLV);
val _ = nv_control (length JS_VARS = 7 andalso ListPair.all (fn (a, b) => aconv a b) (JS_VARS, tl OTH))
          "the bound variables of the old witness = s h stk e envmc fs cl of the antecedent (names and types)";
val _ = nv_control (List.all (fn v => nv_tmem v REQ) (free_vars (concl JS)))
          "the free variables of the old witness are request fields of the antecedent";
val WITVALS = SLV :: tl OTH;
(* concrete values (as in fs-r4-0001 proof.sml lines 79-95): WIT gives s h stk e; NVOLD gives envmc, fs, cl *)
val WIT_ARGS = args_of (concl WIT);
val _ = nv_control (length WIT_ARGS = 5 andalso aconv (hd WIT_ARGS) SLV) "the entry witness is at the same slide";
(* C3: the concrete witness terms serve only the OPTIONAL items (NV0, refund_abs_env_fields, controls) *)
val ENV0_O = nv_opt "ENV0" (fn () =>
  find_term (fn t => is_comb t andalso head_name t = "refund_abs_env" andalso length (args_of t) = 1) (concl NVOLD));
val BFFI_O = nv_opt "BFFI" (fn () =>
  find_term (fn t => head_name t = "basis_ffi" andalso length (args_of t) = 3) (concl NVOLD));
val CL0_O = nv_opt "CL0" (fn () => el 2 (args_of (need "BFFI" BFFI_O)));
val FS0_O = nv_opt "FS0" (fn () => el 3 (args_of (need "BFFI" BFFI_O)));
fun pr_opt (tag : string) (x : term option) : unit =
  case x of SOME t => pr (tag ^ " " ^ term_to_string t) | NONE => pr (tag ^ "_UNAVAILABLE");
val _ = pr_opt "WITNESS_ENVMC" ENV0_O;
val _ = pr_opt "WITNESS_FS" FS0_O;
val _ = pr_opt "WITNESS_CL" CL0_O;
(* C1 (root cause of NVx-0002 exit 1): in the pinned HOL a record field selector is the constant
   "recordtype.machine_config.seldef.ffi_interfer" (HOL src/1/TypeBasePure.sml lines 21-22, mk_recordtype_fieldsel;
   targetSemTheory.dat); "machine_config_ffi_interfer" and "ffi_interfer" are only overloads (OO entries). The old
   test (n = fld or suffix "_" ^ fld) never matched, so find_term raised. The test now also accepts the suffix
   "." ^ fld. The fupd constants end in "_fupd" and do not match. *)
fun is_field_name (fld : string) (n : string) : bool =
  n = fld orelse String.isSuffix ("." ^ fld) n orelse String.isSuffix ("_" ^ fld) n;
fun accessor (fld : string) : term =
  find_term (fn t => is_comb t andalso aconv (rand t) envmcV andalso is_const (rator t) andalso
                     is_field_name fld (fst (dest_const (rator t)))) ANTE;
val ACC_FFI_O = nv_opt "ACC_FFI" (fn () => accessor "ffi_interfer");
val ACC_NEXT_O = nv_opt "ACC_NEXT" (fn () => accessor "next_interfer");
val ACC_PROG_O = nv_opt "ACC_PROG" (fn () => accessor "prog_addresses");
val _ = List.app (fn (n, x) => case x of
                    SOME t => pr ("ACCESSOR " ^ n ^ " constant " ^ fst (dest_const (rator t)))
                  | NONE => pr ("ACCESSOR " ^ n ^ " UNAVAILABLE"))
          [("ffi_interfer", ACC_FFI_O), ("next_interfer", ACC_NEXT_O), ("prog_addresses", ACC_PROG_O)];
val ABS_FFI_C_O = nv_opt "ABS_FFI_C" (fn () => el 4 (args_of (snd (strip_forall (concl REM2)))));
val ID_C_O = nv_opt "ID_C" (fn () => hd (args_of (snd (strip_forall (concl IDOK)))));
val AE_O = nv_opt "AE" (fn () => mk_comb (rator (need "ENV0" ENV0_O), envmcV));

(* ================= statements ================= *)
val _ = pr "MARK STATEMENTS";
val L_ATON = "refund_ffi_contract_at_imp_on";
val L_FIELDS = "refund_abs_env_fields";
val L_NV0 = "refund_shape_premises_hold_at_a_constructed_state";
val L_NV1B = "refund_shape_premises_satisfiable_for_every_request";
val L_NV1 = "refund_shape_premises_satisfiable";
val L_NV2 = "refund_shape_run_is_accepted";
(* !Vok b dm ffi_i. refund_ffi_contract_at b dm ffi_i ==> refund_ffi_contract_on b dm Vok ffi_i *)
val ATON_STMT = nv_stmt L_ATON (fn () =>
  let val on_lhs = lhs (snd (strip_forall (concl ON_DEF)))
      val (bV, dmV, vokV, fV) =
        case args_of on_lhs of [a, b, c, d] => (a, b, c, d)
                             | _ => raise mk_HOL_ERR "nv_common" "ATON" "arity of refund_ffi_contract_on"
      val atC = fst (strip_comb (lhs (snd (strip_forall (concl AT_DEF)))))
  in list_mk_forall ([vokV, bV, dmV, fV], mk_imp (list_mk_comb (atC, [bV, dmV, fV]), on_lhs)) end);
(* !envmc. (refund_abs_env envmc).ffi_interfer = refund_abs_ffi /\ .next_interfer = refund_id_interfer and
           .prog_addresses = envmc.prog_addresses *)
(* C4: optional; the statement text is unchanged, only its construction is non-fatal *)
val FIELDS_STMT_O = nv_opt L_FIELDS (fn () =>
  let val AE = need "AE" AE_O
      val ACC_FFI = need "ACC_FFI" ACC_FFI_O
      val ACC_NEXT = need "ACC_NEXT" ACC_NEXT_O
      val ACC_PROG = need "ACC_PROG" ACC_PROG_O
  in
  mk_forall (envmcV, list_mk_conj
    [mk_eq (subst [envmcV |-> AE] ACC_FFI, need "ABS_FFI_C" ABS_FFI_C_O),
     mk_eq (subst [envmcV |-> AE] ACC_NEXT, need "ID_C" ID_C_O),
     mk_eq (subst [envmcV |-> AE] ACC_PROG, ACC_PROG)])
  end);
(* NV0: the antecedent at the CONSTRUCTED state (slide 0x4000, envmc = refund_abs_env (ARB with prog_addresses := ..),
   fs = sat_fs (request text), cl = [strlit "refund"]); the nine request fields stay free (= for every request) *)
val NV0_STMT_O = nv_opt L_NV0 (fn () =>
  subst [slV |-> SLV, el 2 OTH |-> el 2 WIT_ARGS, el 3 OTH |-> el 3 WIT_ARGS, el 4 OTH |-> el 4 WIT_ARGS,
         el 5 OTH |-> el 5 WIT_ARGS, envmcV |-> need "ENV0" ENV0_O, el 7 OTH |-> need "FS0" FS0_O,
         el 8 OTH |-> need "CL0" CL0_O] ANTE);
(* NV1b: for every request, the premise set is jointly satisfiable *)
val NV1B_STMT = nv_stmt L_NV1B (fn () => list_mk_forall (REQ, list_mk_exists (OTH, ANTE)));
(* NV1: the existential closure of the antecedent over ALL its free variables *)
val NV1_STMT = nv_stmt L_NV1 (fn () => list_mk_exists (REQ @ OTH, ANTE));
(* NV2: ?(all). ANTE /\ ?ms. (arm8_run 27 s = SOME ms /\ ms.PC = ..) /\ (?b. machine_sem MC st ms b) and
        !b. machine_sem MC st ms b ==> ?t io. b = Terminate t io /\ FRAME
   built from the conclusion of refund_model_frame_decision_shape; the middle conjunct comes from machine_sem_total *)
val (MSV, NV2_P, NV2_R) = nv_stmt "NV2_PARTS" (fn () =>
  let val (msv, mbody) = dest_exists CONCL3
      val (p, r) = dest_conj mbody
  in (msv, p, r) end);
val NV2_EXM = nv_stmt "NV2_EXM" (fn () =>
  let val (bv, bimp) = dest_forall NV2_R in mk_exists (bv, fst (dest_imp bimp)) end);
val NV2_EXTRA = List.filter (fn v => not (nv_tmem v (free_vars ANTE))) (free_vars CONCL3);
val _ = pr ("NV2_EXTRA_FREE_VARS " ^ String.concatWith " " (map (fst o dest_var) NV2_EXTRA));
val NV2_STMT = nv_stmt L_NV2 (fn () =>
  list_mk_forall (NV2_EXTRA, list_mk_exists (REQ @ OTH,
    mk_conj (ANTE, mk_exists (MSV, mk_conj (NV2_P, mk_conj (NV2_EXM, NV2_R)))))));
val _ = nv_control (aconv (snd (strip_exists NV1_STMT)) ANTE) "NV1 body is the stored antecedent (aconv)";
val _ = nv_control (null (free_vars NV1_STMT)) "NV1 has no free variable";
val _ = nv_control (null (free_vars NV2_STMT)) "NV2 has no free variable";
(* C5: the NV0 controls run only when the optional NV0 statement exists *)
val _ =
  case NV0_STMT_O of
    SOME NV0_STMT =>
      (nv_control (List.all (fn v => nv_tmem v REQ) (free_vars NV0_STMT)) "NV0: only request fields are free";
       nv_control (can (match_term ANTE) NV0_STMT) "NV0 is an instance of the antecedent")
  | NONE => pr "CONTROL_SKIPPED NV0 controls (optional NV0 statement not built)";
val _ =
  let val d = !Globals.max_print_depth
  in Globals.max_print_depth := ~1;
     List.app (fn (n, x) => case x of
                 SOME t => pr ("STATEMENT " ^ n ^ "\n" ^ term_to_string t)
               | NONE => pr ("STATEMENT_UNAVAILABLE " ^ n ^ " (optional)"))
       [(L_ATON, SOME ATON_STMT), (L_FIELDS, FIELDS_STMT_O), (L_NV0, NV0_STMT_O), (L_NV1B, SOME NV1B_STMT),
        (L_NV1, SOME NV1_STMT), (L_NV2, SOME NV2_STMT)];
     Globals.max_print_depth := d
  end;

(* ================= theorem table (round13 r6r_common.sml method) ================= *)
val NV_TH = ref ([] : (string * thm) list);
fun TH (nm : string) : thm =
  case List.find (fn (n, _) => n = nm) (!NV_TH) of
    SOME (_, th) => th
  | NONE => raise mk_HOL_ERR "nv_common" "TH" ("no theorem " ^ nm);
fun set_TH (nm : string) (th : thm) : unit = NV_TH := (nm, th) :: List.filter (fn (n, _) => n <> nm) (!NV_TH);
fun LATE (f : unit -> tactic) : tactic = fn g => f () g;

(* ================= replay (round13 step_tac and head_replay; empty goal list = step skipped) ================= *)
val STEP_LIMIT = 120;
fun step_tac (lemma : string) (i : int) ((label, t, alts) : step) : tactic =
  fn (g : goal) => fn (ctxt : Context.t) =>
    let
      fun go (_ : int) ([] : tactic list) =
            (showg ("STEP_ALL_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label) g;
             raise mk_HOL_ERR "W-nv" "step_tac" ("all candidates failed at " ^ lemma ^ " step " ^ Int.toString i))
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
fun safe_head (lemma : string) (i : int) (s : step) =
  fn gl => fn ctxt =>
    if null gl then (pr ("STEP_SKIPPED_NO_GOAL " ^ lemma ^ " " ^ Int.toString i ^ " " ^ #1 s); (gl, fn thl => thl))
    else HEADGOAL (step_tac lemma i s) gl ctxt;
fun head_replay (lemma : string) (steps : step list) : tactic =
  let fun loop (_ : int) (acc : tactic) [] = acc
        | loop i acc (s :: rest) = loop (i + 1) (Tactical.THEN_LT (acc, safe_head lemma i s)) rest
  in loop 1 ALL_TAC steps end;
val _ = pr "PART_INFO nv_common loaded";
