structure forge_refundExclusionArm8Theory :> forge_refundExclusionArm8Theory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundExclusionArm8Theory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundCompileFactsTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundExclusionArm8",
        hash = "456b2ebc885faa8064d5994c131a3b911b5a67e8",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundExclusionArm8" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_u298_exclusion_any_handler _ = ()
  val op refund_u298_exclusion_any_handler = TDB.find
    "refund_u298_exclusion_any_handler"
  fun op refund_install_exclusion_installed _ = ()
  val op refund_install_exclusion_installed = TDB.find
    "refund_install_exclusion_installed"
  fun op refund_install_exclusion_arm8 _ = ()
  val op refund_install_exclusion_arm8 = TDB.find
    "refund_install_exclusion_arm8"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundExclusionArm8"

end
