structure forge_refundClosureInstallTheory :> forge_refundClosureInstallTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundClosureInstallTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundArm8CompileTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundClosureInstall",
        hash = "ecec801e610426ad6cb1cc5baa1f9fb915a60537",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundClosureInstall" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_closure_no_install _ = ()
  val op refund_closure_no_install = TDB.find "refund_closure_no_install"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundClosureInstall"

end
