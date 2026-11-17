(* Fresh import with a statement control. *)
load "lab_to_targetProofTheory";
open preamble targetSemTheory targetPropsTheory asmPropsTheory lab_to_targetProofTheory forge_targetInstallPrefixTheory forge_simZeroCaseTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val expected = [
 ("install_entry_distinct", ``!(p:'a word) x. x + 2 * ffi_offset < dimword (:'a) ==> p + n2w x <> p - n2w (2 * ffi_offset)``),
 ("state_rel_no_install_prefix_zero", ``state_rel (mc_conf,code2,labs,(p:'a word)) s1 t1 ms1 /\
   pos_val s1.pc 0 code2 + 2 * ffi_offset < dimword (:'a) ==> no_install_prefix mc_conf ffi 0 (ms1:'state)``),
 ("install_entry_wrap_example", ``(0w:word8) + n2w 224 = 0w - n2w (2 * ffi_offset)``)];
val _ = List.app (fn (n, tm) =>
  let val th = DB.fetch "forge_simZeroCase" n in
    if aconv tm (concl th) then () else raise Fail ("Exact statement mismatch: " ^ n);
    tags n th; pr ("IMPORTED " ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val closure = "forge_simZeroCase" :: Theory.ancestry "forge_simZeroCase";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val th = DB.fetch "forge_simZeroCase" "state_rel_no_install_prefix_zero";
val without = ``state_rel (mc_conf,code2,labs,(p:'a word)) s1 t1 ms1 ==> no_install_prefix mc_conf ffi 0 (ms1:'state)``;
val _ = pr "AFTER_POSITIVE_AUDIT";
val _ = if aconv without (concl th) then pr "UNEXPECTED_CONTROL_ACCEPTANCE" else pr "CONTROL_OK statement without the layout bound is not the stored one";
val _ = pr "P3_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
