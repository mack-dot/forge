open preamble fsFFITheory fsFFIPropsTheory;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_READ_OUT"));
val _ = Globals.max_print_depth := 1000;
val _ = new_theory "forge_refundReadBoundary";

val read_ready = store_thm ("read_ready", ``
  ALOOKUP fs.infds fd = SOME (ino,ReadMode,off) ∧
  ALOOKUP fs.inode_tbl ino = SOME content ∧
  LHD fs.numchars = SOME choice ⇒
  read fd fs n = SOME
    (TAKE (MIN n (MIN (LENGTH content - off) (SUC choice))) (DROP off content),
     bumpFD fd fs (MIN n (MIN (LENGTH content - off) (SUC choice))))``,
  simp [read_def]);

val ffi_read_ready = store_thm ("ffi_read_ready", ``
  LENGTH conf = 8 ∧ LENGTH tail ≥ w22n [n1;n0] ∧
  read (w82n conf) fs (w22n [n1;n0]) = SOME (chars,fs') ⇒
  ffi_read conf (n1::n0::pad1::pad2::tail) fs = SOME
    (FFIreturn (0w :: n2w2 (LENGTH chars) ++ [pad2] ++
      MAP (n2w o ORD) chars ++ DROP (LENGTH chars) tail) fs')``,
  simp [ffi_read_def]);

val ffi_read_ready_status = store_thm ("ffi_read_ready_status", ``
  LENGTH conf = 8 ∧ LENGTH tail ≥ w22n [n1;n0] ∧
  ALOOKUP fs.infds (w82n conf) = SOME (ino,ReadMode,off) ∧
  ALOOKUP fs.inode_tbl ino = SOME content ∧
  LHD fs.numchars = SOME choice ∧
  ffi_read conf (n1::n0::pad1::pad2::tail) fs = SOME (FFIreturn bytes' fs') ⇒
  HD bytes' = 0w``,
  rw [ffi_read_def,read_def] >> fs []);

val ffi_read_unavailable = store_thm ("ffi_read_unavailable", ``
  LENGTH conf = 8 ∧ LENGTH tail ≥ w22n [n1;n0] ∧
  read (w82n conf) fs (w22n [n1;n0]) = NONE ⇒
  ffi_read conf (n1::n0::pad1::pad2::tail) fs =
    SOME (FFIreturn (1w::n0::pad1::pad2::tail) fs)``,
  simp [ffi_read_def]);

val checked = [("read_ready",read_ready), ("ffi_read_ready",ffi_read_ready),
               ("ffi_read_ready_status",ffi_read_ready_status),
               ("ffi_read_unavailable",ffi_read_unavailable)];
val _ = List.app (fn (name,th) =>
  let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
    if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
    then () else raise Fail ("Unexpected assumptions: " ^ name);
    print ("CHECKED " ^ name ^ "\n" ^ Parse.thm_to_string th ^ "\n")
  end) checked;
val _ = export_theory ();
val _ = print "READ_MODEL_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;
