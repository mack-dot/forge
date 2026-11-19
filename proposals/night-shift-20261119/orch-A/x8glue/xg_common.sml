(* xg_common.sml (worker W-x8glue, Night-Shift Orchestrator A, 2026-11-19). NOT RUN. Every definition, statement
   builder and control is UNCHECKED by HOL. Read with use by XGx-0001.sml (exploration, scratch theory) and XG-0001.sml
   (proof, theory forge_refundX8Glue), AFTER new_theory. The caller must define: pr, trunc, showg, tlim, XG_PROOF_MODE.
   Parents (loaded by deps-XG.txt; names checked against the .sig files under <case>/.hol/objs):
     forge_refundModelFrame (MF-0002) M3; forge_refundModelFrameTot (MT-0001) MT1; forge_refundRouteA1 (L1-0001);
     forge_refundSlideProfileA (e4-0001) contract_at, env_ok_sl, refund_abs_ffi_contract_at;
     forge_refundEnvModel (env-0005) refund_abs_ffi_def; forge_refundStartupBridge (mc-0001) refund_mc_def;
     forge_refundStartupClause (startup-0002) arm8_fix_def; forge_machineTrace (TR1-0001) the generic trace theory.
   SWITCH: forge_machineTracePrefix (TR2-0001) is used ONLY when deps-XG2.txt loaded it (SWITCH_TR2 on); it then adds
   the OPTIONAL cross-check XG_trace_prefix_TR2. Nothing required depends on it.
   Content: two definitions (refund_trace_guard, refund_trace_env), the statements (text ones and ones BUILT from the
   stored parent theorems, so that no parent constant is retyped), the controls. ASCII only. Quotations as [QUOTE "..."]. *)

fun Q (s : string) : term quotation = [QUOTE s];
fun PT (s : string) : term = Parse.Term [QUOTE s];
fun PTY (s : string) : hol_type = Parse.Type [QUOTE s];
val XG_PROBLEMS = ref ([] : string list);
fun ctl (ok : bool) (msg : string) : unit =
  if ok then pr ("CONTROL_OK " ^ msg)
  else (pr ("CONTROL_FAILED " ^ msg); XG_PROBLEMS := msg :: !XG_PROBLEMS);
fun var_named (n : string) (tm : term) : term =
  case List.find (fn v => fst (dest_var v) = n) (free_vars tm) of
    SOME v => v
  | NONE => raise mk_HOL_ERR "xg_common" "var_named" ("no free variable " ^ n);
fun app_of (n : string) (k : int) (t : term) : bool =
  (let val (f, args) = strip_comb t in is_const f andalso fst (dest_const f) = n andalso length args = k end)
  handle _ => false;
fun has_const (n : string) (tm : term) : bool =
  can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;
fun head_const (th : thm) : term = fst (strip_comb (lhs (snd (strip_forall (concl th)))));

(* ================= PARENTS ================= *)
val _ = pr "MARK PARENTS";
fun MF n = DB.fetch "forge_refundModelFrame" n;
fun MTT n = DB.fetch "forge_refundModelFrameTot" n;
fun RA1 n = DB.fetch "forge_refundRouteA1" n;
fun SPA n = DB.fetch "forge_refundSlideProfileA" n;
fun EM n = DB.fetch "forge_refundEnvModel" n;
fun TRT n = DB.fetch "forge_machineTrace" n;
val M3 = MF "refund_model_frame_meets_exported_contract";
val MT1 = MTT "refund_model_frame_totalised";
val ON_DEF = RA1 "refund_ffi_contract_on_def";
val TOTID = RA1 "refund_ffi_tot_all_valid_is_identity";
val ON_ALL = RA1 "refund_ffi_contract_on_all_valid_is_the_stored_contract";
val AT_DEF = SPA "refund_ffi_contract_at_def";
val OKSL_DEF = SPA "refund_env_ok_sl_def";
val ABS_AT = SPA "refund_abs_ffi_contract_at";
val ABS_DEF = EM "refund_abs_ffi_def";
val MC_DEF = DB.fetch "forge_refundStartupBridge" "refund_mc_def";
val FIX_DEF = DB.fetch "forge_refundStartupClause" "arm8_fix_def";
val CEQ = DB.fetch "targetSem" "machine_config_component_equality";
val EFT = TRT "evaluate_follows_trace";
val TRIO = TRT "trace_io";
val TAFTER = TRT "term_after";
val NIOK = TRT "trace_next_interfer_ok";
val FIGUARD = TRT "trace_ffi_interfer_guard";
val TROK_DEF = TRT "trace_ok_def";
val BFFI_DEF = DB.fetch "basis_ffi" "basis_ffi_def"
  handle e => (pr ("FETCH_FAILED basis_ffi.basis_ffi_def " ^ trunc 200 (General.exnMessage e)); TRUTH);
val HAVE_TR2 = can (DB.fetch "forge_machineTracePrefix") "trace_terminate";
val TERM2 = if HAVE_TR2 then DB.fetch "forge_machineTracePrefix" "trace_terminate" else TRUTH;
val _ = pr ("SWITCH_TR2 " ^ (if HAVE_TR2 then "on (forge_machineTracePrefix loaded)" else "off"));
val _ =
  let val d = !Globals.max_print_depth
  in Globals.max_print_depth := ~1;
     List.app (fn (n, th) => pr ("USED " ^ n ^ "\n" ^ thm_to_string th))
       [("refund_model_frame_meets_exported_contract", M3), ("refund_model_frame_totalised", MT1),
        ("refund_ffi_contract_on_def", ON_DEF), ("refund_ffi_tot_all_valid_is_identity", TOTID),
        ("refund_ffi_contract_on_all_valid_is_the_stored_contract", ON_ALL),
        ("refund_ffi_contract_at_def", AT_DEF), ("refund_env_ok_sl_def", OKSL_DEF),
        ("refund_abs_ffi_contract_at", ABS_AT), ("refund_abs_ffi_def", ABS_DEF), ("refund_mc_def", MC_DEF),
        ("arm8_fix_def", FIX_DEF), ("evaluate_follows_trace", EFT), ("trace_io", TRIO), ("term_after", TAFTER),
        ("trace_next_interfer_ok", NIOK), ("trace_ffi_interfer_guard", FIGUARD), ("basis_ffi_def", BFFI_DEF),
        ("trace_terminate (switch)", TERM2)];
     Globals.max_print_depth := d
  end;
type step = string * tactic * tactic list;
(* tr_common2.sml lines 161-190, byte-identical copy *)
(* ================= theorem table, replay (round13/r6r_common.sml, unchanged except names) ================= *)
val TR_TH = ref ([] : (string * thm) list);
fun TH (nm : string) : thm =
  case List.find (fn (n, _) => n = nm) (!TR_TH) of
    SOME (_, th) => th
  | NONE => raise mk_HOL_ERR "tr_common" "TH" ("no theorem " ^ nm);
fun set_TH (nm : string) (th : thm) : unit =
  TR_TH := (nm, th) :: List.filter (fn (n, _) => n <> nm) (!TR_TH);
fun LATE (f : unit -> tactic) : tactic = fn g => f () g;
val STEP_LIMIT = 240;
fun step_tac (lemma : string) (i : int) ((label, t, alts) : string * tactic * tactic list) : tactic =
  fn (g : goal) => fn (ctxt : Context.t) =>
    let
      fun go (_ : int) ([] : tactic list) =
            (showg ("STEP_ALL_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label) g;
             raise mk_HOL_ERR "WTR" "step_tac" ("all candidates failed at " ^ lemma ^ " step " ^ Int.toString i))
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

(* ================= PIECES OF M3 (MF-0002), read from the stored theorem ================= *)
val _ = pr "MARK PIECES";
val envv = var_named "envmc" (concl M3);
val mcty = type_of envv;
val (M3A, M3C) = dest_imp (concl M3);
val M3cs = strip_conj M3A;
val progc = valOf (List.find (fn c => is_eq c andalso free_in envv c) M3cs);
val dmT = rhs progc;                                        (* refund_mem_dm_sl sl h e *)
val newA = List.filter (fn c => not (free_in envv c)) M3cs;
val _ = ctl (length M3cs = 11 andalso length newA = 9)
            ("M3 antecedent has 11 conjuncts, 9 of them free of envmc (found " ^ Int.toString (length M3cs) ^
             " and " ^ Int.toString (length newA) ^ ")");
val mcapp = find_term (app_of "refund_mc" 2) M3C;
val pc0T = rand (rator mcapp);                              (* sl + 0x1000040D0w *)
val msemapp = find_term (app_of "machine_sem" 4) M3C;
val stB = el 2 (snd (strip_comb msemapp));                  (* basis_ffi no_ext cl fs *)
val (msv, M3body) = dest_exists M3C;
val armty = type_of msv;
val _ = pr ("PIECE dm " ^ term_to_string dmT);
val _ = pr ("PIECE pc0 " ^ term_to_string pc0T);
val _ = pr ("PIECE st " ^ term_to_string stB);
val _ = pr ("PIECE envmc_type " ^ type_to_string mcty);
val _ = ctl (armty = PTY ":arm8_state") "the M3 state type is arm8_state";
val _ = ctl (type_of dmT = PTY ":word64 set") "the M3 domain type is word64 set";
val _ = ctl ((mcty = fst (dom_rng (type_of (PT "is_arm8_machine_config")))) handle _ => false)
            "envmc of M3 has the type of the argument of is_arm8_machine_config";
val ms0v = mk_var ("ms0", armty);
val trv = mk_var ("tr", PTY ":arm8_state trace_event list");
val envmc0v = mk_var ("envmc0", mcty);
val dmv = mk_var ("dm", type_of dmT);
val pc0v = mk_var ("pc0", type_of pc0T);
val stv = mk_var ("st", PTY ":'ffi ffi_state");

(* ================= DEFINITIONS ================= *)
val _ = pr "MARK DEFS";
fun xg_def (name : string) (tm : term) : thm =
  (let val th = new_definition (name, tm) in pr ("DEFINITION " ^ name ^ "\n" ^ thm_to_string th); th end)
  handle e => (pr ("DEFINITION_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e)); raise e);
(* G_R: the conclusion of refund_ffi_contract_at, written as a relation between the call argument x = (index,
   new_bytes, ms2) and the result s. The t1 terms of the contract are replaced by the matching terms of
   refund_abs_ffi 0 x (its PC, its dm memory, its callee-saved registers). With refund_abs_ffi_def this is: s is
   arm8_ok, s.PC = ms2.REG 30w, s.MEM agrees on dm with the array write of new_bytes at ms2.REG 2w, and s keeps
   x19-x25, x27, x28 of ms2 (XG_guard_unfold). *)
val GUARD_DEF = xg_def "refund_trace_guard_def"
  (PT ("refund_trace_guard (dm:word64 set) (x:num # word8 list # arm8_state) (s:arm8_state) <=> " ^
       "arm8_ok s /\\ s.PC = (refund_abs_ffi 0 x).PC /\\ " ^
       "(!a. a IN dm ==> s.MEM a = (refund_abs_ffi 0 x).MEM a) /\\ " ^
       "(!r. MEM r [19; 20; 21; 22; 23; 24; 25; 27; 28] ==> s.REG (n2w r) = (refund_abs_ffi 0 x).REG (n2w r))"));
(* the constructed environment. refund_mc (refund_mc_def, mc-0001) overwrites ffi_names, ffi_entry_pcs, halt_pc,
   install_pc, mmio_info, shared_addresses and (arm8_fix) target, len_reg, ptr_reg, len2_reg, ptr2_reg,
   callee_saved_regs. It READS from envmc only prog_addresses, next_interfer, ffi_interfer, install_interfer.
   The first three are set here; install_interfer comes from the free envmc0 (M3 holds for every value). *)
val ENV_DEF = xg_def "refund_trace_env_def"
  (Parse.Term [QUOTE "refund_trace_env (envmc0:", ANTIQUOTE (ty_antiq mcty),
               QUOTE (") (dm:word64 set) (ms0:arm8_state) (tr:arm8_state trace_event list) = " ^
                      "envmc0 with <| prog_addresses := dm; " ^
                      "next_interfer := trace_next_interfer (arm8_target.proj dm) tr; " ^
                      "ffi_interfer := trace_ffi_interfer (refund_trace_guard dm) refund_abs_ffi ms0 tr |>")]);
val GUARD_C = head_const GUARD_DEF;
val ENV_C = head_const ENV_DEF;
val MC_C = head_const MC_DEF;
val ABS_C = head_const ABS_DEF;
fun mk_PR (d : term) : term = Parse.Term [QUOTE "arm8_target.proj (", ANTIQUOTE d, QUOTE ")"];

(* ================= BUILT PARTS (by ISPECL of the stored TR1 theorems; no evaluate is retyped) ================= *)
val _ = pr "MARK PARTS";
fun mk_parts (pc0t : term) (dmt : term) (stt : term) =
  let
    val PRt = mk_PR dmt
    val GRt = mk_comb (GUARD_C, dmt)
    val envRt = list_mk_comb (ENV_C, [envmc0v, dmt, ms0v, trv])
    val mcRt = list_mk_comb (MC_C, [pc0t, envRt])
    val envBt = Parse.Term [QUOTE "(", ANTIQUOTE envmc0v, QUOTE " with prog_addresses := ", ANTIQUOTE dmt, QUOTE ")"]
    val mcBt = list_mk_comb (MC_C, [pc0t, envBt])
    val EFTi = ISPECL [PRt, GRt, ABS_C, trv, mcBt, stt, ms0v] EFT
    val (_, EFTb) = dest_forall (concl EFTi)
    val (TROKt, EVEQ) = dest_imp EFTb
    val (_, largs) = strip_comb (lhs EVEQ)
    val (_, rargs) = strip_comb (rhs EVEQ)
    val MCCt = el 1 largs
    val lent = fst (numSyntax.dest_plus (el 3 largs))
    val MCFt = el 1 rargs
    val stEndt = el 2 rargs
    val msEndt = el 4 rargs
    val TAi = ISPECL [mcRt, stt, ms0v, MCFt, stEndt, msEndt, lent] TAFTER
    val (tio, TAb) = strip_forall (concl TAi)
    val (TAant, TAcon) = dest_imp TAb
    val (C2t, MSEMt) = dest_conj TAant
    val (_, PFX0) = dest_conj TAcon
    val TIOi = ISPECL [PRt, GRt, trv, mcBt, stt, ms0v] TRIO
    val (TROK2, C3t) = dest_imp (concl TIOi)
    val (pfxc, pfxargs) = strip_comb PFX0
    val PFXt = list_mk_comb (pfxc, [rhs C3t, el 2 pfxargs])
    val C4t = list_mk_forall (tio, mk_imp (MSEMt, PFXt))
  in
    {PR = PRt, GR = GRt, envR = envRt, mcR = mcRt, mcB = mcBt, MCC = MCCt, MCF = MCFt, stEnd = stEndt,
     msEnd = msEndt, len = lent, TA = TAi, tio = tio, TROK = TROKt, TROK2 = TROK2, C2 = C2t, C3 = C3t, C4 = C4t,
     MSEM = MSEMt}
  end;
val PG = mk_parts pc0v dmv stv;      (* general: free pc0 dm st *)
val PS = mk_parts pc0T dmT stB;      (* at M3: pc0 = sl + 0x1000040D0w, dm = refund_mem_dm_sl sl h e, st = basis_ffi *)
val _ = ctl (aconv (#TROK PG) (#TROK2 PG) andalso aconv (#TROK PS) (#TROK2 PS))
            "trace_ok premise of evaluate_follows_trace = that of trace_io (both instances)";

(* ================= STATEMENTS ================= *)
val _ = pr "MARK STATEMENTS";
fun xg_term (name : string) (s : string) : term =
  PT s handle e => (pr ("STATEMENT_PARSE_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e)); raise e);
val S_ABSK = xg_term "XG_abs_ffi_any_k" "!(k1:num) k2 x. refund_abs_ffi k1 x = refund_abs_ffi k2 x";
val S_GUNF = xg_term "XG_guard_unfold"
  ("!(dm:word64 set) i nb (ms:arm8_state) s. refund_trace_guard dm (i,nb,ms) s <=> " ^
   "arm8_ok s /\\ s.PC = ms.REG 30w /\\ " ^
   "(!a. a IN dm ==> s.MEM a = asm_write_bytearray (ms.REG 2w) nb ms.MEM a) /\\ " ^
   "(!r. MEM r [19; 20; 21; 22; 23; 24; 25; 27; 28] ==> s.REG (n2w r) = ms.REG (n2w r))");
val S_G1 = xg_term "XG_next_interfer_ok"
  ("!(dm:word64 set) (tr:arm8_state trace_event list). " ^
   "interference_ok (trace_next_interfer (arm8_target.proj dm) tr) (arm8_target.proj dm)");
val S_CAT = xg_term "XG_contract_at"
  ("!pc0 (dm:word64 set) (ms0:arm8_state) (tr:arm8_state trace_event list). " ^
   "refund_ffi_contract_at pc0 dm (trace_ffi_interfer (refund_trace_guard dm) refund_abs_ffi ms0 tr)");
val S_CON = xg_term "XG_contract_on"
  ("!pc0 (dm:word64 set) Vok (ms0:arm8_state) (tr:arm8_state trace_event list). " ^
   "refund_ffi_contract_on pc0 dm Vok (trace_ffi_interfer (refund_trace_guard dm) refund_abs_ffi ms0 tr)");
val S_FLD = xg_term "XG_env_fields"
  ("!envmc0 dm ms0 tr. (refund_trace_env envmc0 dm ms0 tr).prog_addresses = dm /\\ " ^
   "(refund_trace_env envmc0 dm ms0 tr).next_interfer = trace_next_interfer (arm8_target.proj dm) tr /\\ " ^
   "(refund_trace_env envmc0 dm ms0 tr).ffi_interfer = " ^
   "trace_ffi_interfer (refund_trace_guard dm) refund_abs_ffi ms0 tr");
val S_ENVOK = xg_term "XG_env_ok"
  ("!pc0 Vok envmc0 dm ms0 tr. " ^
   "interference_ok (refund_trace_env envmc0 dm ms0 tr).next_interfer " ^
   "(arm8_target.proj (refund_trace_env envmc0 dm ms0 tr).prog_addresses) /\\ " ^
   "refund_ffi_contract_on pc0 (refund_trace_env envmc0 dm ms0 tr).prog_addresses Vok " ^
   "(refund_trace_env envmc0 dm ms0 tr).ffi_interfer");
val S_ENVOKSL = xg_term "XG_env_ok_sl" "!sl envmc0 dm ms0 tr. refund_env_ok_sl sl (refund_trace_env envmc0 dm ms0 tr)";
val S_MCEQ = xg_term "XG_mc_eq"
  ("!pc0 envmc0 dm ms0 tr. refund_mc pc0 (refund_trace_env envmc0 dm ms0 tr) = " ^
   "(refund_mc pc0 (envmc0 with prog_addresses := dm)) with <| " ^
   "next_interfer := trace_next_interfer (arm8_target.proj dm) tr; " ^
   "ffi_interfer := trace_ffi_interfer (refund_trace_guard dm) refund_abs_ffi ms0 tr |>");
val S_TOTID =
  (Parse.Term [QUOTE "!envmc:", ANTIQUOTE (ty_antiq mcty),
               QUOTE ". (envmc with ffi_interfer := refund_ffi_tot (\\i nb ms. T) envmc.ffi_interfer) = envmc"])
  handle e => (pr ("STATEMENT_PARSE_FAILED XG_tot_id " ^ trunc 600 (General.exnMessage e)); raise e);
val S_TROKNIL =
  PT ("!(P:'s -> 'q) (G:num # word8 list # 's -> 's -> bool) (mc:('w,'s,'p) machine_config) " ^
      "(st:'ffi ffi_state) (ms:'s). trace_ok P G mc st ms []")
  handle e => (pr ("STATEMENT_PARSE_FAILED XG_trace_ok_nil " ^ trunc 600 (General.exnMessage e)); T);

(* XG_mc_eq at the general parts is the equation mcR = MC_C used in the proofs *)
val (mceq_vs, mceq_b) = strip_forall S_MCEQ;
val mceq_i = subst (ListPair.map (fn (v, t) => v |-> t) (mceq_vs, [pc0v, envmc0v, dmv, ms0v, trv])) mceq_b;
val _ = ctl (aconv (lhs mceq_i) (#mcR PG) andalso aconv (rhs mceq_i) (#MCC PG))
            "XG_mc_eq instance: left = refund_mc pc0 (refund_trace_env ...), right = the machine of evaluate_follows_trace";

(* built: the trace part (general in pc0, dm, st) *)
val QVG = [pc0v, envmc0v, dmv, ms0v, trv, stv];
val S_FOLLOWS = list_mk_forall (QVG, mk_imp (#TROK PG, mk_conj (#C2 PG, #C3 PG)));
val S_PREFIX = list_mk_forall (QVG, mk_imp (#TROK PG, #C4 PG));
(* built: M3 at envmc := refund_trace_env envmc0 (refund_mem_dm_sl sl h e) ms0 tr, env premises removed *)
val M3i = INST [envv |-> #envR PS] M3;
val (M3iA, M3iC) = dest_imp (concl M3i);
val S_FRAME = mk_imp (list_mk_conj newA, M3iC);
val (msi, M3ibody) = dest_exists M3iC;
val BODY0 = subst [msi |-> ms0v] M3ibody;
val ARUN0 = fst (dest_conj (fst (dest_conj BODY0)));      (* arm8_run 27 s = SOME ms0, with M3's own arm8_run *)
val S_COMPOSE = mk_imp (list_mk_conj (newA @ [ARUN0, #TROK PS]), list_mk_conj [BODY0, #C2 PS, #C3 PS, #C4 PS]);
val S_BIO = if aconv (concl BFFI_DEF) T then T
            else Parse.Term [QUOTE "(", ANTIQUOTE stB, QUOTE ").io_events = []"];
(* MT1 at the constructed environment and Vok := (\i nb ms. T) *)
val envMT = var_named "envmc" (concl MT1);
val VokMT = var_named "Vok" (concl MT1);
val KT = PT "\\(i:num) (nb:word8 list) (ms:arm8_state). T";
val MT1i = INST [envMT |-> #envR PS, VokMT |-> KT] MT1;
val (MT1iA, MT1iC) = dest_imp (concl MT1i);
val MT1cs = strip_conj MT1iA;
val MT1newA = List.filter (fn c => not (free_in (#envR PS) c)) MT1cs;
val newenvMT = rand (find_term (app_of "refund_mc" 2) MT1iC);
val _ = ctl (length MT1cs = 12 andalso length MT1newA = 9 andalso ListPair.all (fn (a, b) => aconv a b) (MT1newA, newA))
            "MT1 antecedent: 12 conjuncts; the 9 free of the constructed env are those of M3, in order";
val _ = ctl (has_const "refund_ffi_tot" newenvMT andalso aconv (subst [newenvMT |-> #envR PS] MT1iC) M3iC)
            "MT1 conclusion at the constructed env, with (envR with ffi_interfer := refund_ffi_tot (\\i nb ms. T) ...) replaced by envR, IS the M3 conclusion at envR";
val _ = ctl (List.all (fn c => not (List.exists (fn n => has_const n c)
                 ["refund_env_ok_sl", "interference_ok", "refund_ffi_contract_on", "refund_ffi_contract_at",
                  "refund_ffi_tot"])) (strip_conj (fst (dest_imp S_COMPOSE))))
            "XG_compose antecedent has no environment premise (no env_ok_sl, interference_ok, contract_on/at, ffi_tot)";
val _ = ctl (length (strip_conj (fst (dest_imp S_COMPOSE))) = 11) "XG_compose antecedent = 9 M3 conjuncts + arm8_run + trace_ok";
val _ = ctl (List.all (fn v => not (fst (dest_var v) = "Vok")) (free_vars S_COMPOSE)) "XG_compose has no free Vok";

val _ =
  let val d = !Globals.max_print_depth
  in Globals.max_print_depth := ~1;
     List.app (fn (n, t) => pr ("STATEMENT " ^ n ^ "\n" ^ term_to_string t))
       [("XG_abs_ffi_any_k", S_ABSK), ("XG_guard_unfold", S_GUNF), ("XG_next_interfer_ok", S_G1),
        ("XG_contract_at", S_CAT), ("XG_contract_on", S_CON), ("XG_env_fields", S_FLD), ("XG_env_ok", S_ENVOK),
        ("XG_env_ok_sl", S_ENVOKSL), ("XG_tot_id", S_TOTID), ("XG_mc_eq", S_MCEQ),
        ("XG_model_frame_trace_env", S_FRAME), ("XG_trace_follows", S_FOLLOWS), ("XG_trace_prefix", S_PREFIX),
        ("XG_compose", S_COMPOSE), ("XG_basis_io_nil", S_BIO), ("XG_trace_ok_nil", S_TROKNIL)];
     Globals.max_print_depth := d
  end;
val _ = pr ("XG_CONTROL_PROBLEMS " ^ Int.toString (length (!XG_PROBLEMS)));
val _ = if XG_PROOF_MODE andalso not (null (!XG_PROBLEMS))
        then raise Fail ("xg_common controls failed: " ^ String.concatWith " | " (rev (!XG_PROBLEMS))) else ();
val _ = pr "XG_COMMON loaded";
