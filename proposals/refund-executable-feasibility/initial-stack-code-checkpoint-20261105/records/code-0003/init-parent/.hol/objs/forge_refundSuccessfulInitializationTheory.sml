structure forge_refundSuccessfulInitializationTheory :> forge_refundSuccessfulInitializationTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundSuccessfulInitializationTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundArm8ProofTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundSuccessfulInitialization",
        hash = "cb4d31db18d2a1a0387868f88b39bfe4207d911b",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundSuccessfulInitialization"
      {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_lab_oracle _ = ()
  val op refund_lab_oracle = TDB.find "refund_lab_oracle"
  fun op refund_lab_code _ = ()
  val op refund_lab_code = TDB.find "refund_lab_code"
  fun op refund_initialization_sufficient _ = ()
  val op refund_initialization_sufficient = TDB.find
    "refund_initialization_sufficient"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundSuccessfulInitialization"

end
