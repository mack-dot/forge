structure forge_simZeroCaseTheory :> forge_simZeroCaseTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_simZeroCaseTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_targetInstallPrefixTheory lab_to_targetProofTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_simZeroCase",
        hash = "12151264289d7f7893d0d02fba43121d873b11b2",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_simZeroCase" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op state_rel_no_install_prefix_zero _ = ()
  val op state_rel_no_install_prefix_zero = TDB.find
    "state_rel_no_install_prefix_zero"
  fun op install_entry_wrap_example _ = ()
  val op install_entry_wrap_example = TDB.find "install_entry_wrap_example"
  fun op install_entry_distinct _ = ()
  val op install_entry_distinct = TDB.find "install_entry_distinct"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_simZeroCase"

end
