(* Route A L1: exact-statement import check for forge_refundRouteA1. DRAFT: NOT RUN.
   Run only after routeA-L1.sml has exit 0. Load deps-imp4.txt plus the L1 case's forge_refundRouteA1Theory.sig/.sml.
   The expected definition of refund_ffi_contract_on is rebuilt here from the STORED refund_ffi_contract_at_def
   (theory forge_refundSlideProfileA), not copied from the proof script. No theorem is proved or stored.
   Same machine and cached parents: this is NOT a clean or independent replay. *)
open preamble wordsLib targetSemTheory arm8Theory miscTheory forge_refundEnvModelTheory forge_refundSlideProfileATheory
     forge_refundRouteA1Theory;
val _ = Globals.max_print_depth := 40;
fun pr s = print (s ^ "\n");
val bad = ref 0; val good = ref 0;
fun clean th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors end;
val T = "forge_refundRouteA1";
fun same name tm = let val th = DB.fetch T name in aconv (concl th) tm andalso clean th end handle _ => false;
fun check name tm = if same name tm then (good := !good + 1; pr ("IMPORTED " ^ T ^ "." ^ name)) else (bad := !bad + 1; pr ("IMPORT_MISMATCH " ^ T ^ "." ^ name));
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val envmc = mk_var ("envmc", mcty);
val cat = DB.fetch "forge_refundSlideProfileA" "refund_ffi_contract_at_def";
val ([bv, dmv, ffiv], ceq) = strip_forall (concl cat);
val (qvs, cimp) = strip_forall (rhs ceq);
val [kv, iv, nbv, msv2, t1v, bsv, bs2v] = qvs;
val (chyp, cconc) = dest_imp cimp;
val Vv = mk_var ("Vok", ``:num -> word8 list -> arm8_state -> bool``);
val on_tm = list_mk_comb (prim_mk_const {Thy = T, Name = "refund_ffi_contract_on"}, [bv, dmv, Vv, ffiv]);
val exp_on = list_mk_forall ([bv, dmv, Vv, ffiv], mk_eq (on_tm,
               list_mk_forall (qvs, mk_imp (list_mk_conj (strip_conj chyp @ [list_mk_comb (Vv, [iv, nbv, msv2])]), cconc))));
val _ = check "refund_ffi_contract_on_def" exp_on;
val _ = check "refund_ffi_tot_def" ``!Vok f k x. refund_ffi_tot Vok f k x =
      if Vok (FST x) (FST (SND x)) (SND (SND x)) then f k x else refund_abs_ffi k x``;
val _ = check "refund_ffi_contract_on_totalises"
  ``!b dm Vok f. refund_ffi_contract_on b dm Vok f ==> refund_ffi_contract_at b dm (refund_ffi_tot Vok f)``;
val _ = check "refund_env_ok_sl_of_contract_on"
  ``interference_ok (^envmc).next_interfer (arm8_target.proj (^envmc).prog_addresses) /\
    refund_ffi_contract_on (sl + 0x1000040D0w) (^envmc).prog_addresses Vok (^envmc).ffi_interfer ==>
    refund_env_ok_sl sl (^envmc with ffi_interfer := refund_ffi_tot Vok (^envmc).ffi_interfer)``;
val _ = check "refund_ffi_contract_on_all_valid_is_the_stored_contract"
  ``!b dm f. refund_ffi_contract_on b dm (\i nb ms. T) f <=> refund_ffi_contract_at b dm f``;
val _ = check "contract_on_without_totalisation_is_not_the_stored_contract"
  ``~(!b dm Vok f. refund_ffi_contract_on b dm Vok f ==> refund_ffi_contract_at b dm f)``;
val _ = check "refund_ffi_tot_shift_seq" ``!n Vok f. shift_seq n (refund_ffi_tot Vok f) = refund_ffi_tot Vok (shift_seq n f)``;
val _ = check "close_abort_model_fails_stored_contract" ``!dm. ~refund_ffi_contract_at 0x1000040D0w dm refund_close_abort_model_ffi``;
val _ = check "close_abort_model_satisfies_contract_on"
  ``!b dm. refund_ffi_contract_on b dm refund_close_call_valid refund_close_abort_model_ffi``;
(* Controls: wrong statements must NOT be accepted. *)
fun ctl name ok = if ok then pr ("CONTROL_OK " ^ name) else (bad := !bad + 1; pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ name));
val _ = ctl "L1 without totalisation is not the stored L1"
          (not (same "refund_ffi_contract_on_totalises" ``!b dm Vok f. refund_ffi_contract_on b dm Vok f ==> refund_ffi_contract_at b dm f``));
val _ = ctl "the on-definition without the extra hypothesis is not the stored definition"
          (not (same "refund_ffi_contract_on_def" (list_mk_forall ([bv, dmv, Vv, ffiv], mk_eq (on_tm, list_mk_forall (qvs, cimp))))));
val ths = DB.theorems T @ DB.definitions T;
val dirty = List.filter (fn (_, th) => not (clean th)) ths;
val _ = pr ("THEORY " ^ T ^ " theorems " ^ Int.toString (length (DB.theorems T)) ^ " definitions " ^ Int.toString (length (DB.definitions T)) ^
            " unclean " ^ Int.toString (length dirty));
val _ = if null dirty then () else bad := !bad + 1;
val closure = T :: Theory.ancestry T;
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else bad := !bad + 1;
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = pr ("IMPORTED_COUNT " ^ Int.toString (!good) ^ " MISMATCH_COUNT " ^ Int.toString (!bad));
val _ = if !bad = 0 then () else raise Fail "import check failed";
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
