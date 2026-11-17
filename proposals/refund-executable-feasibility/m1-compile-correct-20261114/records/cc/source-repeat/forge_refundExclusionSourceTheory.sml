structure forge_refundExclusionSourceTheory :> forge_refundExclusionSourceTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundExclusionSourceTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_compileCorrectLabFactsTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundExclusionSource",
        hash = "1d8c6d9bde605c31e2140ba94b60d516c32f9455",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundExclusionSource" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_u298_exclusion_source_any_handler _ = ()
  val op refund_u298_exclusion_source_any_handler = TDB.find
    "refund_u298_exclusion_source_any_handler"
  fun op refund_install_exclusion_source _ = ()
  val op refund_install_exclusion_source = TDB.find
    "refund_install_exclusion_source"
  fun op refund_install_exclusion_compiled _ = ()
  val op refund_install_exclusion_compiled = TDB.find
    "refund_install_exclusion_compiled"
  fun op compile_lab_conf _ = ()
  val op compile_lab_conf = TDB.find "compile_lab_conf"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundExclusionSource"

end
