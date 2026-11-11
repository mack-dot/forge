structure forge_refundWordPremisesTheory :> forge_refundWordPremisesTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundWordPremisesTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_compilerWordTraceTheory forge_refundDataBehaviorTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundWordPremises",
        hash = "3de970f59f122435bcb22c9043e18c090698bf16",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundWordPremises" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_word_single_epoch _ = ()
  val op refund_word_single_epoch = TDB.find "refund_word_single_epoch"
  fun op refund_data_nonfailure _ = ()
  val op refund_data_nonfailure = TDB.find "refund_data_nonfailure"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundWordPremises"

end
