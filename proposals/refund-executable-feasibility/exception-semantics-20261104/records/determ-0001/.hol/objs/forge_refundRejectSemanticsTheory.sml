structure forge_refundRejectSemanticsTheory :> forge_refundRejectSemanticsTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundRejectSemanticsTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundRejectDirectTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundRejectSemantics",
        hash = "75803831d6a5b1d2a26708507608ece38ce68e31",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundRejectSemantics" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_raise_determ _ = ()
  val op refund_raise_determ = TDB.find "refund_raise_determ"
  fun op refund_exception_determ _ = ()
  val op refund_exception_determ = TDB.find "refund_exception_determ"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundRejectSemantics"

end
