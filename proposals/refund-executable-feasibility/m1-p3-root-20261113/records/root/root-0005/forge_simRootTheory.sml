structure forge_simRootTheory :> forge_simRootTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_simRootTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_simLayoutTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_simRoot",
        hash = "0a65cfc02f5beab934003e0ee0c88fbc85d03cf2",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_simRoot" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op state_rel_segment_compose _ = ()
  val op state_rel_segment_compose = TDB.find "state_rel_segment_compose"
  fun op segment_interior_ordinary _ = ()
  val op segment_interior_ordinary = TDB.find "segment_interior_ordinary"
  fun op segment_end_no_install_prefix _ = ()
  val op segment_end_no_install_prefix = TDB.find
    "segment_end_no_install_prefix"
  fun op segment_compose_no_install_prefix _ = ()
  val op segment_compose_no_install_prefix = TDB.find
    "segment_compose_no_install_prefix"
  fun op run_interior_ordinary _ = ()
  val op run_interior_ordinary = TDB.find "run_interior_ordinary"
  fun op run_head_ordinary _ = ()
  val op run_head_ordinary = TDB.find "run_head_ordinary"
  fun op interior_install_example _ = ()
  val op interior_install_example = TDB.find "interior_install_example"
  fun op forge_toy_mc_def _ = ()
  val op forge_toy_mc_def = TDB.find "forge_toy_mc_def"
  fun op forge_toy_mc2_def _ = ()
  val op forge_toy_mc2_def = TDB.find "forge_toy_mc2_def"
  fun op endpoint_correspondence_insufficient _ = ()
  val op endpoint_correspondence_insufficient = TDB.find
    "endpoint_correspondence_insufficient"
  fun op asm_step_IMP_evaluate_step_prefix _ = ()
  val op asm_step_IMP_evaluate_step_prefix = TDB.find
    "asm_step_IMP_evaluate_step_prefix"
  fun op asm_step_IMP_evaluate_step_nop_prefix _ = ()
  val op asm_step_IMP_evaluate_step_nop_prefix = TDB.find
    "asm_step_IMP_evaluate_step_nop_prefix"
  fun op asm_step_IMP_evaluate_step_find_next_prefix _ = ()
  val op asm_step_IMP_evaluate_step_find_next_prefix = TDB.find
    "asm_step_IMP_evaluate_step_find_next_prefix"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_simRoot"

end
