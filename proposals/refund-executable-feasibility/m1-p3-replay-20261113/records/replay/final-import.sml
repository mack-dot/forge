(* Fresh import of forge_simReplay: exact statements, tags, dependency closure, controls. *)
load "lab_to_targetProofTheory";
open preamble labSemTheory targetSemTheory targetPropsTheory asmPropsTheory lab_to_targetProofTheory
     forge_targetInstallPrefixTheory forge_simZeroCaseTheory forge_simLayoutTheory forge_simRootTheory forge_simReplayTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun same a b =
  let fun ok x y = let val (ts, _) = match_term x y in
        List.all (fn {redex, residue} => is_var residue andalso fst (dest_var redex) = fst (dest_var residue)) ts end
  in aconv a b orelse ((ok a b andalso ok b a) handle HOL_ERR _ => false) end;
val closed_def = ``!Inv. lab_step_closed Inv <=>
    (!(s:('a,'c,'ffi) labSem$state) i bs n. Inv s ==> asm_fetch s <> SOME (LabAsm Install i bs n)) /\
    (!s m r ad bs n. Inv s ==> asm_fetch s <> SOME (Asm (ShareMem m r ad) bs n)) /\
    (!s s'. Inv s /\ lab_step s = SOME s' ==> Inv s')``;
val nip_thm = ``lab_step_closed Inv ==>
  !(s1:('a,lab_to_target$config,'ffi) labSem$state) res (mc_conf: ('a,'state,'b) machine_config) s2 code2 labs t1 ms1.
     oracle_tie mc_conf ms1 s1 /\ (labSem$evaluate s1 = (res,s2)) /\ (res <> Error) /\
     encoder_correct mc_conf.target /\ lab_to_targetProof$state_rel (mc_conf,code2,labs,p) s1 t1 ms1 ==>
     Inv s1 /\ code_layout_ok (:'a) code2 ==>
     no_install_prefix mc_conf s1.ffi s1.clock ms1``;
val both_thm = ``lab_step_closed Inv ==>
  !(s1:('a,lab_to_target$config,'ffi) labSem$state) res (mc_conf: ('a,'state,'b) machine_config) s2 code2 labs t1 ms1.
     oracle_tie mc_conf ms1 s1 /\ (labSem$evaluate s1 = (res,s2)) /\ (res <> Error) /\
     encoder_correct mc_conf.target /\ lab_to_targetProof$state_rel (mc_conf,code2,labs,p) s1 t1 ms1 /\
     Inv s1 /\ code_layout_ok (:'a) code2 ==>
     (?k t2 ms2. targetSem$evaluate mc_conf s1.ffi (s1.clock + k) ms1 = (res,ms2,s2.ffi)) /\
     no_install_prefix mc_conf s1.ffi s1.clock ms1``;
val all_thm = ``lab_step_closed Inv /\
  (!k. Inv ((s1:('a,lab_to_target$config,'ffi) labSem$state) with clock := k)) /\
  (!k. FST (labSem$evaluate (s1 with clock := k)) <> Error) /\
  oracle_tie (mc_conf: ('a,'state,'b) machine_config) ms1 s1 /\ encoder_correct mc_conf.target /\
  lab_to_targetProof$state_rel (mc_conf,code2,labs,p) s1 t1 ms1 /\ code_layout_ok (:'a) code2 ==>
  !n. no_install_prefix mc_conf s1.ffi n ms1``;
val expected = [("lab_step_closed_def", closed_def), ("compile_no_install_prefix", nip_thm),
  ("compile_correct_no_install_prefix", both_thm), ("target_install_exclusion_conditional", all_thm),
  ("lab_step_evaluate", ``!(s:('a,'c,'ffi) labSem$state) s'. lab_step s = SOME s' ==> labSem$evaluate s = labSem$evaluate s'``)];
val _ = List.app (fn (n, tm) =>
  let val th = DB.fetch "forge_simReplay" n in
    if same tm (concl th) then () else (pr ("STORED " ^ n ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ n));
    tags n th; pr ("IMPORTED " ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val others = ["seg_finish", "state_rel_ctx", "step_nip", "final_nip"];
val _ = List.app (fn n => (tags n (DB.fetch "forge_simReplay" n); pr ("IMPORTED " ^ n ^ " TAGS_ONLY HYPOTHESES 0 TAGGED_AXIOMS 0"))) others;
val _ = pr ("STORED_THEOREMS " ^ String.concatWith " " (map fst (DB.theorems "forge_simReplay")));
val _ = pr ("STORED_DEFINITIONS " ^ String.concatWith " " (map fst (DB.definitions "forge_simReplay")));
val _ = pr ("LAB_STEP_DEFINITION\n" ^ thm_to_string (DB.fetch "forge_simReplay" "lab_step_def"));
(* Fidelity against the published theorem, recomputed here. *)
val _ = let
    val pub = concl lab_to_targetProofTheory.compile_correct
    val mine = snd (dest_imp (concl (DB.fetch "forge_simReplay" "compile_correct_no_install_prefix")))
    val (mv, mb) = strip_forall mine; val (ma, mc) = dest_imp mb; val mcs = strip_conj ma
    val back = list_mk_forall (mv, mk_imp (list_mk_conj (List.take (mcs, length mcs - 2)), hd (strip_conj mc)))
  in if aconv back pub then pr "FIDELITY published compile_correct recovered" else raise Fail "Fidelity check failed" end;
val _ = pr ("NEGATIVE_CONTROL_KEPT wraparound " ^ thm_to_string (DB.fetch "forge_simZeroCase" "install_entry_wrap_example"));
val _ = pr ("NEGATIVE_CONTROL_KEPT interior " ^ thm_to_string (DB.fetch "forge_simRoot" "endpoint_correspondence_insufficient"));
val _ = pr "AFTER_POSITIVE_AUDIT";
(* Statement controls: forms without a Forge premise are not the stored theorems. *)
val no_inv = ``lab_step_closed Inv ==>
  !(s1:('a,lab_to_target$config,'ffi) labSem$state) res (mc_conf: ('a,'state,'b) machine_config) s2 code2 labs t1 ms1.
     oracle_tie mc_conf ms1 s1 /\ (labSem$evaluate s1 = (res,s2)) /\ (res <> Error) /\
     encoder_correct mc_conf.target /\ lab_to_targetProof$state_rel (mc_conf,code2,labs,p) s1 t1 ms1 ==>
     code_layout_ok (:'a) code2 ==>
     no_install_prefix mc_conf s1.ffi s1.clock ms1``;
val no_sharemem = ``!Inv. lab_step_closed Inv <=>
    (!(s:('a,'c,'ffi) labSem$state) i bs n. Inv s ==> asm_fetch s <> SOME (LabAsm Install i bs n)) /\
    (!s s'. Inv s /\ lab_step s = SOME s' ==> Inv s')``;
val _ = if same no_inv (concl (DB.fetch "forge_simReplay" "compile_no_install_prefix")) orelse
           same no_sharemem (concl (DB.fetch "forge_simReplay" "lab_step_closed_def"))
        then pr "UNEXPECTED_CONTROL_ACCEPTANCE" else pr "CONTROL_OK statements without the invariant premise or the shared-memory clause are not the stored ones";
val closure = "forge_simReplay" :: Theory.ancestry "forge_simReplay";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "P3_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
