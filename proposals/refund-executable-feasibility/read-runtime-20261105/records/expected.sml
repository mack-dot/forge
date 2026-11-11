open preamble fsFFITheory fsFFIPropsTheory;
val expected_read_ready = ``
  ALOOKUP fs.infds fd = SOME (ino,ReadMode,off) ∧
  ALOOKUP fs.inode_tbl ino = SOME content ∧
  LHD fs.numchars = SOME read_quota ⇒
  read fd fs n = SOME
    (TAKE (MIN n (MIN (LENGTH content - off) (SUC read_quota))) (DROP off content),
     bumpFD fd fs (MIN n (MIN (LENGTH content - off) (SUC read_quota))))``;
val expected_ffi_read_ready = ``
  LENGTH conf = 8 ∧ LENGTH read_tail ≥ w22n [n1;n0] ∧
  read (w82n conf) fs (w22n [n1;n0]) = SOME (read_chars,fs') ⇒
  ffi_read conf (n1::n0::pad1::pad2::read_tail) fs = SOME
    (FFIreturn (0w :: n2w2 (LENGTH read_chars) ++ [pad2] ++
      MAP (n2w o ORD) read_chars ++ DROP (LENGTH read_chars) read_tail) fs')``;
val expected_ffi_read_ready_status = ``
  LENGTH conf = 8 ∧ LENGTH read_tail ≥ w22n [n1;n0] ∧
  ALOOKUP fs.infds (w82n conf) = SOME (ino,ReadMode,off) ∧
  ALOOKUP fs.inode_tbl ino = SOME content ∧
  LHD fs.numchars = SOME read_quota ∧
  ffi_read conf (n1::n0::pad1::pad2::read_tail) fs = SOME (FFIreturn bytes' fs') ⇒
  HD bytes' = 0w``;
val expected_ffi_read_unavailable = ``
  LENGTH conf = 8 ∧ LENGTH read_tail ≥ w22n [n1;n0] ∧
  read (w82n conf) fs (w22n [n1;n0]) = NONE ⇒
  ffi_read conf (n1::n0::pad1::pad2::read_tail) fs =
    SOME (FFIreturn (1w::n0::pad1::pad2::read_tail) fs)``;
