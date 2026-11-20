(* APEX-2 (2026-11-19). Route A, reachable-call ("shape") form, restated on the
   plain flat contract. A `hol run` script in the style of the night-shift
   Route A cases (run_case.py; the stored parent theories are given as
   arguments). It is NOT a Holmake script: its parents are the stored
   theories of the earlier M1 chain, which have no Holmake build.

   Parents by loading: forge_refundRouteA2d (case L2d-0001),
   forge_refundExportedContract (case contract-0001, the STORED night-shift
   theory, not the Holmake port), forge_refundSlideEntry, and
   forge_refundFlatContract (APEX-2, built by Holmake).

   Theorems:
   R1 refund_route_a_flat_plain_shape: the stored theorem
      forge_refundRouteA2d.refund_model_frame_decision_shape with its last
      conjunct (the three exported clauses evaluate to true) rewritten by
      exported_contract_exact and refund_fields_flat_plain to the plain
      contract flat_plain on byte codes. The 12 premises are unchanged. The
      FFI premise is the reachable-call form: the contract only at calls that
      meet the shape predicate (for close, index 2: REG 1 = 8 and REG 3 <> 0).
      It is a PREMISE. It is not proved for any real C code.
   R2 refund_entry_forces_plain_user_state: premise P1 (refund_entry_pre_sl)
      forces TBI0 = TBI1 = SA0 = E0E = F and EL = 0.
   R3 refund_entry_refuses_tagged_user_state: so a state with TBI0 or SA0 set
      does NOT meet P1. R1 says nothing about such a state.

   MODEL level. No axiom, no cheat, no mk_thm, no oracle. *)
open HolKernel boolLib bossLib Parse;
open forge_refundRouteA2dTheory forge_refundExportedContractTheory forge_refundSlideEntryTheory
     forge_refundFlatContractTheory;
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundRouteAFlat";

val base = forge_refundRouteA2dTheory.refund_model_frame_decision_shape;
val r1 = PURE_REWRITE_RULE [forge_refundExportedContractTheory.exported_contract_exact,
                            forge_refundFlatContractTheory.refund_fields_flat_plain] base;
fun has_const name tm = can (find_term (fn t => is_const t andalso #1 (dest_const t) = name)) tm;
val _ = if has_const "flat_plain" (concl r1) then pr "TEXT_CHECK flat_plain is in the conclusion"
        else raise Fail "flat_plain is not in the rewritten statement";
val _ = if has_const "evaluate_exps" (concl r1) orelse has_const "exported_ensures" (concl r1)
        then raise Fail "the exported clauses are still in the rewritten statement"
        else pr "TEXT_CHECK no evaluate_exps and no exported_ensures in the statement";
val _ = if aconv (#1 (dest_imp (concl r1))) (#1 (dest_imp (concl base)))
        then pr "TEXT_CHECK the premises are those of refund_model_frame_decision_shape, unchanged"
        else raise Fail "premises changed";
val _ = if length (strip_conj (#1 (dest_imp (concl r1)))) = 12 then pr "TEXT_CHECK 12 premises"
        else raise Fail "premise count";
val r1 = save_thm ("refund_route_a_flat_plain_shape", r1);

val _ = pr "FORGE_BEGIN refund_entry_forces_plain_user_state";
val r2 = store_thm ("refund_entry_forces_plain_user_state", ``
  refund_entry_pre_sl sl s h stk e ==>
  ~s.TCR_EL1.TBI0 /\ ~s.TCR_EL1.TBI1 /\ ~s.SCTLR_EL1.SA0 /\ ~s.SCTLR_EL1.E0E /\
  s.PSTATE.EL = 0w /\ s.exception = NoException``,
  simp [forge_refundSlideEntryTheory.refund_entry_pre_sl_def]);

val _ = pr "FORGE_BEGIN refund_entry_refuses_tagged_user_state";
val r3 = store_thm ("refund_entry_refuses_tagged_user_state", ``
  s.TCR_EL1.TBI0 \/ s.SCTLR_EL1.SA0 ==> ~refund_entry_pre_sl sl s h stk e``,
  metis_tac [r2]);

val checked = [("refund_route_a_flat_plain_shape", r1),
               ("refund_entry_forces_plain_user_state", r2),
               ("refund_entry_refuses_tagged_user_state", r3)];
val _ = Globals.max_print_depth := ~1;
val _ = List.app (fn (name, th) =>
  let val (ors, axs) = Tag.dest_tag (Thm.tag th) in
    if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
    then ()
    else raise Fail ("Unexpected assumptions or tags: " ^ name);
    pr ("FORGE_THEOREM " ^ name);
    pr ("FORGE_ORACLES " ^ String.concatWith "," ors);
    pr ("FORGE_HYPOTHESES " ^ Int.toString (length (hyp th)));
    pr ("FORGE_STATEMENT " ^ Parse.thm_to_string th)
  end) checked;
val _ = export_theory ();
val _ = pr "ROUTE_A_FLAT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
