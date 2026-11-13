structure forge_refundInitializerInstalledTheory :> forge_refundInitializerInstalledTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundInitializerInstalledTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundInitializerAlignedTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundInitializerInstalled",
        hash = "c1221c95b3406953fb5e68b9ec2b335f618c576f",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundInitializerInstalled"
      {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_initialization_installed _ = ()
  val op refund_initialization_installed = TDB.find
    "refund_initialization_installed"
  fun op heap_region_extends _ = ()
  val op heap_region_extends = TDB.find "heap_region_extends"
  fun op arm8_machine_model_instance _ = ()
  val op arm8_machine_model_instance = TDB.find
    "arm8_machine_model_instance"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundInitializerInstalled"

end
