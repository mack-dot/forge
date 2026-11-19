structure forge_refundPrefixExactTheory :> forge_refundPrefixExactTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundPrefixExactTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundPrefixFreeTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundPrefixExact",
        hash = "c407a0782b61f1d6440b7327712cc10bc4a4a822",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundPrefixExact" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_strict_parse_witness _ = ()
  val op refund_strict_parse_witness = TDB.find
    "refund_strict_parse_witness"
  fun op refund_strict_parse_rejects_extension _ = ()
  val op refund_strict_parse_rejects_extension = TDB.find
    "refund_strict_parse_rejects_extension"
  fun op refund_strict_parse_not_reject_all _ = ()
  val op refund_strict_parse_not_reject_all = TDB.find
    "refund_strict_parse_not_reject_all"
  fun op refund_strict_parse_extension_needs_nonempty _ = ()
  val op refund_strict_parse_extension_needs_nonempty = TDB.find
    "refund_strict_parse_extension_needs_nonempty"
  fun op refund_strict_parse_exact _ = ()
  val op refund_strict_parse_exact = TDB.find "refund_strict_parse_exact"
  fun op refund_strict_parse_accepts_only_one_frame _ = ()
  val op refund_strict_parse_accepts_only_one_frame = TDB.find
    "refund_strict_parse_accepts_only_one_frame"
  fun op refund_strict_parse_SOME_render _ = ()
  val op refund_strict_parse_SOME_render = TDB.find
    "refund_strict_parse_SOME_render"
  fun op refund_frame_decision_needs_prefix _ = ()
  val op refund_frame_decision_needs_prefix = TDB.find
    "refund_frame_decision_needs_prefix"
  fun op refund_frame_decision _ = ()
  val op refund_frame_decision = TDB.find "refund_frame_decision"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundPrefixExact"

end
