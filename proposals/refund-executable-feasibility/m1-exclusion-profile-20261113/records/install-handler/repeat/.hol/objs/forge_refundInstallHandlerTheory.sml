structure forge_refundInstallHandlerTheory :> forge_refundInstallHandlerTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundInstallHandlerTheory ... "
    else ()
  
  open Type Term Thm
  local open arm8_configProofTheory forge_targetInstallBridgeTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundInstallHandler",
        hash = "947e7a82eac2659676d969b2a7f3620a74d9a88d",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundInstallHandler" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op installed_modulo_install_handler _ = ()
  val op installed_modulo_install_handler = TDB.find
    "installed_modulo_install_handler"
  fun op install_exclusion_suffices _ = ()
  val op install_exclusion_suffices = TDB.find "install_exclusion_suffices"
  fun op arm8_install_handler_ok _ = ()
  val op arm8_install_handler_ok = TDB.find "arm8_install_handler_ok"
  fun op arm8_install_handler_exists _ = ()
  val op arm8_install_handler_exists = TDB.find
    "arm8_install_handler_exists"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundInstallHandler"

end
