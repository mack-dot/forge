structure forge_refundInstallSiteTheory :> forge_refundInstallSiteTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundInstallSiteTheory ... "
    else ()
  
  open Type Term Thm
  local open arm8_stepTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundInstallSite",
        hash = "20ca4335c908db2cd7cc0a179718a4a22ac4bf3c",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundInstallSite" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op install_call_site_step _ = ()
  val op install_call_site_step = TDB.find "install_call_site_step"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundInstallSite"

end
