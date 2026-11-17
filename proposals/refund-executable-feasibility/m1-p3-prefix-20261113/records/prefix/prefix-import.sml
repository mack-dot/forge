(* Fresh import; expected statements are written out. *)
load "targetPropsTheory";
open preamble targetSemTheory targetPropsTheory forge_targetInstallPrefixTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val segment_expected = ``(!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io2 k ms2) /\ c2.install_pc = c.install_pc /\ c2.target = c.target /\
   no_install_prefix c io l ms1 /\ no_install_prefix c2 io2 n ms2 ==> no_install_prefix c io (l + n) ms1``;
val expected = [
 ("no_install_prefix_def", ``!mc ffi n ms. no_install_prefix mc ffi n ms <=>
    !j ms' ffi'. j <= n /\ targetSem$evaluate mc ffi j ms = (TimeOut,ms',ffi') ==> mc.target.get_pc ms' <> mc.install_pc``),
 ("no_install_prefix_zero", ``no_install_prefix mc ffi 0 ms <=> mc.target.get_pc ms <> mc.install_pc``),
 ("no_install_prefix_all", ``(!n. no_install_prefix mc ffi n ms) <=>
   (!j ms' ffi'. targetSem$evaluate mc ffi j ms = (TimeOut,ms',ffi') ==> mc.target.get_pc ms' <> mc.install_pc)``),
 ("no_install_prefix_halt", ``mc.target.get_pc ms = mc.halt_pc /\ mc.halt_pc NOTIN mc.prog_addresses /\ mc.halt_pc <> mc.install_pc ==>
   !n. no_install_prefix mc ffi n ms``),
 ("no_install_prefix_next", ``mc.target.get_pc ms IN (mc.prog_addresses DIFF set mc.ffi_entry_pcs) /\
   encoded_bytes_in_mem mc.target.config (mc.target.get_pc ms) (mc.target.get_byte ms) mc.prog_addresses /\
   mc.install_pc NOTIN mc.prog_addresses ==>
   (no_install_prefix mc ffi (SUC n) ms <=>
      (EVERY mc.target.state_ok [ms; mc.target.next ms; mc.next_interfer 0 (mc.target.next ms)] /\
       (!x. x NOTIN mc.prog_addresses ==> mc.target.get_byte (mc.target.next ms) x = mc.target.get_byte ms x) ==>
       no_install_prefix (mc with next_interfer := shift_seq 1 mc.next_interfer) ffi n (mc.next_interfer 0 (mc.target.next ms))))``),
 ("no_install_prefix_segment", segment_expected)];
val _ = List.app (fn (n, tm) =>
  let val th = DB.fetch "forge_targetInstallPrefix" n in
    if aconv tm (concl th) then () else raise Fail ("Exact statement mismatch: " ^ n);
    tags n th; pr ("IMPORTED " ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val closure = "forge_targetInstallPrefix" :: Theory.ancestry "forge_targetInstallPrefix";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "P3_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
