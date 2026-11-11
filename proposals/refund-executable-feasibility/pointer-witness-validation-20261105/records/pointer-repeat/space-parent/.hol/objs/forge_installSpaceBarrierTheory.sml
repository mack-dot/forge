structure forge_installSpaceBarrierTheory :> forge_installSpaceBarrierTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_installSpaceBarrierTheory ... "
    else ()
  
  open Type Term Thm
  local open wordPropsTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_installSpaceBarrier",
        hash = "5e40093df3444c9a28c49ac8ef168c99d882c8fd",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_installSpaceBarrier" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op safe_run_excludes_install_suffix _ = ()
  val op safe_run_excludes_install_suffix = TDB.find
    "safe_run_excludes_install_suffix"
  fun op install_suffix_unbounded _ = ()
  val op install_suffix_unbounded = TDB.find "install_suffix_unbounded"
  fun op install_outcomes _ = ()
  val op install_outcomes = TDB.find "install_outcomes"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_installSpaceBarrier"

end
