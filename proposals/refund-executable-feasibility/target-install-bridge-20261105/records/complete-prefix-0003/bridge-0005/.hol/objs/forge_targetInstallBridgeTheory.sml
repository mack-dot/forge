structure forge_targetInstallBridgeTheory :> forge_targetInstallBridgeTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_targetInstallBridgeTheory ... "
    else ()
  
  open Type Term Thm
  local open targetPropsTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_targetInstallBridge",
        hash = "fd3f73dcfa8e156e3bfb7f44765fd8b04a675d83",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_targetInstallBridge" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op machine_sem_install_irrelevant _ = ()
  val op machine_sem_install_irrelevant = TDB.find
    "machine_sem_install_irrelevant"
  fun op evaluate_install_irrelevant _ = ()
  val op evaluate_install_irrelevant = TDB.find
    "evaluate_install_irrelevant"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_targetInstallBridge"

end
