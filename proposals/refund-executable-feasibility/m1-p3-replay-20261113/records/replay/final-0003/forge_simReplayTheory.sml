structure forge_simReplayTheory :> forge_simReplayTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_simReplayTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_simRootTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_simReplay",
        hash = "56856abf7850cac657b2f18478b2cdf5f6ed674a",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_simReplay" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op target_install_exclusion_conditional _ = ()
  val op target_install_exclusion_conditional = TDB.find
    "target_install_exclusion_conditional"
  fun op step_nip _ = () val op step_nip = TDB.find "step_nip"
  fun op state_rel_ctx _ = ()
  val op state_rel_ctx = TDB.find "state_rel_ctx"
  fun op seg_finish _ = () val op seg_finish = TDB.find "seg_finish"
  fun op nip_ctx_def _ = () val op nip_ctx_def = TDB.find "nip_ctx_def"
  fun op lab_step_evaluate _ = ()
  val op lab_step_evaluate = TDB.find "lab_step_evaluate"
  fun op lab_step_def _ = () val op lab_step_def = TDB.find "lab_step_def"
  fun op lab_step_closed_def _ = ()
  val op lab_step_closed_def = TDB.find "lab_step_closed_def"
  fun op halt_ctx_def _ = () val op halt_ctx_def = TDB.find "halt_ctx_def"
  fun op final_nip _ = () val op final_nip = TDB.find "final_nip"
  fun op compile_no_install_prefix _ = ()
  val op compile_no_install_prefix = TDB.find "compile_no_install_prefix"
  fun op compile_correct_no_install_prefix _ = ()
  val op compile_correct_no_install_prefix = TDB.find
    "compile_correct_no_install_prefix"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_simReplay"

end
