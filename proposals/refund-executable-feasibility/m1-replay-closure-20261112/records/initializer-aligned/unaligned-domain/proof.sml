load "forge_refundArm8ProofTheory";
open preamble backendProofTheory arm8_configProofTheory targetPropsTheory
     forge_refundSuccessfulInitializationTheory forge_refundInitializationStaticTheory
     forge_refundInitialStackCodeTheory forge_refundInitializerMachineTheory forge_refundInitializerAlignedTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
(* Construction of the statement from the audited six-premise theorem (U349). *)
val base = forge_refundInitializerMachineTheory.refund_initialization_machine;
fun var name = hd (List.filter (fn v => fst (dest_var v) = name) (free_vars (concl base)));
val dm = var "dm";
val sdm = var "sdm";
val base2 = INST [dm |-> ``^dm INTER byte_aligned``, sdm |-> ``^sdm INTER byte_aligned``] base;
val (ante, conclusion) = dest_imp (concl base2);
val conds = strip_conj ante;
val _ = if length conds = 6 then () else raise Fail "Base theorem does not have 6 premises";
fun has_const name t = can (find_term (fn c => is_const c andalso fst (dest_const c) = name)) t;
fun is_kept t = has_const "is_arm8_machine_config" t orelse has_const "memory_assumption" t;
val kept = List.filter is_kept conds;
val discharged = List.filter (not o is_kept) conds;
val _ = if length kept = 2 andalso length discharged = 4 then () else raise Fail "Unexpected premise split";
val goal = mk_imp (list_mk_conj kept, conclusion);
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val th = forge_refundInitializerAlignedTheory.refund_initialization_aligned;
val (th_ante, th_concl) = dest_imp (concl th);
val th_conds = strip_conj th_ante;
val _ = if aconv goal (concl th) then () else raise Fail "Exact statement mismatch: refund_initialization_aligned";
val _ = if length th_conds = 2 then () else raise Fail "Wrong complete premise count";
val _ = if has_const "is_arm8_machine_config" (hd th_conds) andalso has_const "memory_assumption" (el 2 th_conds)
  then () else raise Fail "Kept premises are not the predicate and memory_assumption";
val _ = if ListPair.allEq (fn (a, b) => aconv a b) (th_conds, kept) then () else raise Fail "Kept premises differ";
val _ = if aconv th_concl conclusion then () else raise Fail "Exact conclusion mismatch";
val _ = tags "refund_initialization_aligned" th;
val _ = if length (DB.theorems "forge_refundInitializerAligned") = 1 then () else raise Fail "Unexpected theorem count";
val _ = pr "IMPORTED_THEOREM refund_initialization_aligned";
val _ = List.app (fn c => pr ("KEPT_PREMISE " ^
  String.substring (term_to_string c, 0, Int.min (200, size (term_to_string c))))) th_conds;
val closure = Lib.mk_set ("forge_refundInitializerAligned" :: Theory.ancestry "forge_refundInitializerAligned");
val _ = List.app (fn n => pr ("CLOSURE_NODE " ^ n ^ ":" ^ String.concatWith "," (Theory.parents n))) closure;
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "AFTER_POSITIVE_AUDIT";
(* Altered claim: the same two premises for arbitrary dm and sdm, without the byte-aligned restriction. *)
val altered = let val (a, c) = dest_imp (concl base) val cs = strip_conj a in mk_imp (list_mk_conj (List.filter is_kept cs), c) end;
val _ = if aconv altered goal then raise Fail "Control statement equals the original" else ();
val _ = if aconv altered (concl th) then () else raise Fail "Exact statement mismatch: unaligned memory domains";
val _ = pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = OS.Process.exit OS.Process.success;
