(* mt_v1.sml: theory forge_refundModelFrameTot (worker W-mt, Night-Shift Orchestrator A, 2026-11-19).
   DRAFT: NOT RUN. No HOL process was started by W-mt. Every tactic below is UNCHECKED.
   Run as case MT-0001 (copy this file to <attempt-0001>/MT-0001.sml). Harness: the helper block of MG-0001.sml.
   Parents (stored, read with DB.fetch; no statement retyped):
     forge_refundModelFrame (MF-0002): refund_model_frame_meets_exported_contract (M3), refund_model_success_gives_frame (M2)
     forge_refundRouteA1 (L1-0001): refund_env_ok_sl_of_contract_on (L1C), refund_env_with_ffi_interfer_fields (UPD),
       refund_ffi_tot_def, refund_ffi_contract_on_def, refund_ffi_tot_valid, refund_ffi_tot_invalid.
   Exported:
     MT1 refund_model_frame_totalised   = M3 at envmc := envmc with ffi_interfer := refund_ffi_tot Vok envmc.ffi_interfer,
                                          refund_env_ok_sl replaced by its two L1C premises (interference_ok, on-form contract).
     MT2 refund_model_success_totalised = the same for M2.
     MT3 refund_ffi_tot_observed_set, MT3b refund_ffi_tot_classification_ignores_counter,
     MT4 refund_ffi_contract_on_empty_predicate (vacuous), MT4b refund_ffi_tot_empty_predicate_is_abstract.
   Kind: MODEL. MT1/MT2 speak about the TOTALISED machine refund_mc (sl + 0x1000040D0w) (envmc with ffi_interfer := ...).
   No ffi_calls_ok premise and no R6 premise. Forward proof: INST + MP + EQ_MP; tactic fallback; ASSUME results never stored. *)
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
fun has_const n tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundModelFrameTot";
val failed = ref ([] : string list);
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goalf tacf =
  let val _ = pr ("BEGIN " ^ name)
      val g = goalf ()
      fun fail_with msg = (pr ("LEMMA_FAILED " ^ name ^ " " ^ msg); failed := name :: !failed; ASSUME g)
  in
    (let val th0 = Tactical.TAC_PROOF (([], g), tacf ()) in
       if null (hyp th0) then (let val th = save_thm (name, th0) in chk name th; th end)
       else fail_with "(proof left hypotheses; not stored)"
     end)
    handle e => fail_with (General.exnMessage e)
  end
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " (statement) " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun try_all name tacs g ctxt =
  FIRST (map (fn t => t \\ NO_TAC) tacs) g ctxt
  handle _ => (showg ("TRY_ALL_ENTRY " ^ name) g; (hd tacs \\ show_tac ("REMAINING " ^ name) \\ NO_TAC) g ctxt);

(* ================= parent results ================= *)
fun MF n = DB.fetch "forge_refundModelFrame" n;
fun RA1 n = DB.fetch "forge_refundRouteA1" n;
val M3  = MF "refund_model_frame_meets_exported_contract";
val M2  = MF "refund_model_success_gives_frame";
val L1C = RA1 "refund_env_ok_sl_of_contract_on";
val UPD = RA1 "refund_env_with_ffi_interfer_fields";
val TOT_DEF = RA1 "refund_ffi_tot_def";
val ON_DEF  = RA1 "refund_ffi_contract_on_def";
val TOTV = RA1 "refund_ffi_tot_valid";
val TOTI = RA1 "refund_ffi_tot_invalid";
val _ = List.app (fn (n, th) => pr ("USED " ^ n ^ "\n" ^ thm_to_string th))
  [("refund_model_frame_meets_exported_contract", M3), ("refund_model_success_gives_frame", M2),
   ("refund_env_ok_sl_of_contract_on", L1C), ("refund_env_with_ffi_interfer_fields", UPD),
   ("refund_ffi_tot_def", TOT_DEF), ("refund_ffi_contract_on_def", ON_DEF),
   ("refund_ffi_tot_valid", TOTV), ("refund_ffi_tot_invalid", TOTI)];

fun var_named n th = List.find (fn v => fst (dest_var v) = n) (free_vars (concl th));
fun head_is n t = (fst (dest_const (fst (strip_comb t))) = n) handle _ => false;

(* ================= the instantiation, built once per parent theorem ================= *)
(* Returns (statement, forward proof thunk, fallback tactic, data for controls). *)
fun build tag M =
  let val (A3, C3) = dest_imp (concl M)
      val cs = strip_conj A3
      val _ = if aconv (list_mk_conj cs) A3 then pr ("CONTROL_OK " ^ tag ^ " antecedent is a right-nested conjunction of "
                                                      ^ Int.toString (length cs) ^ " conjuncts")
              else bad (tag ^ "-antecedent-nesting")
      val okcs = List.filter (head_is "refund_env_ok_sl") cs
      val okc = (case okcs of [c] => c | _ => raise Fail (tag ^ ": not exactly one refund_env_ok_sl conjunct"))
      val envv = rand okc
      val _ = if is_var envv andalso fst (dest_var envv) = "envmc" then () else bad (tag ^ "-envmc-not-a-variable")
      val _ = if Option.isSome (var_named "Vok" M) then bad (tag ^ "-parent-has-free-Vok") else ()
      (* align the types of L1C / UPD to the envmc of M (expected: identical already) *)
      val envL = valOf (var_named "envmc" L1C)
      val tyS = match_type (type_of envL) (type_of envv)
      val _ = pr ("TYPE_SUBST_SIZE " ^ tag ^ " " ^ Int.toString (length tyS))
      val ENV_T = INST_TYPE tyS L1C
      val UPD_T = INST_TYPE tyS UPD
      val _ = if aconv (valOf (var_named "envmc" ENV_T)) envv then () else bad (tag ^ "-envmc-differs")
      val slM = rand (rator okc)
      val _ = if aconv (valOf (var_named "sl" ENV_T)) slM then () else bad (tag ^ "-sl-differs")
      val (AL, okn) = dest_imp (concl ENV_T)
      val (ic, kc) = dest_conj AL
      val newenv = rand okn
      val Mi = INST [envv |-> newenv] M
      val (A3i, C3i) = dest_imp (concl Mi)
      val csi = strip_conj A3i
      val _ = if length csi = length cs then () else bad (tag ^ "-conjunct-count-after-INST")
      val _ = if aconv C3i (subst [envv |-> newenv] C3) then () else bad (tag ^ "-INST-vs-subst")
      val newA = List.concat (map (fn c => if aconv c okc then [ic, kc] else [c]) cs)
      val stmt = mk_imp (list_mk_conj newA, C3i)
      val UPD_G = GEN_ALL UPD_T
      fun peel th 1 = [th]
        | peel th n = CONJUNCT1 th :: peel (CONJUNCT2 th) (n - 1)
      fun fwd () =
        let val asm = ASSUME (list_mk_conj newA)
            val ths = peel asm (length newA)
            fun get t = valOf (List.find (fn th => aconv (concl th) t) ths)
                        handle Option => raise Fail (tag ^ ": no assumption " ^ trunc 200 (term_to_string t))
            fun one (c, ci) =
              if aconv c okc then
                (let val th = MP ENV_T (CONJ (get ic) (get kc))
                 in if aconv (concl th) ci then th else raise Fail (tag ^ ": L1C conclusion differs") end
                 handle e => (pr ("STAGE_FAILED " ^ tag ^ ".envok " ^ General.exnMessage e); raise e))
              else if aconv c ci then get c
              else
                (let val eq = PURE_REWRITE_CONV [UPD_G] ci     (* |- ci = c, expected *)
                     val _ = pr ("REWRITTEN_CONJUNCT " ^ tag ^ " " ^ trunc 300 (term_to_string (concl eq)))
                 in EQ_MP (SYM eq) (get (rhs (concl eq))) end
                 handle e => (pr ("STAGE_FAILED " ^ tag ^ ".field " ^ trunc 300 (term_to_string ci) ^ " : "
                                  ^ General.exnMessage e); raise e))
            val prem = LIST_CONJ (map one (zip cs csi))
            val _ = if aconv (concl prem) A3i then () else raise Fail (tag ^ ": rebuilt premise differs")
            val th = DISCH (list_mk_conj newA) (MP Mi prem)
        in th end
        handle e => (pr ("FORWARD_FAILED " ^ tag ^ " " ^ General.exnMessage e); raise e)
      val FWD_TAC = fn g => fn ctxt => ACCEPT_TAC (fwd ()) g ctxt
      val PREM_TAC = FIRST [FIRST_ASSUM ACCEPT_TAC,
                            MATCH_MP_TAC ENV_T \\ CONJ_TAC \\ FIRST_ASSUM ACCEPT_TAC,
                            ASM_REWRITE_TAC [UPD_G] \\ NO_TAC,
                            show_tac ("PREM_LEFT " ^ tag) \\ NO_TAC]
      val FALLBACK = DISCH_THEN STRIP_ASSUME_TAC
                       \\ SUBGOAL_THEN A3i (fn a => ACCEPT_TAC (MP Mi a))
                       \\ rpt CONJ_TAC \\ ST (tag ^ ".prem") PREM_TAC
  in {stmt = stmt, tacs = [FWD_TAC, FALLBACK], envv = envv, newenv = newenv, okc = okc, ic = ic, kc = kc,
      cs = cs, newA = newA, C3 = C3} end;

val B3 = build "MT1" M3;
val B2 = build "MT2" M2;

(* ================= MT1, MT2 ================= *)
val MT1 = thm "refund_model_frame_totalised" (fn () => #stmt B3) (fn () => try_all "MT1" (#tacs B3));
val MT2 = thm "refund_model_success_totalised" (fn () => #stmt B2) (fn () => try_all "MT2" (#tacs B2));

(* ================= MT3: the reading of refund_ffi_tot for an observed set ================= *)
(* refund_ffi_tot_def: refund_ffi_tot Vok f k x = if Vok (FST x) (FST (SND x)) (SND (SND x)) then f k x else refund_abs_ffi k x.
   The guard sees only the triple x = (index, new_bytes, ms2); it does NOT see the call counter k. *)
val MT3 = thm "refund_ffi_tot_observed_set"
  (fn () => ``!Obs f k index new_bytes ms2.
      refund_ffi_tot (\i nb ms. (i,nb,ms) IN Obs) f k (index,new_bytes,ms2) =
      if (index,new_bytes,ms2) IN Obs then f k (index,new_bytes,ms2) else refund_abs_ffi k (index,new_bytes,ms2)``)
  (fn () => try_all "MT3"
     [rpt gen_tac \\ REWRITE_TAC [TOT_DEF, pairTheory.FST, pairTheory.SND] \\ BETA_TAC \\ REWRITE_TAC [],
      rpt gen_tac \\ Cases_on `(index,new_bytes,ms2) IN Obs` \\ ASM_REWRITE_TAC []
        \\ FIRST [MATCH_MP_TAC TOTV, MATCH_MP_TAC TOTI] \\ BETA_TAC \\ ASM_REWRITE_TAC [],
      rpt gen_tac \\ simp [TOT_DEF]]);
val MT3b = thm "refund_ffi_tot_classification_ignores_counter"
  (fn () => ``!Vok f k1 k2 x.
      (refund_ffi_tot Vok f k1 x = f k1 x /\ refund_ffi_tot Vok f k2 x = f k2 x) \/
      (refund_ffi_tot Vok f k1 x = refund_abs_ffi k1 x /\ refund_ffi_tot Vok f k2 x = refund_abs_ffi k2 x)``)
  (fn () => try_all "MT3b"
     [rpt gen_tac \\ REWRITE_TAC [TOT_DEF] \\ COND_CASES_TAC \\ REWRITE_TAC [],
      rw [TOT_DEF],
      rpt gen_tac \\ simp [TOT_DEF] \\ metis_tac []]);

(* ================= MT4: the empty predicate (why the premise alone carries no native content) ================= *)
val MT4 = thm "refund_ffi_contract_on_empty_predicate"
  (fn () => ``!b dm f. refund_ffi_contract_on b dm (\i nb ms. F) f``)
  (fn () => try_all "MT4"
     [rpt gen_tac \\ REWRITE_TAC [ON_DEF] \\ BETA_TAC \\ REWRITE_TAC [],
      rw [ON_DEF]]);
val MT4b = thm "refund_ffi_tot_empty_predicate_is_abstract"
  (fn () => ``!f. refund_ffi_tot (\i nb ms. F) f = refund_abs_ffi``)
  (fn () => try_all "MT4b"
     [gen_tac \\ REWRITE_TAC [FUN_EQ_THM] \\ rpt gen_tac \\ REWRITE_TAC [TOT_DEF] \\ BETA_TAC \\ REWRITE_TAC [],
      simp [FUN_EQ_THM, TOT_DEF]]);

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
fun ctl tag (B : {stmt:term, tacs:tactic list, envv:term, newenv:term, okc:term, ic:term, kc:term,
                  cs:term list, newA:term list, C3:term}) th =
  let val (A, C) = dest_imp (concl th) in
    if aconv (concl th) (#stmt B) then pr ("CONTROL_OK " ^ tag ^ " stored statement is the built statement") else bad (tag ^ "-stmt");
    if aconv C (subst [#envv B |-> #newenv B] (#C3 B))
    then pr ("CONTROL_OK " ^ tag ^ " conclusion = parent conclusion under envmc := " ^ term_to_string (#newenv B))
    else bad (tag ^ "-conclusion");
    if aconv A (list_mk_conj (List.concat (map (fn c => if aconv c (#okc B) then [#ic B, #kc B] else [c]) (#cs B))))
    then pr ("CONTROL_OK " ^ tag ^ " antecedent = parent antecedent with refund_env_ok_sl replaced by the two L1C premises")
    else bad (tag ^ "-antecedent");
    if not (has_const "refund_env_ok_sl" A) andalso not (has_const "ffi_calls_ok" A) andalso not (has_const "refund_valid_event" A)
    then pr ("CONTROL_OK " ^ tag ^ " antecedent contains no refund_env_ok_sl, no ffi_calls_ok, no refund_valid_event")
    else bad (tag ^ "-antecedent-consts");
    if can (find_term (fn t => head_is "refund_mc" t andalso aconv (rand t) (#newenv B))) C
       andalso not (can (find_term (fn t => head_is "refund_mc" t andalso aconv (rand t) (#envv B))) C)
    then pr ("CONTROL_OK " ^ tag ^ " conclusion speaks only about refund_mc _ (envmc with ffi_interfer := refund_ffi_tot Vok envmc.ffi_interfer)")
    else bad (tag ^ "-machine");
    if List.exists (fn v => fst (dest_var v) = "Vok") (free_vars (concl th))
    then pr ("CONTROL_OK " ^ tag ^ " Vok is free (the theorem holds for every predicate)") else bad (tag ^ "-Vok")
  end;
val _ = ctl "MT1" B3 MT1;
val _ = ctl "MT2" B2 MT2;
val _ = pr ("STATEMENT_MT1 " ^ term_to_string (concl MT1));
val _ = pr ("STATEMENT_MT2 " ^ term_to_string (concl MT2));
val _ = pr ("REMAINING_NATIVE_PREMISE " ^ term_to_string (#kc B3));
val _ = pr ("REMAINING_ENV_PREMISE " ^ term_to_string (#ic B3));
val _ = pr "NOTE With Vok := (\\i nb ms. F) the native premise is trivially true (refund_ffi_contract_on_empty_predicate) and refund_ffi_tot (\\i nb ms. F) f = refund_abs_ffi (refund_ffi_tot_empty_predicate_is_abstract): MT1/MT2 then speak about the machine with the abstract FFI effect only. The content for a real run lies entirely in the refinement statement X8: the real run must be a run of the totalised machine (with a Vok whose contract_on premise holds for the real FFI).";
val _ = pr "NOTE refund_ffi_tot guards on the triple (index, new_bytes, ms2) only, not on the call counter k (refund_ffi_tot_classification_ignores_counter): an observed set is a set of triples; a triple that occurs twice is classified the same way both times (both times f k, or both times refund_abs_ffi k).";
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundModelFrameTot" @ DB.definitions "forge_refundModelFrameTot");
val closure = "forge_refundModelFrameTot" :: Theory.ancestry "forge_refundModelFrameTot";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = if Lib.mem "forge_refundRouteA1" closure andalso Lib.mem "forge_refundModelFrame" closure
        then pr "CONTROL_OK closure contains forge_refundRouteA1 and forge_refundModelFrame" else raise Fail "closure parents";
val _ = pr ("PARENTS " ^ String.concatWith " " (Theory.parents "forge_refundModelFrameTot"));
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundModelFrameTot")));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
