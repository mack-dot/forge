structure forge_refundEntryTheory :> forge_refundEntryTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundEntryTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundGuardTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundEntry",
        hash = "ba149e7e53efe883c4988c7accdf304132d79095",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundEntry" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op single_recursive_call _ = ()
  val op single_recursive_call = TDB.find "single_recursive_call"
  fun op refund_tail_rejects_in_env _ = ()
  val op refund_tail_rejects_in_env = TDB.find "refund_tail_rejects_in_env"
  fun op refund_main_call_env_def _ = ()
  val op refund_main_call_env_def = TDB.find "refund_main_call_env_def"
  fun op refund_actual_prefix_rejects _ = ()
  val op refund_actual_prefix_rejects = TDB.find
    "refund_actual_prefix_rejects"
  fun op refund_actual_prefix_lookups _ = ()
  val op refund_actual_prefix_lookups = TDB.find
    "refund_actual_prefix_lookups"
  fun op refund_actual_prefix_env_def _ = ()
  val op refund_actual_prefix_env_def = TDB.find
    "refund_actual_prefix_env_def"
  fun op refund_actual_main_prefix _ = ()
  val op refund_actual_main_prefix = TDB.find "refund_actual_main_prefix"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundEntry"

end
