structure forge_refundGuardTheory :> forge_refundGuardTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundGuardTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundProgTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundGuard",
        hash = "1bc95860b27b34093cb5118434c30d9fdc49f56f",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundGuard" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_tail_rejects _ = ()
  val op refund_tail_rejects = TDB.find "refund_tail_rejects"
  fun op refund_tail_expr_def _ = ()
  val op refund_tail_expr_def = TDB.find "refund_tail_expr_def"
  fun op refund_tail_env_def _ = ()
  val op refund_tail_env_def = TDB.find "refund_tail_env_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundGuard"

end
