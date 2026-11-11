structure forge_refundDataBehaviorTheory :> forge_refundDataBehaviorTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundDataBehaviorTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundArm8ProofTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundDataBehavior",
        hash = "bfa5c793119a0cf4ff7ba8a057117ecab59c54cf",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundDataBehavior" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_data_behavior _ = ()
  val op refund_data_behavior = TDB.find "refund_data_behavior"
  fun op compiled_source_data _ = ()
  val op compiled_source_data = TDB.find "compiled_source_data"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundDataBehavior"

end
