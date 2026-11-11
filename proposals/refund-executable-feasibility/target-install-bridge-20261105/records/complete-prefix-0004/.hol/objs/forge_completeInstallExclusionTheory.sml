structure forge_completeInstallExclusionTheory :> forge_completeInstallExclusionTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_completeInstallExclusionTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_targetInstallBridgeTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_completeInstallExclusion",
        hash = "3386a31b1fc090c1ff8c5f10ac460d7a88ef4c9f",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_completeInstallExclusion"
      {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op complete_prefix_suffices _ = ()
  val op complete_prefix_suffices = TDB.find "complete_prefix_suffices"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_completeInstallExclusion"

end
