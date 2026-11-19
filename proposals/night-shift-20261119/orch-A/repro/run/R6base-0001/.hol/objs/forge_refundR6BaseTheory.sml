structure forge_refundR6BaseTheory :> forge_refundR6BaseTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundR6BaseTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundRouteA2cTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundR6Base",
        hash = "bc56a1c2767bd5ffeb7775629472cf2af98a7c03",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundR6Base" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op replay_cannot_exclude_error_return_events _ = ()
  val op replay_cannot_exclude_error_return_events = TDB.find
    "replay_cannot_exclude_error_return_events"
  fun op refund_valid_event_implies_weak _ = ()
  val op refund_valid_event_implies_weak = TDB.find
    "refund_valid_event_implies_weak"
  fun op ffi_has_index_in_APPEND _ = ()
  val op ffi_has_index_in_APPEND = TDB.find "ffi_has_index_in_APPEND"
  fun op extract_fs_ignores_bad_read_event _ = ()
  val op extract_fs_ignores_bad_read_event = TDB.find
    "extract_fs_ignores_bad_read_event"
  fun op every_prefix _ = () val op every_prefix = TDB.find "every_prefix"
  fun op every_of_three_parts _ = ()
  val op every_of_three_parts = TDB.find "every_of_three_parts"
  fun op every_clock_events _ = ()
  val op every_clock_events = TDB.find "every_clock_events"
  fun op clock_prefix_of_terminate _ = ()
  val op clock_prefix_of_terminate = TDB.find "clock_prefix_of_terminate"
  fun op bad_read_event_replays_to_the_same_state _ = ()
  val op bad_read_event_replays_to_the_same_state = TDB.find
    "bad_read_event_replays_to_the_same_state"
  fun op bad_read_event_is_not_valid_w _ = ()
  val op bad_read_event_is_not_valid_w = TDB.find
    "bad_read_event_is_not_valid_w"
  fun op bad_read_event_is_not_valid _ = ()
  val op bad_read_event_is_not_valid = TDB.find
    "bad_read_event_is_not_valid"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundR6Base"

end
