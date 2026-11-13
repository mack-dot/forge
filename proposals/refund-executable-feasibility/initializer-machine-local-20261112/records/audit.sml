load "forge_refundArm8ProofTheory";
open preamble backendProofTheory arm8_configProofTheory forge_refundSuccessfulInitializationTheory
     forge_refundInitializationStaticTheory forge_refundInitialStackCodeTheory
     forge_refundInitializerMachineTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
(* Construction of the statement from the audited 14-condition theorem (U347). *)
val base = forge_refundInitialStackCodeTheory.refund_initialization_code;
val pred = ``arm8_configProof$is_arm8_machine_config``;
val mc0 = hd (List.filter (fn v => fst (dest_var v) = "mc") (free_vars (concl base)));
val theta = match_type (type_of mc0) (fst (dom_rng (type_of pred)));
val base1 = INST_TYPE theta base;
val mc = inst theta mc0;
val save = hd (List.filter (fn v => fst (dest_var v) = "save_regs") (free_vars (concl base1)));
val base2 = INST [save |-> ``set (^mc).callee_saved_regs``] base1;
val (ante, conclusion) = dest_imp (concl base2);
val conds = strip_conj ante;
val _ = if length conds = 14 then () else raise Fail "Base theorem does not have 14 conditions";
fun only_mc t = List.all (fn v => aconv v mc) (free_vars t);
val kept = List.filter (not o only_mc) conds;
val discharged = List.filter only_mc conds;
val _ = if length kept = 5 andalso length discharged = 9 then () else raise Fail "Unexpected condition split";
val goal = mk_imp (list_mk_conj (mk_comb (pred, mc) :: kept), conclusion);
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val th = forge_refundInitializerMachineTheory.refund_initialization_machine;
val (th_ante, th_concl) = dest_imp (concl th);
val th_conds = strip_conj th_ante;
val _ = if aconv goal (concl th) then () else raise Fail "Exact statement mismatch: refund_initialization_machine";
val _ = if length th_conds = 6 then () else raise Fail "Wrong complete premise count";
val _ = if aconv (hd th_conds) (mk_comb (pred, mc)) then () else raise Fail "First premise is not the machine-config predicate";
val _ = if ListPair.allEq (fn (a, b) => aconv a b) (tl th_conds, kept) then () else raise Fail "Kept premises differ";
val _ = if aconv th_concl conclusion then () else raise Fail "Exact conclusion mismatch";
val _ = tags "refund_initialization_machine" th;
val _ = if length (DB.theorems "forge_refundInitializerMachine") = 1 then () else raise Fail "Unexpected theorem count";
val _ = pr "IMPORTED_THEOREM refund_initialization_machine";
val _ = List.app (fn c => pr ("KEPT_PREMISE " ^
  String.substring (term_to_string c, 0, Int.min (200, size (term_to_string c))))) th_conds;
val closure = Lib.mk_set ("forge_refundInitializerMachine" :: Theory.ancestry "forge_refundInitializerMachine");
val _ = List.app (fn n => pr ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n))) closure;
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "TRACE_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
