structure forge_refundRejectBasisTheory :> forge_refundRejectBasisTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundRejectBasisTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundRejectSemanticsTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundRejectBasis",
        hash = "ad03ae4f61a5343fd43c52862e7016b4f7678690",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundRejectBasis" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_stdio_extract_fs _ = ()
  val op refund_stdio_extract_fs = TDB.find "refund_stdio_extract_fs"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundRejectBasis"

end
