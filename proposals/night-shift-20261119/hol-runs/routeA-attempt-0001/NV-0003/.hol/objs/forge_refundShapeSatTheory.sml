structure forge_refundShapeSatTheory :> forge_refundShapeSatTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundShapeSatTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundInputSatTheory forge_refundRouteA2dTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundShapeSat",
        hash = "ff571a31a8e62a93496a09de8fc8d26a46e6b67c",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundShapeSat" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_shape_run_is_accepted _ = ()
  val op refund_shape_run_is_accepted = TDB.find
    "refund_shape_run_is_accepted"
  fun op refund_shape_premises_satisfiable_for_every_request _ = ()
  val op refund_shape_premises_satisfiable_for_every_request = TDB.find
    "refund_shape_premises_satisfiable_for_every_request"
  fun op refund_shape_premises_satisfiable _ = ()
  val op refund_shape_premises_satisfiable = TDB.find
    "refund_shape_premises_satisfiable"
  fun op refund_shape_premises_hold_at_a_constructed_state _ = ()
  val op refund_shape_premises_hold_at_a_constructed_state = TDB.find
    "refund_shape_premises_hold_at_a_constructed_state"
  fun op refund_ffi_contract_at_imp_on _ = ()
  val op refund_ffi_contract_at_imp_on = TDB.find
    "refund_ffi_contract_at_imp_on"
  fun op refund_abs_env_fields _ = ()
  val op refund_abs_env_fields = TDB.find "refund_abs_env_fields"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundShapeSat"

end
