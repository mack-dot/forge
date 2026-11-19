structure forge_refundModelFrameTheory :> forge_refundModelFrameTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundModelFrameTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundExportedContractTheory forge_refundLOutTheory
  forge_refundPrefixExactTheory forge_refundRouteA2Theory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundModelFrame",
        hash = "3591187a4b75b05ea88a7cb63793943fe5a2dadf",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundModelFrame" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_success_accept _ = ()
  val op refund_success_accept = TDB.find "refund_success_accept"
  fun op refund_strict_parse_empty_rejected _ = ()
  val op refund_strict_parse_empty_rejected = TDB.find
    "refund_strict_parse_empty_rejected"
  fun op refund_strict_parse_common_prefix_rejected _ = ()
  val op refund_strict_parse_common_prefix_rejected = TDB.find
    "refund_strict_parse_common_prefix_rejected"
  fun op refund_outcome_prefix _ = ()
  val op refund_outcome_prefix = TDB.find "refund_outcome_prefix"
  fun op refund_model_success_gives_frame _ = ()
  val op refund_model_success_gives_frame = TDB.find
    "refund_model_success_gives_frame"
  fun op refund_model_frame_meets_exported_contract _ = ()
  val op refund_model_frame_meets_exported_contract = TDB.find
    "refund_model_frame_meets_exported_contract"
  fun op refund_model_frame_decision_reach _ = ()
  val op refund_model_frame_decision_reach = TDB.find
    "refund_model_frame_decision_reach"
  fun op refund_model_frame_decision _ = ()
  val op refund_model_frame_decision = TDB.find
    "refund_model_frame_decision"
  fun op refund_frame_contract_key _ = ()
  val op refund_frame_contract_key = TDB.find "refund_frame_contract_key"
  fun op refund_frame_accept_of_prefix _ = ()
  val op refund_frame_accept_of_prefix = TDB.find
    "refund_frame_accept_of_prefix"
  fun op refund_frame_accept_of_outcome _ = ()
  val op refund_frame_accept_of_outcome = TDB.find
    "refund_frame_accept_of_outcome"
  fun op refund_fd1_frame_of_run _ = ()
  val op refund_fd1_frame_of_run = TDB.find "refund_fd1_frame_of_run"
  fun op extend_with_resource_limit_single_success _ = ()
  val op extend_with_resource_limit_single_success = TDB.find
    "extend_with_resource_limit_single_success"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundModelFrame"

end
