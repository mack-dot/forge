structure forge_refundR6ReadTheory :> forge_refundR6ReadTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundR6ReadTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundR6WriteTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundR6Read",
        hash = "f21338f41b233290b9cd82ee06b15509e30dd3a4",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundR6Read" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refillBuffer_with_read_spec_V _ = ()
  val op refillBuffer_with_read_spec_V = TDB.find
    "refillBuffer_with_read_spec_V"
  fun op refillBuffer_with_read_spec_STR_V _ = ()
  val op refillBuffer_with_read_spec_STR_V = TDB.find
    "refillBuffer_with_read_spec_STR_V"
  fun op read_into_spec_R _ = ()
  val op read_into_spec_R = TDB.find "read_into_spec_R"
  fun op read_event_ok_refund _ = ()
  val op read_event_ok_refund = TDB.find "read_event_ok_refund"
  fun op read_event_ok_read_into _ = ()
  val op read_event_ok_read_into = TDB.find "read_event_ok_read_into"
  fun op read_event_ok_def _ = ()
  val op read_event_ok_def = TDB.find "read_event_ok_def"
  fun op STD_streams_fd0 _ = ()
  val op STD_streams_fd0 = TDB.find "STD_streams_fd0"
  fun op INSTREAM_STR_V_def _ = ()
  val op INSTREAM_STR_V_def = TDB.find "INSTREAM_STR_V_def"
  fun op INSTREAM_STR_V_IMP _ = ()
  val op INSTREAM_STR_V_IMP = TDB.find "INSTREAM_STR_V_IMP"
  fun op INSTREAM_STRP_V_def _ = ()
  val op INSTREAM_STRP_V_def = TDB.find "INSTREAM_STRP_V_def"
  fun op INSTREAM_STRP_V_F_F _ = ()
  val op INSTREAM_STRP_V_F_F = TDB.find "INSTREAM_STRP_V_F_F"
  fun op INSTREAM_BUFFERED_FD_V_def _ = ()
  val op INSTREAM_BUFFERED_FD_V_def = TDB.find "INSTREAM_BUFFERED_FD_V_def"
  fun op INSTREAM_BUFFERED_FD_V_IMP _ = ()
  val op INSTREAM_BUFFERED_FD_V_IMP = TDB.find "INSTREAM_BUFFERED_FD_V_IMP"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundR6Read"

end
