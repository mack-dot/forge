structure forge_refundWordOracleTheory :> forge_refundWordOracleTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundWordOracleTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundInitializedEpochTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundWordOracle",
        hash = "7c4d20e99fe0e2dbaa63ef99c2cac8dcc26e36d6",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundWordOracle" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_word_oracle_binding _ = ()
  val op refund_word_oracle_binding = TDB.find "refund_word_oracle_binding"
  fun op refund_exact_oracle_single_epoch _ = ()
  val op refund_exact_oracle_single_epoch = TDB.find
    "refund_exact_oracle_single_epoch"
  fun op refund_data_oracle_labels _ = ()
  val op refund_data_oracle_labels = TDB.find "refund_data_oracle_labels"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundWordOracle"

end
