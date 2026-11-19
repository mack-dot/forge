structure forge_refundRouteA2Theory :> forge_refundRouteA2Theory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundRouteA2Theory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundRouteA1Theory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundRouteA2",
        hash = "8c6dcf74d51e175c0d09658fda8d0ede3e18c6e9",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundRouteA2" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_profile_a_sl_reach _ = ()
  val op refund_profile_a_sl_reach = TDB.find "refund_profile_a_sl_reach"
  fun op refund_mc_totalised_record_fields _ = ()
  val op refund_mc_totalised_record_fields = TDB.find
    "refund_mc_totalised_record_fields"
  fun op refund_mc_totalised_record _ = ()
  val op refund_mc_totalised_record = TDB.find "refund_mc_totalised_record"
  fun op refund_ffi_tot_machine_sem_agree _ = ()
  val op refund_ffi_tot_machine_sem_agree = TDB.find
    "refund_ffi_tot_machine_sem_agree"
  fun op refund_ffi_tot_evaluate_agree _ = ()
  val op refund_ffi_tot_evaluate_agree = TDB.find
    "refund_ffi_tot_evaluate_agree"
  fun op read_ffi_bytearrays_ffi_interfer_update _ = ()
  val op read_ffi_bytearrays_ffi_interfer_update = TDB.find
    "read_ffi_bytearrays_ffi_interfer_update"
  fun op read_ffi_bytearray_ffi_interfer_update _ = ()
  val op read_ffi_bytearray_ffi_interfer_update = TDB.find
    "read_ffi_bytearray_ffi_interfer_update"
  fun op ffi_calls_ok_false_at_a_returning_call _ = ()
  val op ffi_calls_ok_false_at_a_returning_call = TDB.find
    "ffi_calls_ok_false_at_a_returning_call"
  fun op ffi_calls_ok_def _ = ()
  val op ffi_calls_ok_def = TDB.find "ffi_calls_ok_def"
  fun op ffi_calls_ok_compute _ = ()
  val op ffi_calls_ok_compute = TDB.find "ffi_calls_ok_compute"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundRouteA2"

end
