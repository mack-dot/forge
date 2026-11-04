structure forge_refundCfGapTheory :> forge_refundCfGapTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundCfGapTheory ... "
    else ()
  
  open Type Term Thm
  local open cfNormaliseTheory forge_refund_callTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundCfGap",
        hash = "f34ad72700e129ed4ec1f044a49e5f01fc381e38",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundCfGap" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_raw_match_value_premise_impossible _ = ()
  val op refund_raw_match_value_premise_impossible = TDB.find
    "refund_raw_match_value_premise_impossible"
  fun op refund_raw_discriminant_not_a_cf_value _ = ()
  val op refund_raw_discriminant_not_a_cf_value = TDB.find
    "refund_raw_discriminant_not_a_cf_value"
  fun op refund_raw_discriminant_def _ = ()
  val op refund_raw_discriminant_def = TDB.find
    "refund_raw_discriminant_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundCfGap"

end
