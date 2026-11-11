structure forge_installExclusionControlTheory :> forge_installExclusionControlTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_installExclusionControlTheory ... "
    else ()
  
  open Type Term Thm
  local open targetPropsTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_installExclusionControl",
        hash = "af16661b9e349960c1915063f98650f893d6c06f",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_installExclusionControl"
      {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op installer_changes_outcome _ = ()
  val op installer_changes_outcome = TDB.find "installer_changes_outcome"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_installExclusionControl"

end
