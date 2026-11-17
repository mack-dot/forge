structure forge_refundExclusionRealTheory :> forge_refundExclusionRealTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundExclusionRealTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundExclusionSourceTheory
  forge_refundInstallHandlerTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundExclusionReal",
        hash = "07057461a48c438758a611a3178a36905f3e54d3",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundExclusionReal" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_u298_exclusion_real _ = ()
  val op refund_u298_exclusion_real = TDB.find "refund_u298_exclusion_real"
  fun op refund_installed_no_handler_def _ = ()
  val op refund_installed_no_handler_def = TDB.find
    "refund_installed_no_handler_def"
  fun op refund_compile_correct_no_handler _ = ()
  val op refund_compile_correct_no_handler = TDB.find
    "refund_compile_correct_no_handler"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundExclusionReal"

end
