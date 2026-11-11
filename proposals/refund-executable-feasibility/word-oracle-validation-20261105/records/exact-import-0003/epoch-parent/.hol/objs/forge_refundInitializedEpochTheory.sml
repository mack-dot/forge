structure forge_refundInitializedEpochTheory :> forge_refundInitializedEpochTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundInitializedEpochTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundWordInitializationTheory
  forge_refundWordPremisesTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundInitializedEpoch",
        hash = "253e6c9cb6cf325458d423de4d8bebbd0b803409",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundInitializedEpoch" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_word_config_facts _ = ()
  val op refund_word_config_facts = TDB.find "refund_word_config_facts"
  fun op refund_initialized_single_epoch _ = ()
  val op refund_initialized_single_epoch = TDB.find
    "refund_initialized_single_epoch"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundInitializedEpoch"

end
