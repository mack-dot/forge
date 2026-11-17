structure forge_labRegionStepTheory :> forge_labRegionStepTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_labRegionStepTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_labRegionInvariantTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_labRegionStep",
        hash = "18f5061370bd64bb3c58afeef7ad05dd6ce287a8",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_labRegionStep" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op region_step_sharemem _ = ()
  val op region_step_sharemem = TDB.find "region_step_sharemem"
  fun op region_step_locvalue _ = ()
  val op region_step_locvalue = TDB.find "region_step_locvalue"
  fun op region_step_label _ = ()
  val op region_step_label = TDB.find "region_step_label"
  fun op region_step_jumpreg _ = ()
  val op region_step_jumpreg = TDB.find "region_step_jumpreg"
  fun op region_step_jumpcmp _ = ()
  val op region_step_jumpcmp = TDB.find "region_step_jumpcmp"
  fun op region_step_jump _ = ()
  val op region_step_jump = TDB.find "region_step_jump"
  fun op region_step_install _ = ()
  val op region_step_install = TDB.find "region_step_install"
  fun op region_step_inst _ = ()
  val op region_step_inst = TDB.find "region_step_inst"
  fun op region_step_halt _ = ()
  val op region_step_halt = TDB.find "region_step_halt"
  fun op region_step_callffi _ = ()
  val op region_step_callffi = TDB.find "region_step_callffi"
  fun op region_step_call _ = ()
  val op region_step_call = TDB.find "region_step_call"
  fun op region_run _ = () val op region_run = TDB.find "region_run"
  fun op region_prefix _ = ()
  val op region_prefix = TDB.find "region_prefix"
  fun op region_one_step _ = ()
  val op region_one_step = TDB.find "region_one_step"
  fun op region_inv_next _ = ()
  val op region_inv_next = TDB.find "region_inv_next"
  fun op region_inv_facts _ = ()
  val op region_inv_facts = TDB.find "region_inv_facts"
  fun op region_hyp_witness _ = ()
  val op region_hyp_witness = TDB.find "region_hyp_witness"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_labRegionStep"

end
