structure forge_refundRejectDirectTheory :> forge_refundRejectDirectTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundRejectDirectTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundWholeProgTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundRejectDirect",
        hash = "fea4d51d28ead4c570ad07ab2ac3d3f62a1a08c4",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundRejectDirect" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_call_main_exception _ = ()
  val op refund_call_main_exception = TDB.find "refund_call_main_exception"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundRejectDirect"

end
