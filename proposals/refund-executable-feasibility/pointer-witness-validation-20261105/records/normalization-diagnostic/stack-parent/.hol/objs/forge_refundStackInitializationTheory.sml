structure forge_refundStackInitializationTheory :> forge_refundStackInitializationTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundStackInitializationTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundWordOracleTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundStackInitialization",
        hash = "683d45b625d7cc6131dd545dc7c5b7af7166fdcb",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundStackInitialization"
      {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_stack_store _ = ()
  val op refund_stack_store = TDB.find "refund_stack_store"
  fun op refund_stack_initialized_single_epoch _ = ()
  val op refund_stack_initialized_single_epoch = TDB.find
    "refund_stack_initialized_single_epoch"
  fun op refund_stack_gc _ = ()
  val op refund_stack_gc = TDB.find "refund_stack_gc"
  fun op refund_stack_compiler _ = ()
  val op refund_stack_compiler = TDB.find "refund_stack_compiler"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundStackInitialization"

end
