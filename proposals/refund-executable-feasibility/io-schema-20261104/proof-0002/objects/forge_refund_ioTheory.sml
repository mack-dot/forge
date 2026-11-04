structure forge_refund_ioTheory :> forge_refund_ioTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refund_ioTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refund_callTheory sexp_to_dafnyTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refund_io",
        hash = "d1f06fc880c562391acbb63566433cfc5c68c283",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refund_io" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_wrong_type_rejected _ = ()
  val op refund_wrong_type_rejected = TDB.find "refund_wrong_type_rejected"
  fun op refund_wire_roundtrip _ = ()
  val op refund_wire_roundtrip = TDB.find "refund_wire_roundtrip"
  fun op refund_wire_model_result _ = ()
  val op refund_wire_model_result = TDB.find "refund_wire_model_result"
  fun op refund_wire_model_def _ = ()
  val op refund_wire_model_def = TDB.find "refund_wire_model_def"
  fun op refund_trailing_input_rejected _ = ()
  val op refund_trailing_input_rejected = TDB.find
    "refund_trailing_input_rejected"
  fun op refund_stream_parse _ = ()
  val op refund_stream_parse = TDB.find "refund_stream_parse"
  fun op refund_schema_roundtrip _ = ()
  val op refund_schema_roundtrip = TDB.find "refund_schema_roundtrip"
  fun op refund_request_def _ = ()
  val op refund_request_def = TDB.find "refund_request_def"
  fun op refund_missing_field_rejected _ = ()
  val op refund_missing_field_rejected = TDB.find
    "refund_missing_field_rejected"
  fun op refund_decode_wire_def _ = ()
  val op refund_decode_wire_def = TDB.find "refund_decode_wire_def"
  fun op refund_decode_def _ = ()
  val op refund_decode_def = TDB.find "refund_decode_def"
  fun op refund_bad_integer_rejected _ = ()
  val op refund_bad_integer_rejected = TDB.find
    "refund_bad_integer_rejected"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refund_io"

end
