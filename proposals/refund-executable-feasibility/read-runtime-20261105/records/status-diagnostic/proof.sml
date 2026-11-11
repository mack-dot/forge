open preamble fsFFITheory fsFFIPropsTheory;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_READ_OUT"));
val _ = Globals.max_print_depth := 1000;
val _ = new_theory "forge_refundReadBoundary";

val read_ready = store_thm ("read_ready", ``
  ALOOKUP fs.infds fd = SOME (ino,ReadMode,off) ∧
  ALOOKUP fs.inode_tbl ino = SOME content ∧
  LHD fs.numchars = SOME read_quota ⇒
  read fd fs n = SOME
    (TAKE (MIN n (MIN (LENGTH content - off) (SUC read_quota))) (DROP off content),
     bumpFD fd fs (MIN n (MIN (LENGTH content - off) (SUC read_quota))))``,
  simp [read_def]);

val ffi_read_ready = store_thm ("ffi_read_ready", ``
  LENGTH conf = 8 ∧ LENGTH read_tail ≥ w22n [n1;n0] ∧
  read (w82n conf) fs (w22n [n1;n0]) = SOME (read_chars,fs') ⇒
  ffi_read conf (n1::n0::pad1::pad2::read_tail) fs = SOME
    (FFIreturn (0w :: n2w2 (LENGTH read_chars) ++ [pad2] ++
      MAP (n2w o ORD) read_chars ++ DROP (LENGTH read_chars) read_tail) fs')``,
  simp [ffi_read_def]);

open proofManagerLib;
val _ = g (`
  LENGTH conf = 8 ∧ LENGTH read_tail ≥ w22n [n1;n0] ∧
  ALOOKUP fs.infds (w82n conf) = SOME (ino,ReadMode,off) ∧
  ALOOKUP fs.inode_tbl ino = SOME content ∧
  LHD fs.numchars = SOME read_quota ∧
  ffi_read conf (n1::n0::pad1::pad2::read_tail) fs = SOME (FFIreturn bytes' fs') ⇒
  HD bytes' = 0w`);
val _ = e (rw [ffi_read_def,read_def] >> fs []);
val _ = List.app (fn (hs,tm) =>
 (List.app (fn h => print ("DIAG_HYP " ^ Parse.term_to_string h ^ "\n")) hs;
  print ("DIAG_GOAL " ^ Parse.term_to_string tm ^ "\n"))) (top_goals ());
val _ = print "READ_MODEL_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;
