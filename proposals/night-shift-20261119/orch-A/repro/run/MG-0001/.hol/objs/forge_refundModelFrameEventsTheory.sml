structure forge_refundModelFrameEventsTheory :> forge_refundModelFrameEventsTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundModelFrameEventsTheory ... "
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
        thyname = "forge_refundModelFrameEvents",
        hash = "3ebe66da54ab4541ff2bd73332aa0bf47b8034c3",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundModelFrameEvents" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_success_accept_of_run _ = ()
  val op refund_success_accept_of_run = TDB.find
    "refund_success_accept_of_run"
  fun op refund_model_success_gives_frame_events _ = ()
  val op refund_model_success_gives_frame_events = TDB.find
    "refund_model_success_gives_frame_events"
  fun op refund_model_frame_decision_events _ = ()
  val op refund_model_frame_decision_events = TDB.find
    "refund_model_frame_decision_events"
  fun op refund_model_frame_contract_of_reach _ = ()
  val op refund_model_frame_contract_of_reach = TDB.find
    "refund_model_frame_contract_of_reach"
  fun op refund_frame_contract_upgrade _ = ()
  val op refund_frame_contract_upgrade = TDB.find
    "refund_frame_contract_upgrade"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundModelFrameEvents"

end
