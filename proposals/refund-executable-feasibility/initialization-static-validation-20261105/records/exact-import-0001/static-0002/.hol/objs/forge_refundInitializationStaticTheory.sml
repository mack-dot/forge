structure forge_refundInitializationStaticTheory :> forge_refundInitializationStaticTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundInitializationStaticTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundSuccessfulInitializationTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundInitializationStatic",
        hash = "43764c8a07656361c755396dafba482ba23e7f06",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundInitializationStatic"
      {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_stack_oracle_good _ = ()
  val op refund_stack_oracle_good = TDB.find "refund_stack_oracle_good"
  fun op refund_name_permutation _ = ()
  val op refund_name_permutation = TDB.find "refund_name_permutation"
  fun op refund_initialization_static _ = ()
  val op refund_initialization_static = TDB.find
    "refund_initialization_static"
  fun op refund_config_ok _ = ()
  val op refund_config_ok = TDB.find "refund_config_ok"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundInitializationStatic"

end
