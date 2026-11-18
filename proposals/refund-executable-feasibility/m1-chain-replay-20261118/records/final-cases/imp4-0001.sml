(* U409: exact-statement import check for forge_refundSlideProfileA (plan steps S4-S6).
   The expected slide statements are built here from the STORED U404 statements by five substitutions, not from the proof script.
   No theorem is proved or stored. Same machine and cached parents: this is NOT a clean or independent replay. *)
open preamble wordsLib targetSemTheory arm8Theory forge_refundEnvModelTheory forge_refundProfileATheory forge_refundSlideEntryTheory
     forge_refundSlideDomainsTheory forge_refundSlideInstalledTheory forge_refundSlideProfileATheory;
val _ = Globals.max_print_depth := 40;
fun pr s = print (s ^ "\n");
val bad = ref 0; val good = ref 0;
fun clean th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors end;
val T = "forge_refundSlideProfileA";
fun same name tm = let val th = DB.fetch T name in aconv (concl th) tm andalso clean th end handle _ => false;
fun check name tm = if same name tm then (good := !good + 1; pr ("IMPORTED " ^ T ^ "." ^ name)) else (bad := !bad + 1; pr ("IMPORT_MISMATCH " ^ T ^ "." ^ name));
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val envmc = mk_var ("envmc", mcty);
val sl = ``sl:word64``;
val lit = ``0x1000040D0w:word64``; val B = ``sl + 0x1000040D0w:word64``;
fun slide tm = subst [``refund_entry_pre s h stk e`` |-> ``refund_entry_pre_sl sl s h stk e``,
                      ``refund_heap_clear h e`` |-> ``refund_heap_clear_sl sl h e``,
                      ``refund_mem_dm h e`` |-> ``refund_mem_dm_sl sl h e``,
                      ``refund_env_ok ^envmc`` |-> ``refund_env_ok_sl sl ^envmc``,
                      lit |-> B] tm;
val u404 = DB.fetch "forge_refundProfileA" "refund_profile_a_slide0";
val u404r = DB.fetch "forge_refundProfileA" "refund_profile_a_slide0_every_machine_run";
val _ = if clean u404 andalso clean u404r then () else bad := !bad + 1;
val exp_ta = slide (concl u404); val exp_runs = slide (concl u404r);
val _ = if aconv exp_ta (concl u404) then (bad := !bad + 1; pr "SUBSTITUTION_HAD_NO_EFFECT") else pr "SUBSTITUTION_CHANGED_THE_STATEMENT true";
val _ = check "refund_profile_a_sl" exp_ta;
val _ = check "refund_profile_a_sl_every_machine_run" exp_runs;
val _ = check "slide_zero_instance_is_refund_profile_a_slide0" (concl u404);
val _ = check "slide_zero_instance_is_refund_profile_a_slide0_every_machine_run" (concl u404r);
val cdef = DB.fetch "forge_refundEnvModel" "refund_ffi_contract_def";
val (cl0, cr0) = dest_eq (snd (strip_forall (concl cdef)));
val [dmv, ffiv] = snd (strip_comb cl0);
val bv = ``b:word64``;
val _ = check "refund_ffi_contract_at_def" (list_mk_forall ([bv, dmv, ffiv], mk_eq (``refund_ffi_contract_at ^bv ^dmv ^ffiv``, subst [lit |-> bv] cr0)));
val _ = check "refund_env_ok_sl_def" ``!sl envmc. refund_env_ok_sl sl envmc <=>
      interference_ok envmc.next_interfer (arm8_target.proj envmc.prog_addresses) /\
      refund_ffi_contract_at (sl + 0x1000040D0w) envmc.prog_addresses envmc.ffi_interfer``;
val _ = check "ffi_interfer_ok_iff_contract_sl" ``ffi_interfer_ok ^B (refund_mc ^B ^envmc) <=>
      refund_ffi_contract_at ^B (^envmc).prog_addresses (^envmc).ffi_interfer``;
val _ = check "refund_env_ok_sl_iff_installed_residual"
  ``!ms. ms.PC = ^B ==> (refund_installed_rest2 (refund_mc ^B ^envmc) ms <=> refund_env_ok_sl sl ^envmc)``;
val _ = check "refund_ffi_contract_at_link_base_is_the_old_contract" ``!dm f. refund_ffi_contract_at 0x1000040D0w dm f <=> refund_ffi_contract dm f``;
val _ = check "refund_abs_ffi_contract_at" ``!b dm. refund_ffi_contract_at b dm refund_abs_ffi``;
val _ = check "refund_abs_env_is_ok_sl" ``refund_env_ok_sl sl (refund_abs_env ^envmc)``;
val _ = check "refund_env_ok_sl_at_slide_zero" ``refund_env_ok_sl 0w ^envmc <=> refund_env_ok ^envmc``;
val _ = check "stub_guard_ffi_satisfies_contract_at_its_base" ``!b dm. refund_ffi_contract_at b dm (refund_stub_guard_ffi b)``;
val _ = check "slide_zero_stub_guard_ffi_fails_contract_at_slide_0x4000"
  ``!dm. ~refund_ffi_contract_at 0x1000080D0w dm (refund_stub_guard_ffi 0x1000040D0w)``;
val _ = check "refund_profile_a_sl_machine_premises_satisfiable_at_0x4000"
  ``?s h stk e (envmc : ^(ty_antiq mcty)). refund_entry_pre_sl 0x4000w s h stk e /\ aligned 3 e /\ h <=+ e /\ 8192w <=+ e - h /\
       refund_heap_clear_sl 0x4000w h e /\ envmc.prog_addresses = refund_mem_dm_sl 0x4000w h e /\ refund_env_ok_sl 0x4000w envmc``;
val ths = DB.theorems T @ DB.definitions T;
val dirty = List.filter (fn (_, th) => not (clean th)) ths;
val _ = pr ("THEORY " ^ T ^ " theorems " ^ Int.toString (length (DB.theorems T)) ^ " definitions " ^ Int.toString (length (DB.definitions T)) ^
            " unclean " ^ Int.toString (length dirty));
val _ = if null dirty then () else bad := !bad + 1;
fun ctl name ok = if ok then pr ("CONTROL_OK " ^ name) else (bad := !bad + 1; pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ name));
val _ = ctl "the slide theorem without the environment premise is not the stored theorem"
          (not (same "refund_profile_a_sl" (let val (a, c) = dest_imp exp_ta in mk_imp (list_mk_conj (List.filter (fn t => not (aconv t ``refund_env_ok_sl sl ^envmc``)) (strip_conj a)), c) end)));
val _ = ctl "the unsubstituted U404 statement is not the stored slide theorem" (not (same "refund_profile_a_sl" (concl u404)));
val _ = ctl "environment predicate at the link base is not the stored slide definition"
          (not (same "refund_env_ok_sl_def" ``!sl envmc. refund_env_ok_sl sl envmc <=>
      interference_ok envmc.next_interfer (arm8_target.proj envmc.prog_addresses) /\
      refund_ffi_contract_at 0x1000040D0w envmc.prog_addresses envmc.ffi_interfer``));
val closure = T :: Theory.ancestry T;
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else bad := !bad + 1;
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = pr ("IMPORTED_COUNT " ^ Int.toString (!good) ^ " MISMATCH_COUNT " ^ Int.toString (!bad));
val _ = if !bad = 0 then () else raise Fail "import check failed";
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
