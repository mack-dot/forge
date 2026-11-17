structure forge_refundCallSiteTheory :> forge_refundCallSiteTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundCallSiteTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundFficloseComposeTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundCallSite",
        hash = "677bb716944e069ba189b377d3de4a09d215b5ea",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundCallSite" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_static_def _ = ()
  val op refund_static_def = TDB.find "refund_static_def"
  fun op normal_step_is_machine_step _ = ()
  val op normal_step_is_machine_step = TDB.find
    "normal_step_is_machine_step"
  fun op mc_static_eq_def _ = ()
  val op mc_static_eq_def = TDB.find "mc_static_eq_def"
  fun op machine_step_def _ = ()
  val op machine_step_def = TDB.find "machine_step_def"
  fun op machine_reach_n_evaluate _ = ()
  val op machine_reach_n_evaluate = TDB.find "machine_reach_n_evaluate"
  fun op machine_reach_n_def _ = ()
  val op machine_reach_n_def = TDB.find "machine_reach_n_def"
  fun op machine_reach_n_compute _ = ()
  val op machine_reach_n_compute = TDB.find "machine_reach_n_compute"
  fun op machine_reach_def _ = ()
  val op machine_reach_def = TDB.find "machine_reach_def"
  fun op call_FFI_return_keeps_oracle _ = ()
  val op call_FFI_return_keeps_oracle = TDB.find
    "call_FFI_return_keeps_oracle"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundCallSite"

end
