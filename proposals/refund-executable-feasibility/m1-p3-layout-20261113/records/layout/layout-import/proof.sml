(* Fresh import with a statement control; the 8-bit wrap example is kept as a negative control. *)
load "lab_to_targetProofTheory";
open preamble labSemTheory targetSemTheory targetPropsTheory asmPropsTheory lab_to_targetProofTheory
     forge_targetInstallPrefixTheory forge_simZeroCaseTheory forge_simLayoutTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val static_expected = ``state_rel (mc_conf,code2,labs,(p:'a word)) s1 t1 ms1 /\ code_layout_ok (:'a) code2 ==>
   no_install_prefix mc_conf ffi 0 (ms1:'state)``;
val expected = [
 ("code_layout_ok_def", ``!code2. code_layout_ok (:'a) code2 <=> LENGTH (prog_to_bytes code2) + 2 * ffi_offset < dimword (:'a)``),
 ("state_rel_no_install_prefix_layout", static_expected),
 ("installed_bound_code_layout", ``cbspace + LENGTH (prog_to_bytes code2) + ffi_offset * (i + 3) < dimword (:'a) ==> code_layout_ok (:'a) code2``)];
val _ = List.app (fn (n, tm) =>
  let val th = DB.fetch "forge_simLayout" n in
    if aconv tm (concl th) then () else raise Fail ("Exact statement mismatch: " ^ n);
    tags n th; pr ("IMPORTED " ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val wrap = DB.fetch "forge_simZeroCase" "install_entry_wrap_example";
val _ = pr ("NEGATIVE_CONTROL_KEPT " ^ thm_to_string wrap);
val th = DB.fetch "forge_simLayout" "state_rel_no_install_prefix_layout";
val without = ``state_rel (mc_conf,code2,labs,(p:'a word)) s1 t1 ms1 ==> no_install_prefix mc_conf ffi 0 (ms1:'state)``;
val _ = pr "AFTER_POSITIVE_AUDIT";
val _ = if aconv without (concl th) then pr "UNEXPECTED_CONTROL_ACCEPTANCE" else pr "CONTROL_OK statement without the layout premise is not the stored one";
val closure = "forge_simLayout" :: Theory.ancestry "forge_simLayout";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "P3_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
