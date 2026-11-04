structure forge_refundRejectSemanticsTheory :> forge_refundRejectSemanticsTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundRejectSemanticsTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundRejectDirectTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundRejectSemantics",
        hash = "4f25430514adaa1b05187a9a9001b9f78d9eedce",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundRejectSemantics" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_semantics_dec_list_determ_terminate_unique _ = ()
  val op refund_semantics_dec_list_determ_terminate_unique = TDB.find
    "refund_semantics_dec_list_determ_terminate_unique"
  fun op refund_semantics_dec_list_all_terminate _ = ()
  val op refund_semantics_dec_list_all_terminate = TDB.find
    "refund_semantics_dec_list_all_terminate"
  fun op refund_raise_determ _ = ()
  val op refund_raise_determ = TDB.find "refund_raise_determ"
  fun op refund_exception_semantics _ = ()
  val op refund_exception_semantics = TDB.find "refund_exception_semantics"
  fun op refund_exception_determ _ = ()
  val op refund_exception_determ = TDB.find "refund_exception_determ"
  fun op refund_evaluate_dec_list_clock_result _ = ()
  val op refund_evaluate_dec_list_clock_result = TDB.find
    "refund_evaluate_dec_list_clock_result"
  fun op refund_error_stdio_semantics _ = ()
  val op refund_error_stdio_semantics = TDB.find
    "refund_error_stdio_semantics"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundRejectSemantics"

end
