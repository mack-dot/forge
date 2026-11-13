structure forge_refundInitialStackCodeTheory :> forge_refundInitialStackCodeTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundInitialStackCodeTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundInitializationStaticTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundInitialStackCode",
        hash = "9f3b7a98c332f024424dfba46f97516e7f05e613",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundInitialStackCode" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_word_postalloc _ = ()
  val op refund_word_postalloc = TDB.find "refund_word_postalloc"
  fun op refund_word_labels _ = ()
  val op refund_word_labels = TDB.find "refund_word_labels"
  fun op refund_stack_lowering _ = ()
  val op refund_stack_lowering = TDB.find "refund_stack_lowering"
  fun op refund_initialization_code _ = ()
  val op refund_initialization_code = TDB.find "refund_initialization_code"
  fun op refund_initial_stack_good _ = ()
  val op refund_initial_stack_good = TDB.find "refund_initial_stack_good"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundInitialStackCode"

end
