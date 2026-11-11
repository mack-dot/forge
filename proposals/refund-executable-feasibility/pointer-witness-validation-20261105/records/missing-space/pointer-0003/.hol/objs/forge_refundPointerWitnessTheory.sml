structure forge_refundPointerWitnessTheory :> forge_refundPointerWitnessTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundPointerWitnessTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundStackInitializationTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundPointerWitness",
        hash = "24d0e8fb5d36ecab9afa0e6c60fdb3f3df202c6d",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundPointerWitness" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_witnessed_single_epoch _ = ()
  val op refund_witnessed_single_epoch = TDB.find
    "refund_witnessed_single_epoch"
  fun op refund_pointer_fixed_point _ = ()
  val op refund_pointer_fixed_point = TDB.find "refund_pointer_fixed_point"
  fun op refund_initializer_oracle_independence _ = ()
  val op refund_initializer_oracle_independence = TDB.find
    "refund_initializer_oracle_independence"
  fun op refund_fixed_syntax_pointer_witness _ = ()
  val op refund_fixed_syntax_pointer_witness = TDB.find
    "refund_fixed_syntax_pointer_witness"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundPointerWitness"

end
