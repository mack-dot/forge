structure forge_spaceInstallTraceTheory :> forge_spaceInstallTraceTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_spaceInstallTraceTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_installSpaceBarrierTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_spaceInstallTrace",
        hash = "ddbaa64fed595842d2813901f60556d38eb48e34",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_spaceInstallTrace" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op safe_run_single_epoch _ = ()
  val op safe_run_single_epoch = TDB.find "safe_run_single_epoch"
  fun op epoch_single _ = () val op epoch_single = TDB.find "epoch_single"
  fun op bounded_stack_single_epoch _ = ()
  val op bounded_stack_single_epoch = TDB.find "bounded_stack_single_epoch"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_spaceInstallTrace"

end
