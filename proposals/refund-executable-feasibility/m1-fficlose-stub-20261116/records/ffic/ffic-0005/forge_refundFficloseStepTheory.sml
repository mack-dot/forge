structure forge_refundFficloseStepTheory :> forge_refundFficloseStepTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundFficloseStepTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundCmlMainStepTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundFficloseStep",
        hash = "cd180451514be3bb693e3e85064387067f6a87a5",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundFficloseStep" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op fficlose_suffix_wrong_return_refuted _ = ()
  val op fficlose_suffix_wrong_return_refuted = TDB.find
    "fficlose_suffix_wrong_return_refuted"
  fun op fficlose_suffix_run _ = ()
  val op fficlose_suffix_run = TDB.find "fficlose_suffix_run"
  fun op fficlose_stub_pre_def _ = ()
  val op fficlose_stub_pre_def = TDB.find "fficlose_stub_pre_def"
  fun op fficlose_return_pre_def _ = ()
  val op fficlose_return_pre_def = TDB.find "fficlose_return_pre_def"
  fun op fficlose_prefix_run _ = ()
  val op fficlose_prefix_run = TDB.find "fficlose_prefix_run"
  fun op fficlose_entry_pre_def _ = ()
  val op fficlose_entry_pre_def = TDB.find "fficlose_entry_pre_def"
  fun op fficlose_code_bytes_def _ = ()
  val op fficlose_code_bytes_def = TDB.find "fficlose_code_bytes_def"
  fun op cake_fficlose_stub_wrong_target_refuted _ = ()
  val op cake_fficlose_stub_wrong_target_refuted = TDB.find
    "cake_fficlose_stub_wrong_target_refuted"
  fun op cake_fficlose_stub_run _ = ()
  val op cake_fficlose_stub_run = TDB.find "cake_fficlose_stub_run"
  fun op cake_fficlose_stub_does_not_return _ = ()
  val op cake_fficlose_stub_does_not_return = TDB.find
    "cake_fficlose_stub_does_not_return"
  fun op arm8_user_def _ = ()
  val op arm8_user_def = TDB.find "arm8_user_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundFficloseStep"

end
