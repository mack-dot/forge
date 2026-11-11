structure forge_refundDataOracleTheory :> forge_refundDataOracleTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundDataOracleTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundArm8ProofTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundDataOracle",
        hash = "f46c1b5f97d290e8061ae0a7782e8ea3f64f60e2",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundDataOracle" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op safe_data_execution _ = ()
  val op safe_data_execution = TDB.find "safe_data_execution"
  fun op refund_data_oracle_independence _ = ()
  val op refund_data_oracle_independence = TDB.find
    "refund_data_oracle_independence"
  fun op initial_oracle_relation _ = ()
  val op initial_oracle_relation = TDB.find "initial_oracle_relation"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundDataOracle"

end
