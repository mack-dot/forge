(* compose_v2.sml: theory forge_refundModelFrameEvents (worker A21, Night-Shift Orchestrator A, 2026-11-19).
   DRAFT: NOT RUN. No HOL process was started by A21. Every tactic below is UNCHECKED.
   Run as case MG-0001. Harness: the helper block of compose_v1.sml / MF-0002.sml (PX-0001 style).
   Parents (stored, read with DB.fetch; no statement retyped):
     forge_refundModelFrame (MF-0002): refund_model_frame_decision_reach (M1b), refund_model_frame_meets_exported_contract (M3),
       refund_model_success_gives_frame (M2), extend_with_resource_limit_single_success (ERL)
     forge_refundRouteA2c (L2c-0001): refund_profile_a_sl_events (EV), refund_events_premise_gives_l2r_third_premise (R5)
     forge_refundLOut: refund_L_OUT; forge_refundPrefixFree: refund_strict_parse_complete;
     forge_refundSlideEntry: arm8_run_constants_agree; forge_refundExportedContract: exported_contract_on_refund_fields.
   Exported: refund_frame_contract_upgrade (UP), refund_model_frame_contract_of_reach (UPC), refund_success_accept_of_run (SUCC2),
     G1 refund_model_frame_decision_events, G2 refund_model_success_gives_frame_events.
   Kind: MODEL, machine model at no_ext. G1 and G2 keep two premises that NO theorem discharges:
     R6 (every event of every run of the totalised machine is a refund_valid_event) and the native contract
     refund_ffi_contract_on ... VokY3 ... . They are printed as REMAINING_PREMISE_R6 / REMAINING_PREMISE_CONTRACT. *)
open preamble mlsexpTheory mlstringTheory;
val _ = Globals.max_print_depth := 60;
val _ = metisTools.limit := {time = SOME 30.0, infs = NONE};
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun trunc n s = if size s <= n then s else String.substring (s, 0, n) ^ " ...";
fun showg tag (asl, w) = (pr ("SHOW " ^ tag);
   List.app (fn a => pr ("  ASM " ^ trunc 700 (term_to_string a))) asl;
   pr ("  GOAL " ^ trunc 3000 (term_to_string w)));
fun show_tac tag g = (showg tag g; ALL_TAC g);
fun ST tag tac g ctxt = tac g ctxt
  handle e => (showg ("STAGE_FAILED " ^ tag ^ " : " ^ trunc 300 (General.exnMessage e)) g; raise e);
fun thy_of c = #Thy (dest_thy_const c) handle _ => "?";
fun has_const n tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundModelFrameEvents";
val failed = ref ([] : string list);
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
val failed_stmts = ref ([] : (string * term) list);
val diag = ref ([] : string list);
fun names_of_hyps th = map (fn h => case List.find (fn (_, t) => aconv t h) (!failed_stmts) of
                                      SOME (n, _) => n | NONE => "?" ^ trunc 80 (term_to_string h)) (hyp th);
fun thm name goalf tacf =
  let val _ = pr ("BEGIN " ^ name)
      val g = goalf ()
      fun fail_with msg = (pr ("LEMMA_FAILED " ^ name ^ " " ^ msg); failed := name :: !failed;
                           failed_stmts := (name, g) :: !failed_stmts; ASSUME g)
  in
    (let val th0 = Tactical.TAC_PROOF (([], g), tacf ()) in
       if null (hyp th0) then (let val th = save_thm (name, th0) in chk name th; th end)
       else (pr ("DIAG_OK_UNDER " ^ name ^ " assumed: " ^ String.concatWith " " (names_of_hyps th0));
             diag := name :: !diag; fail_with "(diagnostic only: proved only under the failed lemmas above)")
     end)
    handle e => fail_with (General.exnMessage e)
  end
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " (statement) " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun try_all name tacs g ctxt =
  FIRST (map (fn t => t \\ NO_TAC) tacs) g ctxt
  handle _ => (showg ("TRY_ALL_ENTRY " ^ name) g; (hd tacs \\ show_tac ("REMAINING " ^ name) \\ NO_TAC) g ctxt);

(* ================= parent results ================= *)
fun MF n = DB.fetch "forge_refundModelFrame" n;
val M1B   = MF "refund_model_frame_decision_reach";
val M3    = MF "refund_model_frame_meets_exported_contract";
val M2    = MF "refund_model_success_gives_frame";
val ERL   = MF "extend_with_resource_limit_single_success";
val EV    = DB.fetch "forge_refundRouteA2c" "refund_profile_a_sl_events";
val R5    = DB.fetch "forge_refundRouteA2c" "refund_events_premise_gives_l2r_third_premise";
val LOUT  = DB.fetch "forge_refundLOut" "refund_L_OUT";
val P0    = DB.fetch "forge_refundPrefixFree" "refund_strict_parse_complete";
val AGREE = DB.fetch "forge_refundSlideEntry" "arm8_run_constants_agree";
val ECON0 = DB.fetch "forge_refundExportedContract" "exported_contract_on_refund_fields";
val _ = List.app (fn (n, th) => pr ("USED " ^ n ^ "\n" ^ thm_to_string th))
  [("refund_model_frame_decision_reach", M1B), ("refund_model_frame_meets_exported_contract", M3),
   ("refund_model_success_gives_frame", M2), ("extend_with_resource_limit_single_success", ERL),
   ("refund_profile_a_sl_events", EV), ("refund_events_premise_gives_l2r_third_premise", R5),
   ("refund_L_OUT", LOUT), ("refund_strict_parse_complete", P0), ("arm8_run_constants_agree", AGREE),
   ("exported_contract_on_refund_fields", ECON0)];

(* ext := no_ext, as LO-0006 / compose_v1: the constant at the exact type of each theorem's variable ext. *)
fun at_no_ext th =
  let val v = valOf (List.find (fn v => fst (dest_var v) = "ext") (free_vars (concl th)))
      val c = mk_thy_const {Thy = "basis_ffi", Name = "no_ext", Ty = type_of v}
  in pr ("NOEXT_TYPE " ^ type_to_string (type_of v)); INST [v |-> c] th end;
val EV_NE = at_no_ext EV;
val R5_NE = at_no_ext R5;
(* Vok := VokY3 in M1b (Vok is a variable of L2-0003, proof.sml 144; VokY3 is the L2c constant). *)
val VokY3C = find_term (fn t => is_const t andalso fst (dest_const t) = "VokY3") (concl EV);
val VokV = valOf (List.find (fn v => fst (dest_var v) = "Vok") (free_vars (concl M1B)));
val M1B_V = INST [VokV |-> VokY3C] M1B;
val (ANTE_V, M1BC) = dest_imp (concl M1B_V);
val (EV_ANTE, EVC) = dest_imp (concl EV_NE);
val M3C = snd (dest_imp (concl M3));
val M2C = snd (dest_imp (concl M2));
(* premise 3 of M1B_V must be the conclusion of R5_NE *)
val _ = if List.exists (aconv (snd (dest_imp (concl R5_NE)))) (strip_conj ANTE_V)
        then pr "CONTROL_OK R5 at no_ext concludes a premise of M1b at Vok := VokY3"
        else pr "NOTE R5_NOT_LITERAL_PREMISE (G1 then needs the AGREE fallback of PREM_TAC)";

(* ================= pieces of M1BC and M3C (same variables: both come from refund_profile_a_sl_fd1) ======== *)
fun pieces c =
  let val (ms, B) = dest_exists c
      val (C1, ALLB) = dest_conj B
      val (b, I) = dest_forall ALLB
      val (_, E) = dest_imp I
      val (tio, body) = strip_exists E
      val (_, N) = dest_conj body
  in (ms, b, List.nth (tio, 0), List.nth (tio, 1), N) end;
val (msv, bv, tv, iov, N1) = pieces M1BC;
val (msv3, bv3, tv3, iov3, N3) = pieces M3C;
val _ = if aconv msv msv3 andalso aconv bv bv3 andalso aconv tv tv3 andalso aconv iov iov3
        then pr "CONTROL_OK M1b and M3 conclusions use the same bound variables" else bad "bound-variables-differ";
val gv3 = fst (dest_forall N3);

(* ECON with the variable names used in M3 (MF-0002: h -> dafny_heap, env -> dafny_env) *)
fun fv n = List.find (fn v => fst (dest_var v) = n) (free_vars (concl ECON0));
val ECON = INST (List.mapPartial (fn (n, n') => case fv n of SOME v => SOME (v |-> mk_var (n', type_of v)) | NONE => NONE)
                   [("h", "dafny_heap"), ("env", "dafny_env")]) ECON0;

(* ================= UP: newc(out) ==> newc3(out), at out = fd1_written io ================= *)
(* Hand walk = the passed K3 tactic of MF-0002 without the KEY step: DISCH_TAC [N1: !g. rsp o = SOME g ==> g = FT /\ o = EXPL];
   X_GEN_TAC g; DISCH_TAC [rsp o = SOME g]; MATCH_MP of the two gives g = FT, o = EXPL; two conjuncts by assumption;
   gen ok a r c q n; DISCH_TAC [g = TUP]; MATCH_MP_TAC ECON leaves FT = TUP; metis from g = FT, g = TUP. *)
val UP = thm "refund_frame_contract_upgrade"
  (fn () => mk_imp (N1, N3))
  (fn () => try_all "refund_frame_contract_upgrade"
     [DISCH_TAC \\ X_GEN_TAC gv3 \\ DISCH_TAC
        \\ first_x_assum (fn th => first_assum (STRIP_ASSUME_TAC o MATCH_MP th))
        \\ CONJ_TAC >- FIRST_ASSUM ACCEPT_TAC
        \\ CONJ_TAC >- FIRST_ASSUM ACCEPT_TAC
        \\ rpt gen_tac \\ DISCH_TAC \\ MATCH_MP_TAC ECON \\ metis_tac [],
      DISCH_TAC \\ X_GEN_TAC gv3 \\ rpt strip_tac \\ res_tac \\ TRY (FIRST_ASSUM ACCEPT_TAC)
        \\ MATCH_MP_TAC ECON \\ metis_tac []]);

(* ================= UPC: M1b's conclusion ==> M3's conclusion ================= *)
(* Hand walk: choose ms; C1 from the two assumptions; X_GEN_TAC b, DISCH_TAC [MS b]; first_x_assum drule (the !b
   assumption is the newest implication); choose t io; witness them; CONJ (b = Terminate t io) (MATCH_MP UP N1). *)
val UPC = thm "refund_model_frame_contract_of_reach"
  (fn () => mk_imp (M1BC, M3C))
  (fn () => try_all "refund_model_frame_contract_of_reach"
     [DISCH_THEN (X_CHOOSE_THEN msv STRIP_ASSUME_TAC)
        \\ EXISTS_TAC msv \\ CONJ_TAC >- (CONJ_TAC \\ FIRST_ASSUM ACCEPT_TAC)
        \\ X_GEN_TAC bv \\ DISCH_TAC
        \\ ST "upc.drule" (first_x_assum drule)
        \\ DISCH_THEN (X_CHOOSE_THEN tv (X_CHOOSE_THEN iov (fn th =>
             EXISTS_TAC tv \\ EXISTS_TAC iov \\ ACCEPT_TAC (CONJ (CONJUNCT1 th) (MATCH_MP UP (CONJUNCT2 th)))))),
      ho_match_mp_tac boolTheory.MONO_EXISTS \\ gen_tac \\ BETA_TAC
        \\ ho_match_mp_tac boolTheory.MONO_AND \\ CONJ_TAC >- REWRITE_TAC []
        \\ ho_match_mp_tac boolTheory.MONO_ALL \\ gen_tac \\ BETA_TAC
        \\ ho_match_mp_tac boolTheory.MONO_IMP \\ CONJ_TAC >- REWRITE_TAC []
        \\ ho_match_mp_tac boolTheory.MONO_EXISTS \\ gen_tac \\ BETA_TAC
        \\ ho_match_mp_tac boolTheory.MONO_EXISTS \\ gen_tac \\ BETA_TAC
        \\ ho_match_mp_tac boolTheory.MONO_AND \\ CONJ_TAC >- REWRITE_TAC []
        \\ MATCH_ACCEPT_TAC UP]);

(* ================= G1 ================= *)
(* Hand walk: DISCH_THEN STRIP_ASSUME_TAC puts every premise of EV (at no_ext) in the assumptions (R6 included).
   MATCH_MP_TAC UPC (same free variables; UPC's antecedent has no extra variable) leaves M1BC.
   SUBGOAL_THEN ANTE_V (fn a => ACCEPT_TAC (MP M1B_V a)) closes M1BC and leaves ANTE_V (MP, not MATCH_MP_TAC:
   ANTE_V has variables h stk e that M1BC lacks). rpt conj_tac; each premise is an assumption, except premise 3
   (ffi_calls_ok VokY3 ...), which is MATCH_MP R5_NE R6. *)
val G1_STMT = mk_imp (EV_ANTE, M3C);
val PREM_TAC = FIRST [FIRST_ASSUM ACCEPT_TAC, FIRST_ASSUM (ACCEPT_TAC o MATCH_MP R5_NE),
                      FIRST_ASSUM (ACCEPT_TAC o REWRITE_RULE [AGREE] o MATCH_MP R5_NE),
                      FIRST_ASSUM (ACCEPT_TAC o REWRITE_RULE [GSYM AGREE] o MATCH_MP R5_NE)];
val G1 = thm "refund_model_frame_decision_events"
  (fn () => G1_STMT)
  (fn () => try_all "refund_model_frame_decision_events"
     [DISCH_THEN STRIP_ASSUME_TAC
        \\ ST "g1.upc" (MATCH_MP_TAC UPC)
        \\ SUBGOAL_THEN ANTE_V (fn a => ACCEPT_TAC (MP M1B_V a))
        \\ rpt conj_tac \\ ST "g1.prem" PREM_TAC,
      DISCH_THEN STRIP_ASSUME_TAC
        \\ SUBGOAL_THEN ANTE_V (fn a => ACCEPT_TAC (MP UPC (MP M1B_V a)))
        \\ rpt conj_tac \\ PREM_TAC]);

(* ================= G2 (M2 form; M2's own route used refund_env_ok_sl, so the events route goes through ERL and
   refund_L_OUT as M1b did) ================= *)
(* SUCC2 hand walk: STRIP_TAC gives (1) [Terminate Success io0 = Terminate Success io1; FD] and
   (2) [Terminate Success io0 = Terminate Resource_limit_hit io'; io' <<= io1; FD]. gvs: (1) io0 = io1 by injectivity,
   goal rsp (E f) = SOME f, P0; (2) Success = Resource_limit_hit is false. *)
val SUCC2 = thm "refund_success_accept_of_run"
  (fn () => ``!io0 io1 f.
      (Terminate Success io0 = Terminate Success io1 \/
       ?io'. Terminate Success io0 = Terminate Resource_limit_hit io' /\ io' <<= io1) /\
      fd1_written io1 = explode (refund_render_fields f) ==>
      refund_strict_parse (fd1_written io0) = SOME f``)
  (fn () => try_all "refund_success_accept_of_run"
     [rpt gen_tac \\ STRIP_TAC \\ gvs [P0],
      rpt strip_tac \\ fs [] \\ rveq \\ fs [P0],
      rpt strip_tac \\ fs [] \\ rfs [P0]]);
(* G2 hand walk: keep STD_streams fs (last premise); strip MP EV_NE: ms, run, PC, TO, io_events, SUB, EXT.
   EXISTS_TAC ms (M2's variable = EV's, both "ms"); C1 with the LO-0006 / M1b FIRST list (AGREE); X_GEN_TAC io,
   DISCH_TAC [MS (Terminate Success io)]; MATCH_MP_TAC SUCC2 (io0 := io, f := FT) leaves ?io1. cases /\ FD;
   witness io_events; cases by drule_all ERL (SUB, MS); FD by drule_all LOUT (STD_streams fs, EXT). *)
val (msv2, M2B) = dest_exists M2C;
val io2 = fst (dest_forall (snd (dest_conj M2B)));
val (_, EVB) = dest_exists EVC;
val ioev = fst (dest_exists (List.last (strip_conj EVB)));
val C1_TAC = FIRST [CONJ_TAC \\ FIRST_ASSUM ACCEPT_TAC,
                    ASM_REWRITE_TAC [AGREE] \\ NO_TAC,
                    ASM_REWRITE_TAC [GSYM AGREE] \\ NO_TAC];
val G2_STMT = mk_imp (EV_ANTE, M2C);
val G2 = thm "refund_model_success_gives_frame_events"
  (fn () => G2_STMT)
  (fn () => try_all "refund_model_success_gives_frame_events"
     [DISCH_THEN (fn th => ASSUME_TAC (List.last (CONJUNCTS th)) \\ STRIP_ASSUME_TAC (MP EV_NE th))
        \\ EXISTS_TAC msv2
        \\ ST "g2.c1" (CONJ_TAC >- C1_TAC)
        \\ X_GEN_TAC io2 \\ DISCH_TAC
        \\ ST "g2.succ2" (MATCH_MP_TAC SUCC2) \\ EXISTS_TAC ioev
        \\ CONJ_TAC
        >- ST "g2.erl" (drule_all ERL \\ DISCH_THEN ACCEPT_TAC)
        \\ ST "g2.lout" (drule_all LOUT \\ DISCH_THEN ACCEPT_TAC),
      DISCH_THEN (fn th => ASSUME_TAC (List.last (CONJUNCTS th)) \\ STRIP_ASSUME_TAC (MP EV_NE th))
        \\ qexists_tac `ms` \\ CONJ_TAC >- C1_TAC
        \\ X_GEN_TAC io2 \\ DISCH_TAC
        \\ MATCH_MP_TAC SUCC2 \\ qexists_tac `io_events` \\ metis_tac [ERL, LOUT]]);

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = pr ("DIAG_OK_UNDER_LIST " ^ String.concatWith " " (rev (!diag)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val G1A = fst (dest_imp (concl G1));
val _ = if aconv (snd (dest_imp (concl G1))) M3C
        then pr "CONTROL_OK G1 conclusion is term-identical to the conclusion of refund_model_frame_meets_exported_contract"
        else bad "G1-conclusion";
val _ = if aconv G1A EV_ANTE
        then pr "CONTROL_OK G1 antecedent is term-identical to the antecedent of refund_profile_a_sl_events at ext := no_ext"
        else bad "G1-antecedent";
val _ = if not (has_const "refund_env_ok_sl" G1A) andalso not (has_const "ffi_calls_ok" G1A)
        then pr "CONTROL_OK G1 antecedent contains neither refund_env_ok_sl nor ffi_calls_ok" else bad "G1-antecedent-consts";
val _ = if aconv (snd (dest_imp (concl G2))) M2C andalso aconv (fst (dest_imp (concl G2))) EV_ANTE
        then pr "CONTROL_OK G2 = M2 conclusion under the G1 antecedent" else bad "G2-shape";
val _ = if List.all (fn th => not (Lib.mem "ext" (map (fst o dest_var) (free_vars (concl th))))) [G1, G2]
        then pr "CONTROL_OK G1 and G2 have no free ext (no_ext)" else bad "G1G2-ext";
val _ = (case List.filter (has_const "refund_valid_event") (strip_conj G1A) of
           [r6] => pr ("REMAINING_PREMISE_R6 " ^ term_to_string r6)
         | l => bad ("R6-count-" ^ Int.toString (length l)));
val _ = (case List.filter (fn c => (fst (dest_const (fst (strip_comb c))) = "refund_ffi_contract_on") handle _ => false)
                          (strip_conj G1A) of
           [k] => pr ("REMAINING_PREMISE_CONTRACT " ^ term_to_string k)
         | l => bad ("contract-count-" ^ Int.toString (length l)));
val _ = pr "NOTE G1/G2 are conditional on REMAINING_PREMISE_R6 and REMAINING_PREMISE_CONTRACT (both unproved; MODEL only)";
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundModelFrameEvents" @ DB.definitions "forge_refundModelFrameEvents");
val closure = "forge_refundModelFrameEvents" :: Theory.ancestry "forge_refundModelFrameEvents";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = pr ("PARENTS " ^ String.concatWith " " (Theory.parents "forge_refundModelFrameEvents"));
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundModelFrameEvents")));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
