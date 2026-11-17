load "targetPropsTheory";
open preamble targetSemTheory targetPropsTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory THEORY_NAME;
(* Every TimeOut prefix of the published target evaluator, up to clock n, has a program
   counter different from the installer entry. For all n this is the U298 exclusion. *)
val nip_def = Define `
  no_install_prefix mc ffi n ms <=>
    !j ms' ffi'. j <= n /\ targetSem$evaluate mc ffi j ms = (TimeOut,ms',ffi') ==>
                 mc.target.get_pc ms' <> mc.install_pc`;
val zero_goal = ``no_install_prefix mc ffi 0 ms <=> mc.target.get_pc ms <> mc.install_pc``;
val mono_goal = ``!n m. no_install_prefix mc ffi n ms /\ m <= n ==> no_install_prefix mc ffi m ms``;
val all_goal = ``(!n. no_install_prefix mc ffi n ms) <=>
   (!j ms' ffi'. targetSem$evaluate mc ffi j ms = (TimeOut,ms',ffi') ==> mc.target.get_pc ms' <> mc.install_pc)``;
val halt_goal = ``mc.target.get_pc ms = mc.halt_pc /\ mc.halt_pc NOTIN mc.prog_addresses /\ mc.halt_pc <> mc.install_pc ==>
   !n. no_install_prefix mc ffi n ms``;
val next_goal = ``mc.target.get_pc ms IN (mc.prog_addresses DIFF set mc.ffi_entry_pcs) /\
   encoded_bytes_in_mem mc.target.config (mc.target.get_pc ms) (mc.target.get_byte ms) mc.prog_addresses /\
   mc.install_pc NOTIN mc.prog_addresses ==>
   (no_install_prefix mc ffi (SUC n) ms <=>
      (EVERY mc.target.state_ok [ms; mc.target.next ms; mc.next_interfer 0 (mc.target.next ms)] /\
       (!x. x NOTIN mc.prog_addresses ==> mc.target.get_byte (mc.target.next ms) x = mc.target.get_byte ms x) ==>
       no_install_prefix (mc with next_interfer := shift_seq 1 mc.next_interfer) ffi n (mc.next_interfer 0 (mc.target.next ms))))``;
val segment_goal = ``(!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io2 k ms2) /\ c2.install_pc = c.install_pc /\ c2.target = c.target /\
   no_install_prefix c io l ms1 /\ no_install_prefix c2 io2 n ms2 ==> no_install_prefix c io (l + n) ms1``;
