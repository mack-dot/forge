structure forge_refundNonNegTheory :> forge_refundNonNegTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundNonNegTheory ... "
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
        thyname = "forge_refundNonNeg",
        hash = "fbd7d5e8158ca429807588e05fe8e4959c2ab32a",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundNonNeg" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_strict_parse_accepts_negative_frame _ = ()
  val op refund_strict_parse_accepts_negative_frame = TDB.find
    "refund_strict_parse_accepts_negative_frame"
  fun op refund_run_wire_output_nonneg _ = ()
  val op refund_run_wire_output_nonneg = TDB.find
    "refund_run_wire_output_nonneg"
  fun op refund_model_frame_decision_reach_nonneg _ = ()
  val op refund_model_frame_decision_reach_nonneg = TDB.find
    "refund_model_frame_decision_reach_nonneg"
  fun op refund_model_frame_decision_nonneg _ = ()
  val op refund_model_frame_decision_nonneg = TDB.find
    "refund_model_frame_decision_nonneg"
  fun op refund_frame_decision_nonneg _ = ()
  val op refund_frame_decision_nonneg = TDB.find
    "refund_frame_decision_nonneg"
  fun op refund_fields_positive_witness _ = ()
  val op refund_fields_positive_witness = TDB.find
    "refund_fields_positive_witness"
  fun op refund_fields_negative_amount_rejected _ = ()
  val op refund_fields_negative_amount_rejected = TDB.find
    "refund_fields_negative_amount_rejected"
  fun op refund_fields_ints_bounded_proj _ = ()
  val op refund_fields_ints_bounded_proj = TDB.find
    "refund_fields_ints_bounded_proj"
  fun op refund_fields_ints_bounded _ = ()
  val op refund_fields_ints_bounded = TDB.find "refund_fields_ints_bounded"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundNonNeg"

end
