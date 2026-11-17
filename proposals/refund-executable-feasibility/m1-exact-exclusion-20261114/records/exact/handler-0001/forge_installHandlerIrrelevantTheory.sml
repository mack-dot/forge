structure forge_installHandlerIrrelevantTheory :> forge_installHandlerIrrelevantTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_installHandlerIrrelevantTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_labRegionAlignedTheory forge_refundLabRunTheory
  forge_simReplayTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_installHandlerIrrelevant",
        hash = "12002b27623f053a2f754ffc10c2fceaf9879c54",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_installHandlerIrrelevant"
      {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op same_but_install_def _ = ()
  val op same_but_install_def = TDB.find "same_but_install_def"
  fun op no_install_prefix_same_but_install _ = ()
  val op no_install_prefix_same_but_install = TDB.find
    "no_install_prefix_same_but_install"
  fun op handler_matters_when_installer_reached _ = ()
  val op handler_matters_when_installer_reached = TDB.find
    "handler_matters_when_installer_reached"
  fun op forge_toy_mc3_def _ = ()
  val op forge_toy_mc3_def = TDB.find "forge_toy_mc3_def"
  fun op evaluate_same_but_install _ = ()
  val op evaluate_same_but_install = TDB.find "evaluate_same_but_install"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_installHandlerIrrelevant"

end
