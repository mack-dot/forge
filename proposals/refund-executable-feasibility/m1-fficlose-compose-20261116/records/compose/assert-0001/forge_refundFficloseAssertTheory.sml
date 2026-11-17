structure forge_refundFficloseAssertTheory :> forge_refundFficloseAssertTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundFficloseAssertTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundFficloseStepTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundFficloseAssert",
        hash = "ab346c765207a4a2a98a91d7df2bb2719623dc4a",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundFficloseAssert" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op fficlose_clen_bad_reaches_assert _ = ()
  val op fficlose_clen_bad_reaches_assert = TDB.find
    "fficlose_clen_bad_reaches_assert"
  fun op fficlose_clen_bad_pre_def _ = ()
  val op fficlose_clen_bad_pre_def = TDB.find "fficlose_clen_bad_pre_def"
  fun op fficlose_alen_zero_reaches_assert _ = ()
  val op fficlose_alen_zero_reaches_assert = TDB.find
    "fficlose_alen_zero_reaches_assert"
  fun op fficlose_alen_zero_pre_def _ = ()
  val op fficlose_alen_zero_pre_def = TDB.find "fficlose_alen_zero_pre_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundFficloseAssert"

end
