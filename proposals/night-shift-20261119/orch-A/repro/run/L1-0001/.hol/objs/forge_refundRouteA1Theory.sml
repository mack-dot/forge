structure forge_refundRouteA1Theory :> forge_refundRouteA1Theory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundRouteA1Theory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundSlideProfileATheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundRouteA1",
        hash = "57b9ea183c77b7fc1a46cb28bdb60376f0f64969",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundRouteA1" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op stored_contract_demands_return_at_u393_close_state _ = ()
  val op stored_contract_demands_return_at_u393_close_state = TDB.find
    "stored_contract_demands_return_at_u393_close_state"
  fun op refund_ffi_tot_valid _ = ()
  val op refund_ffi_tot_valid = TDB.find "refund_ffi_tot_valid"
  fun op refund_ffi_tot_shift_seq _ = ()
  val op refund_ffi_tot_shift_seq = TDB.find "refund_ffi_tot_shift_seq"
  fun op refund_ffi_tot_invalid _ = ()
  val op refund_ffi_tot_invalid = TDB.find "refund_ffi_tot_invalid"
  fun op refund_ffi_tot_def _ = ()
  val op refund_ffi_tot_def = TDB.find "refund_ffi_tot_def"
  fun op refund_ffi_tot_all_valid_is_identity _ = ()
  val op refund_ffi_tot_all_valid_is_identity = TDB.find
    "refund_ffi_tot_all_valid_is_identity"
  fun op refund_ffi_contract_on_totalises _ = ()
  val op refund_ffi_contract_on_totalises = TDB.find
    "refund_ffi_contract_on_totalises"
  fun op refund_ffi_contract_on_def _ = ()
  val op refund_ffi_contract_on_def = TDB.find "refund_ffi_contract_on_def"
  fun op refund_ffi_contract_on_all_valid_is_the_stored_contract _ = ()
  val op refund_ffi_contract_on_all_valid_is_the_stored_contract = TDB.find
    "refund_ffi_contract_on_all_valid_is_the_stored_contract"
  fun op refund_env_with_ffi_interfer_fields _ = ()
  val op refund_env_with_ffi_interfer_fields = TDB.find
    "refund_env_with_ffi_interfer_fields"
  fun op refund_env_ok_sl_of_contract_on _ = ()
  val op refund_env_ok_sl_of_contract_on = TDB.find
    "refund_env_ok_sl_of_contract_on"
  fun op refund_close_call_valid_rejects_u393_witness _ = ()
  val op refund_close_call_valid_rejects_u393_witness = TDB.find
    "refund_close_call_valid_rejects_u393_witness"
  fun op refund_close_call_valid_excludes_zero_alen _ = ()
  val op refund_close_call_valid_excludes_zero_alen = TDB.find
    "refund_close_call_valid_excludes_zero_alen"
  fun op refund_close_call_valid_def _ = ()
  val op refund_close_call_valid_def = TDB.find
    "refund_close_call_valid_def"
  fun op refund_close_abort_model_ffi_def _ = ()
  val op refund_close_abort_model_ffi_def = TDB.find
    "refund_close_abort_model_ffi_def"
  fun op contract_on_without_totalisation_is_not_the_stored_contract _ = ()
  val op contract_on_without_totalisation_is_not_the_stored_contract =
    TDB.find "contract_on_without_totalisation_is_not_the_stored_contract"
  fun op close_abort_model_totalised_meets_stored_contract _ = ()
  val op close_abort_model_totalised_meets_stored_contract = TDB.find
    "close_abort_model_totalised_meets_stored_contract"
  fun op close_abort_model_satisfies_contract_on _ = ()
  val op close_abort_model_satisfies_contract_on = TDB.find
    "close_abort_model_satisfies_contract_on"
  fun op close_abort_model_fails_stored_contract _ = ()
  val op close_abort_model_fails_stored_contract = TDB.find
    "close_abort_model_fails_stored_contract"
  fun op bad_return_ffi_totalised_with_empty_predicate_meets_contract _ =
    ()
  val op bad_return_ffi_totalised_with_empty_predicate_meets_contract =
    TDB.find "bad_return_ffi_totalised_with_empty_predicate_meets_contract"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundRouteA1"

end
