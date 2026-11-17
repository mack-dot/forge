(* Fresh import of forge_simRoot: exact statements, tags, dependency closure, negative controls. *)
load "lab_to_targetProofTheory";
open preamble labSemTheory targetSemTheory targetPropsTheory asmPropsTheory lab_to_targetProofTheory
     forge_targetInstallPrefixTheory forge_simZeroCaseTheory forge_simLayoutTheory forge_simRootTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
(* Equal up to renaming of type variables; term variables keep their names. *)
fun same a b =
  let fun ok x y = let val (ts, _) = match_term x y in
        List.all (fn {redex, residue} => is_var residue andalso fst (dest_var redex) = fst (dest_var residue)) ts end
  in aconv a b orelse ((ok a b andalso ok b a) handle HOL_ERR _ => false) end;
val interior = ``!j ms' io'. j < l /\ targetSem$evaluate c io j ms1 = (TimeOut,ms',io') ==>
     c.target.get_pc ms' IN (c.prog_addresses DIFF set c.ffi_entry_pcs)``;
val expected = [
 ("run_head_ordinary", ``l <> 0 /\ find_next_interference c io l ms = NONE /\ targetSem$evaluate c io l ms = (TimeOut,ms2,io2) ==>
     c.target.get_pc ms IN (c.prog_addresses DIFF set c.ffi_entry_pcs)``),
 ("run_interior_ordinary", ``!l c io ms ms2 io2. find_next_interference c io l ms = NONE /\ targetSem$evaluate c io l ms = (TimeOut,ms2,io2) ==>
     !j ms' io'. j < l /\ targetSem$evaluate c io j ms = (TimeOut,ms',io') ==>
       c.target.get_pc ms' IN (c.prog_addresses DIFF set c.ffi_entry_pcs)``),
 ("segment_interior_ordinary", ``(!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io2 k ms2 /\
        find_next_interference c io (k + l) ms1 = find_next_interference c2 io2 k (ms2:'state)) ==>
     !j ms' io'. j < l /\ targetSem$evaluate c io j ms1 = (TimeOut,ms',io') ==>
       c.target.get_pc ms' IN (c.prog_addresses DIFF set c.ffi_entry_pcs)``),
 ("segment_end_no_install_prefix", ``(!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io2 k ms2 /\
        find_next_interference c io (k + l) ms1 = find_next_interference c2 io2 k (ms2:'state)) /\ l <> 0 /\
     c.install_pc NOTIN c.prog_addresses ==>
     no_install_prefix c io (l - 1) ms1 /\ (c.target.get_pc ms2 <> c.install_pc ==> no_install_prefix c io l ms1)``),
 ("segment_compose_no_install_prefix", ``(!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io2 k ms2 /\
        find_next_interference c io (k + l) ms1 = find_next_interference c2 io2 k (ms2:'state)) /\
     c.install_pc NOTIN c.prog_addresses /\ c2.install_pc = c.install_pc /\ c2.target = c.target /\
     no_install_prefix c2 io2 n ms2 ==> no_install_prefix c io (l + n) ms1``),
 ("asm_step_IMP_evaluate_step_find_next_prefix", ``!c s1 ms1 io i.
      encoder_correct c.target /\ (c.prog_addresses = s1.mem_domain) /\
      ffi_entry_pcs_disjoint c s1 (LENGTH (c.target.config.encode i)) /\
      interference_ok c.next_interfer (c.target.proj s1.mem_domain) /\
      asm_step c.target.config s1 i (asm i (s1.pc + n2w (LENGTH (c.target.config.encode i))) s1) /\
      target_state_rel c.target (s1:'a asm_state) (ms1:'state) ==>
      ?l ms2. (!k. (targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate (shift_interfer l c) io k ms2) /\
                  (find_next_interference c io (k + l) ms1 = find_next_interference (shift_interfer l c) io k ms2) /\
                  target_state_rel c.target (asm i (s1.pc + n2w (LENGTH (c.target.config.encode i))) s1) ms2 /\ l <> 0) /\
              (!j ms' io'. j < l /\ targetSem$evaluate c io j ms1 = (TimeOut,ms',io') ==>
                  c.target.get_pc ms' IN (c.prog_addresses DIFF set c.ffi_entry_pcs)) /\
              (c.install_pc NOTIN c.prog_addresses ==>
                 no_install_prefix c io (l - 1) ms1 /\
                 ((asm i (s1.pc + n2w (LENGTH (c.target.config.encode i))) s1).pc <> c.install_pc ==> no_install_prefix c io l ms1))``),
 ("asm_step_IMP_evaluate_step_nop_prefix", ``!c s1 ms1 io i s2 bytes.
      encoder_correct c.target /\ c.prog_addresses = s1.mem_domain /\
      ffi_entry_pcs_disjoint c s1 (LENGTH bytes) /\
      interference_ok c.next_interfer (c.target.proj s1.mem_domain) /\
      bytes_in_memory s1.pc bytes s2.mem s1.mem_domain /\
      asm_step_nop bytes c.target.config s1 i s2 /\
      s2 = asm i (s1.pc + n2w (LENGTH bytes)) s1 /\
      target_state_rel c.target (s1:'a asm_state) (ms1:'state) /\ (!x. i <> Call x) ==>
      ?l ms2. (!k. (targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate (shift_interfer l c) io k ms2) /\
                  (find_next_interference c io (k + l) ms1 = find_next_interference (shift_interfer l c) io k ms2) /\
                  target_state_rel c.target s2 ms2 /\ l <> 0) /\
              (!j ms' io'. j < l /\ targetSem$evaluate c io j ms1 = (TimeOut,ms',io') ==>
                  c.target.get_pc ms' IN (c.prog_addresses DIFF set c.ffi_entry_pcs)) /\
              (c.install_pc NOTIN c.prog_addresses ==>
                 no_install_prefix c io (l - 1) ms1 /\ (s2.pc <> c.install_pc ==> no_install_prefix c io l ms1))``),
 ("asm_step_IMP_evaluate_step_prefix", ``!c s1 ms1 io i.
      encoder_correct c.target /\ (c.prog_addresses = s1.mem_domain) /\
      ffi_entry_pcs_disjoint c s1 (LENGTH (c.target.config.encode i)) /\
      interference_ok c.next_interfer (c.target.proj s1.mem_domain) /\
      asm_step c.target.config s1 i (asm i (s1.pc + n2w (LENGTH (c.target.config.encode i))) s1) /\
      target_state_rel c.target (s1:'a asm_state) (ms1:'state) ==>
      ?l ms2. ((!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate (shift_interfer l c) io k ms2) /\
               target_state_rel c.target (asm i (s1.pc + n2w (LENGTH (c.target.config.encode i))) s1) ms2 /\ l <> 0) /\
              (!j ms' io'. j < l /\ targetSem$evaluate c io j ms1 = (TimeOut,ms',io') ==>
                  c.target.get_pc ms' IN (c.prog_addresses DIFF set c.ffi_entry_pcs)) /\
              (c.install_pc NOTIN c.prog_addresses ==>
                 no_install_prefix c io (l - 1) ms1 /\
                 ((asm i (s1.pc + n2w (LENGTH (c.target.config.encode i))) s1).pc <> c.install_pc ==> no_install_prefix c io l ms1))``),
 ("state_rel_segment_compose", ``lab_to_targetProof$state_rel (c,code2,labs,(p:'a word)) s1 t1 (ms1:'state) /\
     (!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io2 k ms2 /\
          find_next_interference c io (k + l) ms1 = find_next_interference c2 io2 k (ms2:'state)) /\
     c2.install_pc = c.install_pc /\ c2.target = c.target /\ no_install_prefix c2 io2 n ms2 ==>
     no_install_prefix c io (l + n) ms1``),
 ("interior_install_example", ``(!k (io:'ffi ffi_state). targetSem$evaluate forge_toy_mc io (k + 2) 0 = targetSem$evaluate forge_toy_mc2 io k 2) /\
     forge_toy_mc2.install_pc = forge_toy_mc.install_pc /\ forge_toy_mc2.target = forge_toy_mc.target /\
     forge_toy_mc.install_pc NOTIN forge_toy_mc.prog_addresses /\
     forge_toy_mc.target.get_pc 0 <> forge_toy_mc.install_pc /\ forge_toy_mc.target.get_pc 2 <> forge_toy_mc.install_pc /\
     (!io:'ffi ffi_state. ~no_install_prefix forge_toy_mc io 2 0) /\
     (!io:'ffi ffi_state. find_next_interference forge_toy_mc io 2 0 <> find_next_interference forge_toy_mc2 io 0 2)``),
 ("endpoint_correspondence_insufficient", ``~(!(c:(8,num,unit) machine_config) c2 (io:'ffi ffi_state) l ms1 ms2.
     (!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io k ms2) /\ c2.install_pc = c.install_pc /\ c2.target = c.target /\
     c.install_pc NOTIN c.prog_addresses /\ c.target.get_pc ms1 <> c.install_pc /\ c.target.get_pc ms2 <> c.install_pc ==>
     no_install_prefix c io l ms1)``)];
val _ = List.app (fn (n, tm) =>
  let val th = DB.fetch "forge_simRoot" n in
    if same tm (concl th) then () else raise Fail ("Exact statement mismatch: " ^ n);
    tags n th; pr ("IMPORTED " ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val stored = map fst (DB.theorems "forge_simRoot");
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length stored) ^ " EXPECTED " ^ Int.toString (length expected));
val _ = if length stored = length expected then () else raise Fail "Theorem count mismatch";
val _ = List.app (fn (n, th) => pr ("DEFINITION " ^ n ^ "\n" ^ thm_to_string th)) (DB.definitions "forge_simRoot");
(* Negative controls. *)
val wrap = DB.fetch "forge_simZeroCase" "install_entry_wrap_example";
val _ = pr ("NEGATIVE_CONTROL_KEPT wraparound " ^ thm_to_string wrap);
val _ = pr ("NEGATIVE_CONTROL_KEPT interior " ^ thm_to_string (DB.fetch "forge_simRoot" "endpoint_correspondence_insufficient"));
val _ = pr "AFTER_POSITIVE_AUDIT";
(* Statement controls: weaker-premise forms are not the stored theorems. *)
val no_len = ``(!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io2 k ms2 /\
        find_next_interference c io (k + l) ms1 = find_next_interference c2 io2 k (ms2:'state)) /\
     c.install_pc NOTIN c.prog_addresses ==>
     no_install_prefix c io (l - 1) ms1 /\ (c.target.get_pc ms2 <> c.install_pc ==> no_install_prefix c io l ms1)``;
val no_trace = ``(!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io2 k (ms2:'state)) /\
     c.install_pc NOTIN c.prog_addresses /\ c2.install_pc = c.install_pc /\ c2.target = c.target /\
     no_install_prefix c2 io2 n ms2 ==> no_install_prefix c io (l + n) ms1``;
val _ = if same no_len (concl (DB.fetch "forge_simRoot" "segment_end_no_install_prefix")) orelse
           same no_trace (concl (DB.fetch "forge_simRoot" "segment_compose_no_install_prefix"))
        then pr "UNEXPECTED_CONTROL_ACCEPTANCE" else pr "CONTROL_OK weaker-premise statements are not the stored ones";
(* The checker itself rejects a changed statement. *)
val _ = if same ``l <> 0 /\ find_next_interference c io l ms = NONE ==> c.target.get_pc ms IN (c.prog_addresses DIFF set c.ffi_entry_pcs)``
               (concl (DB.fetch "forge_simRoot" "run_head_ordinary"))
        then pr "UNEXPECTED_CONTROL_ACCEPTANCE" else pr "CONTROL_OK checker rejects a changed statement";
val closure = "forge_simRoot" :: Theory.ancestry "forge_simRoot";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "P3_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
