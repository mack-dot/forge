structure forge_refundExclusionFinalTheory :> forge_refundExclusionFinalTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundExclusionFinalTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_installHandlerIrrelevantTheory
  forge_refundExclusionChainTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundExclusionFinal",
        hash = "b951b5bc268af1c07d58c42b55cef9d2adfb0f76",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundExclusionFinal" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_install_exclusion_any_handler _ = ()
  val op refund_install_exclusion_any_handler = TDB.find
    "refund_install_exclusion_any_handler"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundExclusionFinal"

end
