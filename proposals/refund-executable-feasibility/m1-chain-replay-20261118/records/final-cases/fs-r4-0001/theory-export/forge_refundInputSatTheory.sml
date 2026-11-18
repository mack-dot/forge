structure forge_refundInputSatTheory :> forge_refundInputSatTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundInputSatTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundSlideProfileATheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundInputSat",
        hash = "10b5376298ecf09ce2b9383972015a7d052b5b0f",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundInputSat" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op sat_fs_wfFS _ = () val op sat_fs_wfFS = TDB.find "sat_fs_wfFS"
  fun op sat_fs_stdin_content _ = ()
  val op sat_fs_stdin_content = TDB.find "sat_fs_stdin_content"
  fun op sat_fs_def _ = () val op sat_fs_def = TDB.find "sat_fs_def"
  fun op sat_fs_STD_streams _ = ()
  val op sat_fs_STD_streams = TDB.find "sat_fs_STD_streams"
  fun op sat_cl_wfcl _ = () val op sat_cl_wfcl = TDB.find "sat_cl_wfcl"
  fun op
    refund_profile_a_sl_conclusion_holds_for_a_constructed_model_state_at_0x4000
    _ = ()
  val op
    refund_profile_a_sl_conclusion_holds_for_a_constructed_model_state_at_0x4000
    = TDB.find
    "refund_profile_a_sl_conclusion_holds_for_a_constructed_model_state_at_0x4000"
  fun op refund_profile_a_sl_all_premises_satisfiable_at_0x4000 _ = ()
  val op refund_profile_a_sl_all_premises_satisfiable_at_0x4000 = TDB.find
    "refund_profile_a_sl_all_premises_satisfiable_at_0x4000"
  fun op refund_input_premises_satisfiable _ = ()
  val op refund_input_premises_satisfiable = TDB.find
    "refund_input_premises_satisfiable"
  fun op live_numchars_LREPEAT_one _ = ()
  val op live_numchars_LREPEAT_one = TDB.find "live_numchars_LREPEAT_one"
  fun op finite_numchars_is_not_live _ = ()
  val op finite_numchars_is_not_live = TDB.find
    "finite_numchars_is_not_live"
  fun op consumed_stdin_has_no_content _ = ()
  val op consumed_stdin_has_no_content = TDB.find
    "consumed_stdin_has_no_content"
  fun op always_eventually_LREPEAT_one _ = ()
  val op always_eventually_LREPEAT_one = TDB.find
    "always_eventually_LREPEAT_one"
  fun op LREPEAT_one_unfold _ = ()
  val op LREPEAT_one_unfold = TDB.find "LREPEAT_one_unfold"
  fun op LFINITE_not_LREPEAT_one _ = ()
  val op LFINITE_not_LREPEAT_one = TDB.find "LFINITE_not_LREPEAT_one"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundInputSat"

end
