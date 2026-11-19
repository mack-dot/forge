structure forge_refundModelFrameTotTheory :> forge_refundModelFrameTotTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundModelFrameTotTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundModelFrameTheory forge_refundRouteA2cTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundModelFrameTot",
        hash = "d4fb7f3d5a9f262e5510a60f160b3200e9393dd7",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundModelFrameTot" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_model_success_totalised _ = ()
  val op refund_model_success_totalised = TDB.find
    "refund_model_success_totalised"
  fun op refund_model_frame_totalised _ = ()
  val op refund_model_frame_totalised = TDB.find
    "refund_model_frame_totalised"
  fun op refund_ffi_tot_observed_set _ = ()
  val op refund_ffi_tot_observed_set = TDB.find
    "refund_ffi_tot_observed_set"
  fun op refund_ffi_tot_empty_predicate_is_abstract _ = ()
  val op refund_ffi_tot_empty_predicate_is_abstract = TDB.find
    "refund_ffi_tot_empty_predicate_is_abstract"
  fun op refund_ffi_tot_classification_ignores_counter _ = ()
  val op refund_ffi_tot_classification_ignores_counter = TDB.find
    "refund_ffi_tot_classification_ignores_counter"
  fun op refund_ffi_contract_on_empty_predicate _ = ()
  val op refund_ffi_contract_on_empty_predicate = TDB.find
    "refund_ffi_contract_on_empty_predicate"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundModelFrameTot"

end
