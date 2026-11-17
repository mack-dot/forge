structure forge_simLayoutTheory :> forge_simLayoutTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_simLayoutTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_simZeroCaseTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_simLayout",
        hash = "29e820f3856b6e0f23233a7769c2c43803cd44e3",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_simLayout" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op state_rel_no_install_prefix_layout _ = ()
  val op state_rel_no_install_prefix_layout = TDB.find
    "state_rel_no_install_prefix_layout"
  fun op installed_bound_code_layout _ = ()
  val op installed_bound_code_layout = TDB.find
    "installed_bound_code_layout"
  fun op code_layout_ok_def _ = ()
  val op code_layout_ok_def = TDB.find "code_layout_ok_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_simLayout"

end
