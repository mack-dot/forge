structure forge_refundFficloseBridgeTheory :> forge_refundFficloseBridgeTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundFficloseBridgeTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundEnvModelTheory forge_refundFficloseStepTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundFficloseBridge",
        hash = "67c9abc3a5353bf775f79dfd4de4f010f5b1462d",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundFficloseBridge" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op stub_only_ffi_rejected _ = ()
  val op stub_only_ffi_rejected = TDB.find "stub_only_ffi_rejected"
  fun op refund_stub_only_ffi_def _ = ()
  val op refund_stub_only_ffi_def = TDB.find "refund_stub_only_ffi_def"
  fun op refund_image_fficlose_code _ = ()
  val op refund_image_fficlose_code = TDB.find "refund_image_fficlose_code"
  fun op refund_file_fficlose_words _ = ()
  val op refund_file_fficlose_words = TDB.find "refund_file_fficlose_words"
  fun op cake_fficlose_to_import_branch _ = ()
  val op cake_fficlose_to_import_branch = TDB.find
    "cake_fficlose_to_import_branch"
  fun op cake_fficlose_stub_exact _ = ()
  val op cake_fficlose_stub_exact = TDB.find "cake_fficlose_stub_exact"
  fun op bytes_in_memory_slice _ = ()
  val op bytes_in_memory_slice = TDB.find "bytes_in_memory_slice"
  fun op arm8_run_add _ = () val op arm8_run_add = TDB.find "arm8_run_add"
  fun op altered_stub_word_not_in_file _ = ()
  val op altered_stub_word_not_in_file = TDB.find
    "altered_stub_word_not_in_file"
  fun op altered_stub_byte_rejected _ = ()
  val op altered_stub_byte_rejected = TDB.find "altered_stub_byte_rejected"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundFficloseBridge"

end
