structure forge_refundLExitTheory :> forge_refundLExitTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundLExitTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundLOutTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundLExit",
        hash = "409be033dc253a70ce672ca89c21165dcdbf9cc7",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundLExit" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_profile_a_sl_halt _ = ()
  val op refund_profile_a_sl_halt = TDB.find "refund_profile_a_sl_halt"
  fun op refund_halt_address _ = ()
  val op refund_halt_address = TDB.find "refund_halt_address"
  fun op machine_sem_of_evaluate_Halt _ = ()
  val op machine_sem_of_evaluate_Halt = TDB.find
    "machine_sem_of_evaluate_Halt"
  fun op evaluate_Halt_reg _ = ()
  val op evaluate_Halt_reg = TDB.find "evaluate_Halt_reg"
  fun op cml_exit_stderr_def _ = ()
  val op cml_exit_stderr_def = TDB.find "cml_exit_stderr_def"
  fun op cml_exit_status_def _ = ()
  val op cml_exit_status_def = TDB.find "cml_exit_status_def"
  fun op N_E3_success_with_zero_register _ = ()
  val op N_E3_success_with_zero_register = TDB.find
    "N_E3_success_with_zero_register"
  fun op N_E2_silent_stop _ = ()
  val op N_E2_silent_stop = TDB.find "N_E2_silent_stop"
  fun op N_E1_status_collision _ = ()
  val op N_E1_status_collision = TDB.find "N_E1_status_collision"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundLExit"

end
