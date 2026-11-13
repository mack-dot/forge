structure forge_refundInitializerAlignedTheory :> forge_refundInitializerAlignedTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundInitializerAlignedTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundInitializerMachineTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundInitializerAligned",
        hash = "ab3fd435454ef1f9cc310b8a2a97fcca5c25b9c6",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundInitializerAligned"
      {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_initialization_aligned _ = ()
  val op refund_initialization_aligned = TDB.find
    "refund_initialization_aligned"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundInitializerAligned"

end
